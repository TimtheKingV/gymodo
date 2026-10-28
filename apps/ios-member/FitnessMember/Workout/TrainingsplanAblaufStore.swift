import Foundation
import Observation

/// Der Ablauf der heutigen Planeinheit auf dem Geraet (Trainingsplan Etappe 3,
/// Task 9): welche Einheit dran ist, was die Saetze schon abgehakt haben, und
/// die Momentaufnahme, die mit jedem Satz-PUT mitgeht.
///
/// Eigener Speicher neben WorkoutSessionStore statt eines Felds an
/// LokaleSession: der Ablauf gibt es schon VOR dem ersten Satz (Plankarte,
/// Tausch "nur heute"), die Session erst mit "Training starten". Die Regeln
/// selbst stehen in TrainingsplanAblauf (gemeinsamer Testfallsatz mit dem
/// Server, F17); hier liegt nur, wann sie greifen und was ueberdauert.
@MainActor
@Observable
final class TrainingsplanAblaufStore {
    /// Ein vorbereiteter Ablauf ohne Satz verfaellt nach zwoelf Stunden: der
    /// Tausch "nur heute" gilt dann nicht mehr fuer morgen.
    static let verfallOhneSatz: TimeInterval = 12 * 60 * 60

    private var datei: PlanAblaufDatei
    @ObservationIgnored private let fileStore: PlanAblaufFileStore
    /// Was zuletzt auf der Platte steht: vorbereiten() laeuft bei jedem
    /// Bootstrap und Vordergrund, meist ohne Aenderung -- dann kein Schreiben.
    @ObservationIgnored private var aufPlatte: PlanAblaufDatei

    init(fileStore: PlanAblaufFileStore = PlanAblaufFileStore()) {
        self.fileStore = fileStore
        let geladen = fileStore.load() ?? PlanAblaufDatei()
        datei = geladen
        aufPlatte = geladen
    }

    // MARK: - Lesen

    var zustand: AblaufZustand? { datei.lauf?.zustand }
    var planId: String? { datei.lauf?.planId }
    var einheitKey: String? { datei.lauf?.einheitKey }
    var gebundeneSessionId: UUID? { datei.lauf?.gebundeneSessionId }
    /// Der Stand der letzten Momentaufnahme; 0 vor dem ersten Satz.
    var stand: Int { datei.lauf?.stand ?? 0 }

    /// Die zuletzt beendete Einheit samt Ablauf -- fuer den Abschluss-Screen
    /// (Entwurf 2.3), der erst nach `einheitBeendet()` erscheint, wenn
    /// `zustand` schon leer ist. Bleibt bis zur naechsten beendeten Einheit.
    var zuletztBeendeterLauf: PlanLauf? { datei.zuletztBeendet?.lauf }

    /// Die Einheit, die als naechste vorbereitet wuerde -- fuer "Nächstes Mal
    /// ist Einheit B dran", wenn der Ablauf nach dem Beenden leer ist.
    var naechsteEinheitKey: String? { datei.vorlage.map(gewaehlteEinheit) }

    // MARK: - Vorbereiten

    /// Bequemer Einstieg fuer die Wurzel: der Plan des Mitglieds aus dem Bootstrap.
    func vorbereiten(bootstrap: BootstrapResponse?, jetzt: Date = Date()) {
        vorbereiten(plan: PlanAnzeige.plan(bootstrap: bootstrap), jetzt: jetzt)
    }

    /// Haelt den Plan des Mitglieds fest und baut den Ablauf der heutigen Einheit,
    /// falls noch keiner passt. Idempotent: die Wurzel ruft das nach jedem
    /// Bootstrap, Ortswechsel und Vordergrund.
    ///
    /// Ein Ablauf mit gebundener Session (es ging schon ein Satz raus) behaelt
    /// seine Planversion, auch wenn der Bootstrap inzwischen eine neuere nennt
    /// (Review Focus 2): der Server hat die Session an diese Version gebunden,
    /// und ein Wechsel mitten in der Einheit aenderte ihre Zaehlung.
    func vorbereiten(plan: Trainingsplan?, jetzt: Date = Date()) {
        datei.vorlage = plan.flatMap { p in !p.einheiten.isEmpty ? PlanVorlage(p) : nil }

        if let lauf = datei.lauf, lauf.gebundeneSessionId != nil {
            let letzte = lauf.letzterSatzAm ?? lauf.erstelltAm
            guard jetzt.timeIntervalSince(letzte) > WorkoutSessionStore.sessionPause else {
                speichern()
                return
            }
            // Vier Stunden ohne Satz: die Session ist auch fuer den Server
            // vorbei (Auto-Abschluss) und zaehlt wie eine beendete.
            abschliessen(jetzt: jetzt)
        }

        ungebundenAuffrischen(jetzt: jetzt)
        speichern()
    }

