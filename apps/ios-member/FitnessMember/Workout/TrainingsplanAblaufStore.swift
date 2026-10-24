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

    /// Die Einheit, die als naechste vorbereitet wuerde -- fuer "Nächstes Mal
    /// ist Einheit B dran", wenn der Ablauf nach dem Beenden leer ist.
    var naechsteEinheitKey: String? { datei.vorlage.map(gewaehlteEinheit) }

    // MARK: - Vorbereiten

    /// Bequemer Einstieg fuer die Wurzel: der Plan des Studios aus dem Bootstrap.
    func vorbereiten(bootstrap: BootstrapResponse?, studioId: String?, jetzt: Date = Date()) {
        let plan = studioId.flatMap { id in bootstrap?.member.plans.first { $0.studioId == id } }
        vorbereiten(plan: plan, studioId: studioId, jetzt: jetzt)
    }

    /// Haelt den Plan des Orts fest und baut den Ablauf der heutigen Einheit,
    /// falls noch keiner passt. Idempotent: die Wurzel ruft das nach jedem
    /// Bootstrap, Ortswechsel und Vordergrund.
    ///
    /// Ein Ablauf mit gebundener Session (es ging schon ein Satz raus) behaelt
    /// seine Planversion, auch wenn der Bootstrap inzwischen eine neuere nennt
    /// (Review Focus 2): der Server hat die Session an diese Version gebunden,
    /// und ein Wechsel mitten in der Einheit aenderte ihre Zaehlung.
    func vorbereiten(plan: Trainingsplan?, studioId: String?, jetzt: Date = Date()) {
        datei.vorlage = plan.flatMap { p in
            p.studioId == studioId && !p.einheiten.isEmpty ? PlanVorlage(p) : nil
        }

        if let lauf = datei.lauf, lauf.gebundeneSessionId != nil {
            let letzte = lauf.letzterSatzAm ?? lauf.erstelltAm
            guard jetzt.timeIntervalSince(letzte) > WorkoutSessionStore.sessionPause else {
                speichern()
                return
            }
            // Vier Stunden ohne Satz: die Session ist auch fuer den Server
            // vorbei (Auto-Abschluss) und zaehlt wie eine beendete.
            abschliessen()
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
    /// nil ohne Plan, im Freien Training und in einem anderen Studio als dem
    /// des Plans (Review Focus 4) -- dann bleibt auch alles unberuehrt: der
    /// Satz geht wie bisher ohne `plan` raus.
    ///
    /// `studioId` ist der Ort der EINHEIT, nicht des Geraets: der Server
    /// prueft den Plan gegen das Studio der Session.
    func nachSatz(sessionId: UUID, studioId: String?, satz: AblaufSatz, jetzt: Date = Date()) -> PlanMomentaufnahme? {
        guard let studioId else { return nil }
        // Dieselbe Session in einem anderen Studio: der Server hat sie an den
        // Plan ihres Studios gebunden, ein anderer Plan gilt fuer sie nie.
        if let vorhanden = datei.lauf, vorhanden.gebundeneSessionId == sessionId,
           vorhanden.studioId != studioId { return nil }
        var lauf: PlanLauf
        if let vorhanden = datei.lauf, vorhanden.studioId == studioId,
           vorhanden.gebundeneSessionId == nil || vorhanden.gebundeneSessionId == sessionId {
            lauf = vorhanden
        } else if let vorlage = datei.vorlage, vorlage.studioId == studioId {
            // Eine neue Session, obwohl der Ablauf noch an einer anderen
            // haengt: die alte ist vorbei (sonst gaebe es keine neue
            // Kennung). Sie zaehlt wie beendet, und die neue bekommt die
            // naechste Einheit -- nicht den Ablauf der alten.
            if datei.lauf?.gebundeneSessionId != nil { abschliessen() }
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
    /// die Einheit als zuletzt gemacht -- bis ein Bootstrap bei leerer
    /// Warteschlange das selbst weiss. Danach ist der Ablauf leer.
    func einheitBeendet() {
        guard let lauf = datei.lauf else { return }
        if lauf.gebundeneSessionId != nil {
            abschliessen()
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
            if beendet.gezaehlt, datei.lokalZuletzt == beendet.lauf.alsZuletzt {
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
        if beendet.gezaehlt, datei.lokalZuletzt == beendet.lauf.alsZuletzt {
            datei.lokalZuletzt = beendet.lokalZuletztVorher
        }
        datei.lauf = beendet.lauf
        datei.zuletztBeendet = nil
        speichern()
    }

    /// Nach einem frisch geladenen Bootstrap. Ist nichts mehr offen, kennt
    /// der Server jede beendete Einheit, und seine naechste Einheit gilt
    /// wieder; mit offenen Saetzen kann er hinterherhinken.
    func nachBootstrap(offeneSchreibvorgaenge: Int) {
        guard offeneSchreibvorgaenge == 0, datei.lokalZuletzt != nil else { return }
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
    private func abschliessen() {
        guard let lauf = datei.lauf else { return }
        let vorher = datei.lokalZuletzt
        let gezaehlt = TrainingsplanAblauf.zaehlt(lauf.zustand)
        if gezaehlt { datei.lokalZuletzt = lauf.alsZuletzt }
        datei.zuletztBeendet = BeendeterLauf(lauf: lauf, gezaehlt: gezaehlt, lokalZuletztVorher: vorher)
        datei.lauf = nil
    }

    /// Ersetzt einen ungebundenen Ablauf, der nicht mehr passt, und baut einen,
    /// falls keiner da ist. Ein gebundener bleibt immer (Review Focus 2).
    private func ungebundenAuffrischen(jetzt: Date) {
        if let lauf = datei.lauf, lauf.gebundeneSessionId == nil, !passt(lauf, jetzt: jetzt) {
            datei.lauf = nil
        }
        if datei.lauf == nil, let vorlage = datei.vorlage {
            datei.lauf = neuerLauf(vorlage, jetzt: jetzt)
        }
    }

    /// Ein ungebundener Ablauf gilt weiter, solange Plan, Version, Ort und
    /// Einheit stimmen und er nicht verfallen ist.
    private func passt(_ lauf: PlanLauf, jetzt: Date) -> Bool {
        guard let vorlage = datei.vorlage else { return false }
        return lauf.planId == vorlage.planId
            && lauf.version == vorlage.version
            && lauf.studioId == vorlage.studioId
            && lauf.einheitKey == gewaehlteEinheit(vorlage)
            && jetzt.timeIntervalSince(lauf.erstelltAm) <= Self.verfallOhneSatz
    }

    /// Die lokal zuletzt beendete Einheit geht dem Server vor, solange er sie
    /// noch nicht kennen kann; sonst seine naechste, ohne sie die erste.
    private func gewaehlteEinheit(_ vorlage: PlanVorlage) -> String {
        if let zuletzt = datei.lokalZuletzt, zuletzt.studioId == vorlage.studioId,
           vorlage.einheitKeys.contains(zuletzt.einheitKey) {
            return TrainingsplanFolge.naechsteEinheitKey(einheitKeys: vorlage.einheitKeys, zuletzt: zuletzt.einheitKey)
        }
        if let server = vorlage.serverNaechste, vorlage.einheitKeys.contains(server) { return server }
        return vorlage.einheitKeys[0]
    }

    private func neuerLauf(_ vorlage: PlanVorlage, jetzt: Date) -> PlanLauf {
        let key = gewaehlteEinheit(vorlage)
        return PlanLauf(
            planId: vorlage.planId, version: vorlage.version, studioId: vorlage.studioId,
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
    let studioId: String
    let einheitKeys: [String]
    /// Ausgangszustand je Einheit, alle Positionen offen.
    let positionen: [String: [AblaufPosition]]
    let serverNaechste: String?

    init(_ plan: Trainingsplan) {
        planId = plan.planId
        version = plan.version
        studioId = plan.studioId
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
    }
}

/// Der Ablauf einer Einheit, ab dem ersten Satz an eine Session gebunden.
struct PlanLauf: Codable, Equatable {
    let planId: String
    let version: Int
    let studioId: String
    let einheitKey: String
    var zustand: AblaufZustand
    var stand: Int
    var gebundeneSessionId: UUID?
    let erstelltAm: Date
    var letzterSatzAm: Date?

    var alsZuletzt: LokalZuletzt { LokalZuletzt(studioId: studioId, einheitKey: einheitKey) }

    var momentaufnahme: PlanMomentaufnahme {
        PlanMomentaufnahme(
            planId: planId, einheitKey: einheitKey, stand: stand,
            positionen: zustand.positionen.map {
                // exerciseId ist die ERSATZuebung, sonst nil (workout.ts sessionPlanSchema).
                PlanMomentaufnahme.Position(key: $0.key, status: $0.status.momentaufnahme, exerciseId: $0.ersatzExerciseId)
            })
    }
}

/// Je Studio: ein Plan gilt nur dort, und eine Einheit eines anderen Studios
/// darf hier nichts weiterschalten.
struct LokalZuletzt: Codable, Equatable {
    let studioId: String
    let einheitKey: String
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