    // MARK: - Tausch "nur heute"

    /// Tauscht eine Position nur im heutigen Ablauf. Geht auch vor dem ersten
    /// Satz und bleibt bis zu ihm (und darueber) erhalten; die naechste
    /// Momentaufnahme traegt ihn mit.
    func tauschen(positionKey: String, ersatz: (exerciseId: String, hauptmuskeln: [String])) {
        if datei.lauf == nil, let vorlage = datei.vorlage {
            datei.lauf = neuerLauf(vorlage, jetzt: Date())
        }
        guard var lauf = datei.lauf else { return }
        lauf.zustand = TrainingsplanAblauf.tauschen(lauf.zustand, positionKey: positionKey, ersatz: ersatz)
        datei.lauf = lauf
        speichern()
    }

    // MARK: - Satz

    /// Hakt den Satz im Ablauf ab und gibt die Momentaufnahme fuer den
    /// Satz-PUT zurueck.
    ///
    /// nil ohne Plan -- dann bleibt auch alles unberuehrt: der Satz geht wie
    /// bisher ohne `plan` raus. Der Plan gilt an jedem Ort, auch im Freien
    /// Training.
    func nachSatz(sessionId: UUID, satz: AblaufSatz, jetzt: Date = Date()) -> PlanMomentaufnahme? {
        var lauf: PlanLauf
        if let vorhanden = datei.lauf,
           vorhanden.gebundeneSessionId == nil || vorhanden.gebundeneSessionId == sessionId {
            lauf = vorhanden
        } else if let vorlage = datei.vorlage {
            // Eine neue Session, obwohl der Ablauf noch an einer anderen
            // haengt: die alte ist vorbei (sonst gaebe es keine neue
            // Kennung). Sie zaehlt wie beendet, und die neue bekommt die
            // naechste Einheit -- nicht den Ablauf der alten.
            if datei.lauf?.gebundeneSessionId != nil { abschliessen(jetzt: jetzt) }
            lauf = neuerLauf(vorlage, jetzt: jetzt)
        } else {
            return nil
        }

        lauf.zustand = TrainingsplanAblauf.nachSatz(lauf.zustand, satz)
        // Jede Momentaufnahme bekommt einen hoeheren Stand, auch wenn sich
        // nichts aenderte: der Server nimmt nur einen hoeheren, und ein
        // erneut gesendeter aelterer Satz bleibt so wirkungslos.
        lauf.stand += 1
        lauf.gebundeneSessionId = sessionId
        lauf.letzterSatzAm = jetzt
        datei.lauf = lauf
        speichern()
        return lauf.momentaufnahme
    }

    // MARK: - Ende

    /// Vor `sessions.beenden()` rufen, solange die Einheit noch da ist. Zaehlt
    /// der Ablauf (erledigte oder optionale Position), merkt sich der Speicher
    /// die Einheit als zuletzt gemacht -- bis ein Bootstrap sie gezaehlt
    /// zeigt (`nachBootstrap`). Danach ist der Ablauf leer.
    func einheitBeendet(jetzt: Date = Date()) {
        guard let lauf = datei.lauf else { return }
        if lauf.gebundeneSessionId != nil {
            abschliessen(jetzt: jetzt)
        } else {
            // Ohne Satz gab es die Einheit nie (Entschieden 2): nur leeren.
            datei.lauf = nil
        }
        speichern()
    }

    /// "Training verwerfen": die Einheit zaehlt nicht. Nimmt die lokale
    /// Zaehlung zurueck, falls `einheitBeendet` sie gesetzt hatte und noch
    /// kein Bootstrap sie abgeloest hat.
    func einheitVerworfen(sessionId: UUID) {
        if datei.lauf?.gebundeneSessionId == sessionId {
            datei.lauf = nil
        }
        if let beendet = datei.zuletztBeendet, beendet.lauf.gebundeneSessionId == sessionId {
            if beendet.gezaehlt, datei.lokalZuletzt?.betrifft(beendet.lauf) == true {
                datei.lokalZuletzt = beendet.lokalZuletztVorher
            }
            datei.zuletztBeendet = nil
        }
        // Ein schon vorbereiteter Ablauf der Folgeeinheit passt jetzt nicht mehr.
        ungebundenAuffrischen(jetzt: Date())
        speichern()
    }

    /// "Fortsetzen" einer eben beendeten Einheit (WorkoutSessionStore.
    /// wiederaufnehmen): ihr Ablauf kommt zurueck, samt Stand -- sonst bekaeme
    /// dieselbe Session die naechste Einheit, und der Server lehnte jede
    /// weitere Momentaufnahme ab (die Bindung bleibt die erste).
    func einheitWiederaufgenommen(sessionId: UUID) {
        guard let beendet = datei.zuletztBeendet, beendet.lauf.gebundeneSessionId == sessionId else { return }
        if beendet.gezaehlt, datei.lokalZuletzt?.betrifft(beendet.lauf) == true {
            datei.lokalZuletzt = beendet.lokalZuletztVorher
        }
        datei.lauf = beendet.lauf
        datei.zuletztBeendet = nil
        speichern()
    }

    /// Nach einem frisch geladenen Bootstrap mit dessen Plan (hoechstens einer). Die lokale
    /// Zaehlung gibt erst ab, wenn nichts mehr offen ist (mit offenen Saetzen
    /// kann der Server hinterherhinken) UND
    /// - der Plan die Einheit gezaehlt zeigt: als zuletzt
    ///   gezaehlte und, wenn der Zaehler beim Beenden bekannt war, mit
    ///   hoeherem Zaehler (dieselbe Einheit kann schon vorher die letzte
    ///   gewesen sein), oder
    /// - sie aelter ist als die Vier-Stunden-Regel: dann ist die Session auch
    ///   fuer den Server vorbei, und die Zaehlung haelt sich nicht ewig.
    /// Eine leere Warteschlange allein reicht nicht: completeSession kann noch
    /// unterwegs sein (Ortswechsel meldet im Hintergrund) oder gescheitert.
    func nachBootstrap(offeneSchreibvorgaenge: Int, plaene: [Trainingsplan], jetzt: Date = Date()) {
        guard offeneSchreibvorgaenge == 0, let lokal = datei.lokalZuletzt else { return }
        let alt = jetzt.timeIntervalSince(lokal.beendetAm) > WorkoutSessionStore.sessionPause
        let gezaehlt = plaene.first.map { plan in
            plan.zuletztEinheitKey == lokal.einheitKey
                && lokal.serverErledigtVorher.map { plan.einheitenErledigt > $0 } ?? true
        } ?? false
        guard alt || gezaehlt else { return }
        datei.lokalZuletzt = nil
        speichern()
    }

    /// Beim Abmelden: der Ablauf gehoert zum abgemeldeten Konto.
    func reset() {
        datei = PlanAblaufDatei()
        speichern()
    }

    // MARK: - Intern

    /// Beendet den gebundenen Ablauf und merkt ihn fuer Verwerfen/Fortsetzen.
    private func abschliessen(jetzt: Date) {
        guard let lauf = datei.lauf else { return }
        let vorher = datei.lokalZuletzt
        let gezaehlt = TrainingsplanAblauf.zaehlt(lauf.zustand)
        if gezaehlt {
            // Der Zaehler des Servers, so wie die Vorlage ihn zuletzt sah:
            // erst ein hoeherer zeigt diese Einheit gezaehlt.
            let erledigt = datei.vorlage?.serverErledigt
            datei.lokalZuletzt = LokalZuletzt(einheitKey: lauf.einheitKey, beendetAm: jetzt,
                                              serverErledigtVorher: erledigt)
        }
        datei.zuletztBeendet = BeendeterLauf(lauf: lauf, gezaehlt: gezaehlt, lokalZuletztVorher: vorher)
        datei.lauf = nil
    }

    /// Ersetzt einen ungebundenen Ablauf, der nicht mehr passt, und baut einen,
    /// falls keiner da ist. Ein gebundener bleibt immer (Review Focus 2).
    private func ungebundenAuffrischen(jetzt: Date) {
        var ersetzt: PlanLauf?
        if let lauf = datei.lauf, lauf.gebundeneSessionId == nil, !passt(lauf, jetzt: jetzt) {
            ersetzt = lauf
            datei.lauf = nil
        }
        if datei.lauf == nil, let vorlage = datei.vorlage {
            let neu = neuerLauf(vorlage, jetzt: jetzt)
            datei.lauf = ersetzt.map { mitHeutigenTauschen(aus: $0, in: neu, jetzt: jetzt) } ?? neu
        }
    }

    /// Eine neue Planversion vor dem ersten Satz (dauerhafter Tausch, Task 12;
    /// ein Trainer) ersetzt den Ablauf. Die Taeusche "nur heute" derselben
    /// Einheit gehen dabei nicht verloren, solange ihre Position in der neuen
    /// Version dieselbe Uebung plant. Plant sie eine andere -- genau die
    /// eben dauerhaft getauschte --, faellt der heutige Tausch weg: sonst
    /// stuende die neue Uebung als geplant UND als Tausch da. Ein verfallener
    /// Ablauf (12 h) gibt nichts weiter, und mit ihm bleibt sein Alter, damit
    /// ein Tausch nicht durch eine neue Version verlaengert wird.
    private func mitHeutigenTauschen(aus alt: PlanLauf, in neu: PlanLauf, jetzt: Date) -> PlanLauf {
        guard alt.einheitKey == neu.einheitKey,
              jetzt.timeIntervalSince(alt.erstelltAm) <= Self.verfallOhneSatz else { return neu }
        var zustand = neu.zustand
        var uebernommen = false
        for position in alt.zustand.positionen where position.status == .getauscht {
            guard let ersatz = position.ersatzExerciseId,
                  zustand.positionen.contains(where: { $0.key == position.key && $0.exerciseId == position.exerciseId })
            else { continue }
            zustand = TrainingsplanAblauf.tauschen(zustand, positionKey: position.key,
                                                   ersatz: (exerciseId: ersatz, hauptmuskeln: position.hauptmuskeln))
            uebernommen = true
        }
        guard uebernommen else { return neu }
        return PlanLauf(planId: neu.planId, version: neu.version, einheitKey: neu.einheitKey,
                        zustand: zustand, stand: neu.stand, gebundeneSessionId: nil, erstelltAm: alt.erstelltAm,
                        letzterSatzAm: nil)
    }

    /// Ein ungebundener Ablauf gilt weiter, solange Plan, Version und
    /// Einheit stimmen und er nicht verfallen ist.
    private func passt(_ lauf: PlanLauf, jetzt: Date) -> Bool {
        guard let vorlage = datei.vorlage else { return false }
        return lauf.planId == vorlage.planId
            && lauf.version == vorlage.version
            && lauf.einheitKey == gewaehlteEinheit(vorlage)
            && jetzt.timeIntervalSince(lauf.erstelltAm) <= Self.verfallOhneSatz
    }

    /// Die lokal zuletzt beendete Einheit geht dem Server vor, solange er sie
    /// noch nicht kennen kann; sonst seine naechste, ohne sie die erste.
    private func gewaehlteEinheit(_ vorlage: PlanVorlage) -> String {
        if let zuletzt = datei.lokalZuletzt, vorlage.einheitKeys.contains(zuletzt.einheitKey) {
            return TrainingsplanFolge.naechsteEinheitKey(einheitKeys: vorlage.einheitKeys, zuletzt: zuletzt.einheitKey)
        }
        if let server = vorlage.serverNaechste, vorlage.einheitKeys.contains(server) { return server }
        return vorlage.einheitKeys[0]
    }

    private func neuerLauf(_ vorlage: PlanVorlage, jetzt: Date) -> PlanLauf {
        let key = gewaehlteEinheit(vorlage)
        return PlanLauf(
            planId: vorlage.planId, version: vorlage.version,
            einheitKey: key,
            zustand: AblaufZustand(positionen: vorlage.positionen[key] ?? [], ungeplanteGesehen: []),
            stand: 0, gebundeneSessionId: nil, erstelltAm: jetzt, letzterSatzAm: nil)
    }

    private func speichern() {
        guard datei != aufPlatte else { return }
        fileStore.save(datei)
        aufPlatte = datei
    }
}

// MARK: - Gespeicherte Form

/// Alles, was einen Neustart ueberdauern muss, in einer Datei: Ablauf und
/// lokale Zaehlung gehoeren zusammen, getrennte Dateien koennten nach einem
/// Absturz zwischen zwei Schreibvorgaengen einander widersprechen.
struct PlanAblaufDatei: Codable, Equatable {
    /// Der Plan des aktuellen Orts, auf das reduziert, was der Ablauf braucht.
    /// Damit kann der Speicher die naechste Einheit selbst bauen, auch wenn
    /// eine neue Session ohne neuen Bootstrap beginnt.
    var vorlage: PlanVorlage?
    var lauf: PlanLauf?
    var lokalZuletzt: LokalZuletzt?
    var zuletztBeendet: BeendeterLauf?

    var istLeer: Bool { vorlage == nil && lauf == nil && lokalZuletzt == nil && zuletztBeendet == nil }
}

struct PlanVorlage: Codable, Equatable {
    let planId: String
    let version: Int
    let einheitKeys: [String]
    /// Ausgangszustand je Einheit, alle Positionen offen.
    let positionen: [String: [AblaufPosition]]
    let serverNaechste: String?
    /// einheitenErledigt des Bootstraps; optional, damit eine Datei von
    /// davor lesbar bleibt (synthetisiertes Decodable nimmt dann nil).
    let serverErledigt: Int?

    init(_ plan: Trainingsplan) {
        planId = plan.planId
        version = plan.version
        einheitKeys = plan.einheiten.map(\.key)
        var positionen: [String: [AblaufPosition]] = [:]
        for einheit in plan.einheiten {
            positionen[einheit.key] = einheit.positionen.map {
                AblaufPosition(key: $0.key, exerciseId: $0.exerciseId, hauptmuskeln: $0.hauptmuskeln,
                               cardio: $0.baustein == "cardio", status: .offen, ersatzExerciseId: nil)
            }
        }
        self.positionen = positionen
        serverNaechste = plan.naechsteEinheitKey
        serverErledigt = plan.einheitenErledigt
    }
}

/// Der Ablauf einer Einheit, ab dem ersten Satz an eine Session gebunden.
struct PlanLauf: Codable, Equatable {
    let planId: String
    let version: Int
    let einheitKey: String
    var zustand: AblaufZustand
    var stand: Int
    var gebundeneSessionId: UUID?
    let erstelltAm: Date
    var letzterSatzAm: Date?

    var momentaufnahme: PlanMomentaufnahme {
        PlanMomentaufnahme(
            planId: planId, einheitKey: einheitKey, stand: stand,
            positionen: zustand.positionen.map {
                // exerciseId ist die ERSATZuebung, sonst nil (workout.ts sessionPlanSchema).
                PlanMomentaufnahme.Position(key: $0.key, status: $0.status.momentaufnahme, exerciseId: $0.ersatzExerciseId)
            })
    }
}

/// Die lokal zuletzt beendete Einheit des Plans. Eine Datei von vorher nennt
/// dazu noch eine `studioId`; sie wird beim Lesen ignoriert.
struct LokalZuletzt: Codable, Equatable {
    let einheitKey: String
    /// Wann die Einheit lokal beendet wurde -- fuer die Vier-Stunden-Regel
    /// in `nachBootstrap`.
    let beendetAm: Date
    /// einheitenErledigt des Servers beim Beenden; nil, wenn unbekannt.
    let serverErledigtVorher: Int?

    /// Dieselbe Einheit wie der Lauf, unabhaengig vom Zeitpunkt.
    func betrifft(_ lauf: PlanLauf) -> Bool {
        einheitKey == lauf.einheitKey
    }
}

// In einer Extension, damit der memberwise init erhalten bleibt.
extension LokalZuletzt {
    private enum CodingKeys: String, CodingKey {
        case einheitKey, beendetAm, serverErledigtVorher
    }

    /// Eine Datei von vor `beendetAm` bleibt lesbar. Ohne Zeitpunkt gilt die
    /// Zaehlung als laengst beendet: der naechste frische Bootstrap bei leerer
    /// Warteschlange gibt sie ab (Vier-Stunden-Regel), so haelt sie sich nie ewig.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        einheitKey = try c.decode(String.self, forKey: .einheitKey)
        beendetAm = try c.decodeIfPresent(Date.self, forKey: .beendetAm) ?? .distantPast
        serverErledigtVorher = try c.decodeIfPresent(Int.self, forKey: .serverErledigtVorher)
    }
}

struct BeendeterLauf: Codable, Equatable {
    let lauf: PlanLauf
    let gezaehlt: Bool
    let lokalZuletztVorher: LokalZuletzt?
}

private extension PositionStatus {
    var momentaufnahme: PlanMomentaufnahme.Status {
        switch self {
        case .offen: .offen
        case .erledigt: .erledigt
        case .optional: .optional
        case .getauscht: .getauscht
        }
    }
}

/// Wie SessionFileStore: App-Support, atomar geschrieben, Verzeichnis fuer
/// Tests injizierbar.
final class PlanAblaufFileStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("plan-ablauf.json")
    }

    func load() -> PlanAblaufDatei? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PlanAblaufDatei.self, from: data)
    }

    func save(_ datei: PlanAblaufDatei) {
        guard !datei.istLeer else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(datei) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
