import Foundation
import Observation

/// Der Ausschnitt aus `APIClient`, den der dauerhafte Tausch braucht -- als
/// eigenes Protokoll, damit die Tests eine Attrappe einsetzen (der Debug-Build
/// zeigt auf Prod). `throws(APIError)` wie `ProfilSchreibend`, sonst passte
/// der Actor `APIClient` nicht.
protocol PlanTauschend: Sendable {
    func swapPlanPosition(planId: String, einheitKey: String, positionKey: String, exerciseId: String,
                          modelId: String, grund: String?, ortId: String?) async throws(APIError) -> Trainingsplan
}

extension APIClient: PlanTauschend {}

/// Ein Tauschkandidat, wie die Liste 3.2 ihn zeigt.
struct TauschKandidat: Equatable, Hashable, Identifiable {
    let exerciseId: String
    /// Das Katalogmodell, das der Server beim Tausch erwartet.
    let modelId: String
    let name: String
    /// Das Label des Geraets; nil, wenn der Bootstrap es nicht kennt.
    let geraet: String?
    /// Namen der Hauptmuskeln, "Brust, Schulter vorn"; nil ohne Angabe.
    let muskeln: String?
    /// Schluessel der Hauptmuskeln -- der Ablauf haengt optionale Positionen
    /// an ihnen auf (`TrainingsplanAblauf.nachSatz`, Regel 2).
    let hauptmuskeln: [String]
    let vorschaubildModell: String?

    /// Dieselbe Uebung kann an zwei Modellen stehen; erst beide zusammen
    /// sind eindeutig.
    var id: String { "\(exerciseId):\(modelId)" }

    var untertitel: String {
        [geraet, muskeln].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Alles, was Sheet 3.1-3.3 zu einer angetippten Planzeile wissen muss, als
/// fester Wert beim Antippen: der Bootstrap darf sich waehrend des Sheets
/// aendern (409 laedt neu), die angezeigte Position bleibt dieselbe.
struct PlanTauschAuftrag: Equatable, Identifiable {
    let planId: String
    let einheitKey: String
    /// Die Position im Bootstrap-Plan (Vorgabe, Baustein, Modell).
    let position: TrainingsplanPosition
    /// Der Status im heutigen Ablauf; ohne Ablauf offen.
    let status: PositionStatus
    /// Die Uebung, die ein Start meint: der heutige Ersatz, sonst die geplante.
    let uebungId: String
    /// Der Name der geplanten Uebung (wie die Zeile).
    let name: String
    /// Der heutige Ersatz bei einem Tausch nur heute.
    let ersatzName: String?
    /// "Vorgesehen am Gerät ..."; nil, wenn das nicht sicher stimmt.
    let vorgesehen: String?
    let kandidaten: [TauschKandidat]
    /// Der aktive Ort fuer "Gibt es hier nicht": Studio-ID, im Freien Training
    /// die Katalog-Studio-ID; nil, solange beides fehlt.
    var ort: String? = nil
    /// Nur offene und heute getauschte Kraftpositionen: der Ablauf tauscht
    /// sonst nichts (`TrainingsplanAblauf.tauschen`), und eine Wahl, die nichts
    /// bewirkt, waere eine Luege.
    let tauschbar: Bool
    /// Saetze der wirksamen Uebung (Ersatz, sonst geplant) in dieser Session,
    /// an welchem Geraet auch immer.
    var satzGemacht = 0
    /// Die Satzvorgabe der Position.
    var satzGeplant = 0
    /// Cardio zaehlt keine Saetze.
    var cardio = false
    /// Heute ausgelassen: das Sheet bietet "Doch machen" statt Start.
    var istAusgelassen = false

    /// Der Hauptknopf: nach angefangenen Saetzen "Weiter mit Satz X" -- auch
    /// wenn die Position schon erledigt ist (der erste Satz hakt sie ab, das
    /// Mitglied darf trotzdem weitermachen).
    var weiterTitel: String {
        !cardio && satzGemacht > 0 ? "Weiter mit Satz \(satzGemacht + 1)" : "Übung starten"
    }

    var id: String { "\(planId):\(einheitKey):\(position.key)" }

    /// "Andere Übung wählen" nur mit Kandidaten -- nie eine leere Liste
    /// oeffnen (Review Focus 3).
    var zeigtAndereUebung: Bool { tauschbar && !kandidaten.isEmpty }

    /// Die Wahl in "Warum wechselst du?". "Gefällt mir nicht" merkt sich der
    /// Server nur zusammen mit einem Ersatz; ohne Ersatz gibt es zwei.
    func entfernOptionen(mitErsatz: Bool) -> [PlanTausch.EntfernOption] {
        mitErsatz ? [.heuteAuslassen, .belegt, .gefaelltNicht] : [.heuteAuslassen, .belegt]
    }
}

/// Reine Ableitungen fuer den Tausch einer Planposition (Trainingsplan
/// Etappe 3, Task 12, Entwuerfe 3.1-3.3). Die Regeln, was der Server
/// annimmt (Baustein, Studio, "meiden"), stehen nur dort; die Liste kommt
/// schon gefiltert im Bootstrap (`alternativen`).
enum PlanTausch {
    /// Eine Antwort auf "Warum wechselst du?" (Entwurf 4). Texte sind ein
    /// Entwurf, Tim liest sie vor dem Merge.
    enum EntfernOption: Equatable, Sendable {
        case heuteAuslassen, belegt, gefaelltNicht

        var titel: String {
            switch self {
            case .heuteAuslassen: "Heute auslassen"
            case .belegt: "Belegt"
            case .gefaelltNicht: "Übung gefällt mir nicht"
            }
        }

        /// Der Wert, den der Server als `grund` erwartet; nil = nichts merken.
        var serverGrund: String? {
            self == .gefaelltNicht ? "gefaellt_nicht" : nil
        }
    }

    /// Der Ort der Merkliste: das aktive Studio, im Freien Training die
    /// Katalog-Studio-ID des Bootstraps.
    static func ort(aktivesStudio: String?, bootstrap: BootstrapResponse?) -> String? {
        aktivesStudio ?? bootstrap?.catalog?.studioId
    }

    /// Wie oben, mit der Merkliste des Plans: ohne die Uebungen, die am Ort
    /// fehlen. "Gefällt mir nicht" bleibt drin, der Server stellt es nach hinten.
    static func kandidaten(position: TrainingsplanPosition, plan: Trainingsplan, ort: String?,
                           belegt: Set<String>, uebungen: BootstrapResponse?) -> [TauschKandidat] {
        let fehlt = Set(ort.flatMap { plan.merkliste.nichtVorhanden[$0] } ?? [])
        return kandidaten(position: position, alternativen: plan.alternativen,
                          belegt: belegt.union(fehlt), uebungen: uebungen)
    }

    /// Die Kandidaten des Bausteins der Position in Serverreihenfolge
    /// ("vorsichtig" steht dort schon hinten), ohne die Uebung der Position
    /// und ohne `belegt` (was die Einheit schon fuehrt: sonst stuende eine
    /// Uebung zweimal in der Einheit).
    ///
    /// `uebungen` ist der Bootstrap: Namen, Geraet, Muskeln und Bild kommen
    /// aus seinen Geraeten, der Name notfalls aus dem Katalog.
    static func kandidaten(position: TrainingsplanPosition, alternativen: [String: [PlanAlternative]],
                           belegt: Set<String>, uebungen: BootstrapResponse?) -> [TauschKandidat] {
        let ausgeschlossen = belegt.union([position.exerciseId])
        return (alternativen[position.baustein] ?? []).compactMap { alternative in
            guard !ausgeschlossen.contains(alternative.exerciseId) else { return nil }
            let maschine = uebungen?.aktivesGeraet(modellId: alternative.modelId, exerciseId: alternative.exerciseId)
            // Ohne Studio-Geraet (Freies Training, Geraet fehlt): Muskeln und
            // Bezeichnung des Katalogtyps.
            let typ = maschine == nil
                ? uebungen?.katalogTyp(modellId: alternative.modelId, exerciseId: alternative.exerciseId) : nil
            let uebung = maschine?.exercises.first { $0.id == alternative.exerciseId }
                ?? typ?.exercises.first { $0.id == alternative.exerciseId }
            let primaer = (uebung?.muscles ?? []).filter { $0.role == .primary }
            return TauschKandidat(
                exerciseId: alternative.exerciseId,
                modelId: alternative.modelId,
                name: PlanZeilenModell.uebungsname(exerciseId: alternative.exerciseId, maschine: maschine,
                                                   bootstrap: uebungen),
                geraet: maschine?.label ?? typ?.name,
                muskeln: primaer.isEmpty ? nil : primaer.map(\.name).joined(separator: ", "),
                hauptmuskeln: primaer.map(\.key),
                vorschaubildModell: alternative.modelId)
        }
    }

    /// Der Auftrag zur angetippten Zeile. Status, geplante Uebung und was
    /// die Einheit schon fuehrt, kommen aus dem Ablauf (gebundene Version,
    /// wie die Zeile selbst -- `PlanAnzeige.planstellen`).
    static func auftrag(position: TrainingsplanPosition, heute: PlanAnzeige.Heute,
                        bootstrap: BootstrapResponse?, ort: String? = nil,
                        bloecke: [LokalerBlock] = []) -> PlanTauschAuftrag {
        let stellen = PlanAnzeige.planstellen(einheit: heute.einheit, zustand: heute.zustand)
        let stelle = stellen.first { $0.key == position.key }
        // Geplant und heute getauscht, auch die eigene: die geplante Uebung
        // gehoert der Position ohnehin, ihr heutiger Ersatz steht schon da.
        let belegt = Set(stellen.flatMap { [$0.geplant, $0.ersatz].compactMap { $0 } })
        let status = stelle?.status ?? .offen
        let cardio = stelle?.cardio ?? (position.baustein == "cardio")
        let geplant = stelle?.geplant ?? position.exerciseId
        return PlanTauschAuftrag(
            planId: heute.plan.planId,
            einheitKey: heute.einheitKey,
            position: position,
            status: status,
            uebungId: stelle?.wirksam ?? position.exerciseId,
            name: name(geplant, bootstrap),
            ersatzName: stelle?.ersatz.map { name($0, bootstrap) },
            vorgesehen: status == .offen && geplant == position.exerciseId
                ? vorgesehen(position: position, bootstrap: bootstrap) : nil,
            kandidaten: kandidaten(position: position, plan: heute.plan, ort: ort,
                                   belegt: belegt, uebungen: bootstrap),
            ort: ort,
            tauschbar: !cardio && (status == .offen || status == .getauscht),
            satzGemacht: PlanAnzeige.satzzahl(exerciseId: stelle?.wirksam ?? position.exerciseId, bloecke: bloecke),
            satzGeplant: position.saetze,
            cardio: cardio,
            istAusgelassen: heute.ausgelassen.contains(position.key))
    }

    // MARK: - Texte

    /// "3 Sätze", "8–12 Wdh.", "Pause 2:30", "Reserve 1–3" (Entwurf 3.1);
    /// Cardio nur die Dauer -- Wiederholungen und Reserve gibt es am Fahrrad nicht.
    static func vorgabeTags(_ position: TrainingsplanPosition) -> [String] {
        if position.baustein == "cardio" || position.dauerMin != nil {
            return position.dauerMin.map { ["\($0) Min"] } ?? []
        }
        var tags = [position.saetze == 1 ? "1 Satz" : "\(position.saetze) Sätze"]
        if let von = position.wdhVon, let bis = position.wdhBis {
            tags.append(von == bis ? "\(von) Wdh." : "\(von)–\(bis) Wdh.")
        }
        // 0 s waere ein Datenfehler (nur Cardio hat keine Pause): dann kein Tag
        // statt "Pause 0:00".
        if position.pauseSek > 0 {
            tags.append("Pause \(position.pauseSek / 60):\(String(format: "%02d", position.pauseSek % 60))")
        }
        tags.append(position.reserveVon == position.reserveBis
                    ? "Reserve \(position.reserveVon)"
                    : "Reserve \(position.reserveVon)–\(position.reserveBis)")
        return tags
    }

    /// Nur, wenn ein aktives Geraet des Modells der Position die Uebung fuehrt;
    /// ein stillgelegtes Geraet zu nennen, schickte das Mitglied an ein
    /// abgedecktes Geraet. Der Ablauf zaehlt jedes Geraet mit derselben
    /// Uebung, das sagt der zweite Satz.
    static func vorgesehen(position: TrainingsplanPosition, bootstrap: BootstrapResponse?) -> String? {
        guard let maschine = bootstrap?.aktivesGeraet(modellId: position.modelId, exerciseId: position.exerciseId)
        else { return nil }
        return "Vorgesehen am Gerät „\(maschine.label)“. Jedes andere Gerät mit dieser Übung zählt auch."
    }

    /// Untertitel des Schalters (Entwurf 3.2).
    static func dauerhaftHinweis(einheitKey: String) -> String {
        "Gilt für alle künftigen \(einheitenPlural(einheitKey)). Heute ändert sich nichts anderes."
    }

    /// Text der Bestaetigung (Entwurf 3.3). Ohne Artikel vor dem Namen: der
    /// Katalog kennt das Geschlecht der Uebung nicht ("die Schrägbankpresse",
    /// "das Schulterdrücken").
    static func bestaetigungsHinweis(einheitKey: String, uebung: String) -> String {
        "Ab der nächsten \(einheitSingular(einheitKey)) steht hier: \(uebung)."
    }

    /// Was nach einem gescheiterten "Übernehmen" im Sheet steht. Immer mit
    /// dem, was gilt (designsystem.md SS5): der Plan ist unveraendert.
    static func fehlerText(_ fehler: APIError) -> String {
        switch fehler {
        case .offline:
            "Keine Verbindung. Dein Plan bleibt, wie er ist. Versuch es gleich noch einmal."
        case .conflict:
            "Dein Plan hat sich inzwischen geändert und ist neu geladen. Versuch es noch einmal."
        case .validation, .notFound, .planNichtMoeglich, .profilUnvollstaendig:
            "Diese Übung passt gerade nicht in deinen Plan. Dein Plan bleibt, wie er ist."
        case .unauthorized:
            "Deine Anmeldung ist abgelaufen. Dein Plan bleibt, wie er ist."
        case .server, .encodingFailed, .decodingFailed:
            "Das hat nicht geklappt. Dein Plan bleibt, wie er ist. Versuch es noch einmal."
        }
    }

    /// "Einheiten A"; "Oberkörper A" bleibt ein Name in Anfuehrung, sonst
    /// hiesse es "Einheiten Oberkörper A".
    private static func einheitenPlural(_ key: String) -> String {
        let name = EinheitName.text(key)
        return name == "Einheit \(key)" ? "Einheiten \(key)" : "Einheiten „\(name)“"
    }

    private static func einheitSingular(_ key: String) -> String {
        let name = EinheitName.text(key)
        return name == "Einheit \(key)" ? name : "Einheit „\(name)“"
    }

    private static func name(_ exerciseId: String, _ bootstrap: BootstrapResponse?) -> String {
        PlanZeilenModell.uebungsname(exerciseId: exerciseId, maschine: nil, bootstrap: bootstrap)
    }
}

/// Der Ablauf hinter Sheet 3.1-3.3 ohne View, damit "nur heute",
/// "dauerhaft", offline und Fehler mit Attrappen pruefbar sind (wie
/// `BeschwerdenSitzung`).
///
/// - Schalter aus + "Wählen": Tausch nur im heutigen Ablauf, ohne Netz.
/// - Schalter an + "Wählen": erst die Bestaetigung (3.3), "Übernehmen"
///   schreibt eine neue aktive Planversion beim Server und laedt dann den
///   Bootstrap neu (die Antwort des Schreibwegs kennt die App-Felder nicht).
/// - Eine laufende Einheit (Ablauf an eine Session gebunden) behaelt ihre
///   Version (Review Focus 2): "dauerhaft" aendert ihren Ablauf nicht.
@MainActor
@Observable
final class PlanTauschSitzung {
    enum Schritt: Equatable {
        case vorgabe
        case kandidaten
        /// "Übung entfernen": die Frage nach dem Grund.
        case entfernen
        case bestaetigen(TauschKandidat)
    }

    let auftrag: PlanTauschAuftrag
    private(set) var schritt: Schritt = .vorgabe
    private(set) var dauerhaft = false
    /// Warum die Uebung dauerhaft weg soll; nil bei "Belegt" und beim
    /// Schalter. Nur mit Grund gehen `grund` und `ortId` an den Server.
    private(set) var grund: PlanTausch.EntfernOption?
    /// Die zuletzt gewaehlte Zeile -- "Wählen" steht dort gefuellt (3.2),
    /// auch zurueck aus der Bestaetigung.
    private(set) var gewaehlt: TauschKandidat?
    /// Der Ersatz aus der vollen Auswahl; nil = ohne Ersatz (nur auslassen).
    private(set) var ersatz: TauschKandidat?
    /// Die vorgewaehlte Zeile von "Warum wechselst du?".
    private(set) var gewaehlteOption: PlanTausch.EntfernOption = .heuteAuslassen
    private(set) var schreibtGerade = false
    private(set) var fehler: APIError?

    @ObservationIgnored private let client: any PlanTauschend
    @ObservationIgnored private let ablauf: TrainingsplanAblaufStore
    @ObservationIgnored private let istOnline: @MainActor () -> Bool
    @ObservationIgnored private let aktuellePlanId: @MainActor () -> String?
    @ObservationIgnored private let neuLaden: @MainActor () async -> Void

    /// - `istOnline`: liest der View-Body mit; `NetzwerkMonitor` ist
    ///   beobachtbar, so folgt der Schalter der Verbindung.
    /// - `aktuellePlanId`: die aktive Version laut Bootstrap. Nach einem 409
    ///   ist sie neu geladen, ein Wiederholen geht an sie statt erneut an die
    ///   ersetzte.
    /// - `neuLaden`: Bootstrap laden und den Ablauf vorbereiten lassen.
    init(auftrag: PlanTauschAuftrag, client: any PlanTauschend, ablauf: TrainingsplanAblaufStore,
         istOnline: @escaping @MainActor () -> Bool,
         aktuellePlanId: @escaping @MainActor () -> String?,
         neuLaden: @escaping @MainActor () async -> Void) {
        self.auftrag = auftrag
        self.client = client
        self.ablauf = ablauf
        self.istOnline = istOnline
        self.aktuellePlanId = aktuellePlanId
        self.neuLaden = neuLaden
    }

    /// Den Schalter einschalten braucht Verbindung; ausschalten geht immer --
    /// sonst saesse fest, wer offline ging, waehrend er an war.
    var dauerhaftMoeglich: Bool { istOnline() }

    func andereUebung() {
        guard auftrag.zeigtAndereUebung else { return }
        schritt = .kandidaten
    }

    /// Ein Ersatz ist gewaehlt (oder keiner): die Frage nach dem Grund.
    func ersatzGewaehlt(_ kandidat: TauschKandidat?) {
        ersatz = kandidat
        grund = nil
        dauerhaft = false
        fehler = nil
        gewaehlteOption = .heuteAuslassen
        schritt = .entfernen
    }

    /// Die Zeilen der Frage; ohne Ersatz entfaellt "Übung gefällt mir nicht".
    var optionen: [PlanTausch.EntfernOption] { auftrag.entfernOptionen(mitErsatz: ersatz != nil) }

    /// "Übung gefällt mir nicht" geht an den Server und braucht Verbindung.
    func optionMoeglich(_ option: PlanTausch.EntfernOption) -> Bool {
        optionen.contains(option) && (option.serverGrund == nil || istOnline())
    }

    /// Das Auswaehlen einer Zeile; bestaetigt wird erst mit "Übung wechseln".
    func optionAuswaehlen(_ option: PlanTausch.EntfernOption) {
        guard schritt == .entfernen, optionMoeglich(option) else { return }
        gewaehlteOption = option
    }

    /// "Übung wechseln": bestaetigt die gewaehlte Zeile.
    @discardableResult
    func optionBestaetigen() -> Bool { grundWaehlen(gewaehlteOption) }

    /// Ein Grund. "Heute auslassen" und "Belegt" sind dasselbe: mit Ersatz
    /// nur heute tauschen, ohne ihn die Position auslassen -- kein Server,
    /// nichts gemerkt. "Übung gefällt mir nicht" (nur mit Ersatz, nur online)
    /// geht weiter zur Bestaetigung und tauscht dauerhaft mit Grund.
    /// `true` = das Sheet darf zu.
    @discardableResult
    func grundWaehlen(_ option: PlanTausch.EntfernOption) -> Bool {
        guard schritt == .entfernen, optionMoeglich(option) else { return false }
        fehler = nil
        switch option {
        case .heuteAuslassen, .belegt:
            guard let ersatz else {
                ablauf.auslassen(positionKey: auftrag.position.key)
                return true
            }
            return waehlen(ersatz)
        case .gefaelltNicht:
            guard let ersatz else { return false }
            grund = option
            dauerhaft = true
            gewaehlt = ersatz
            schritt = .bestaetigen(ersatz)
            return false
        }
    }

    /// Rueckfall nach einem Fehler in der Bestaetigung: der Server nimmt die
    /// Uebung nicht, heute tauscht sie trotzdem. `true` = das Sheet darf zu.
    func nurHeuteTauschen() -> Bool {
        guard case .bestaetigen(let kandidat) = schritt, !schreibtGerade, auftrag.tauschbar else { return false }
        ablauf.tauschen(positionKey: auftrag.position.key,
                        ersatz: (exerciseId: kandidat.exerciseId, hauptmuskeln: kandidat.hauptmuskeln))
        fehler = nil
        return true
    }

    func dauerhaftSetzen(_ an: Bool) {
        // Waehrend "Übernehmen" schreibt, gilt, was bestaetigt wurde: sonst
        // schloesse das Sheet nach Erfolg mit einem Tausch, den der Schalter
        // scheinbar abgesagt hat, und ein Fehler landete in der Liste, die
        // keinen zeigt. Das Sheet sperrt den Schalter dann auch.
        guard !schreibtGerade, grund == nil else { return }
        if an && !istOnline() { return }
        dauerhaft = an
        fehler = nil
        // Ausschalten in der Bestaetigung fuehrt zurueck zur Liste: ohne
        // Schalter gibt es nichts zu bestaetigen.
        if !an, case .bestaetigen = schritt { schritt = .kandidaten }
    }

    /// "Wählen". `true` = nur heute getauscht, das Sheet darf zu.
    func waehlen(_ kandidat: TauschKandidat) -> Bool {
        // Auch ein Ersatz ausserhalb der Kandidaten (volle Auswahl); ob er in
        // den Plan passt, entscheidet der Server beim dauerhaften Tausch.
        guard auftrag.tauschbar else { return false }
        gewaehlt = kandidat
        if dauerhaft {
            // Auch offline in die Bestaetigung: "Übernehmen" sagt dort, warum
            // es nicht geht. Still nur fuer heute zu tauschen, obwohl der
            // Schalter an steht, taete etwas anderes als verlangt.
            fehler = nil
            schritt = .bestaetigen(kandidat)
            return false
        }
        ablauf.tauschen(positionKey: auftrag.position.key,
                        ersatz: (exerciseId: kandidat.exerciseId, hauptmuskeln: kandidat.hauptmuskeln))
        return true
    }

    /// "Abbrechen" in der Bestaetigung: zurueck zur Liste, nichts geschrieben.
    func abbrechen() {
        guard case .bestaetigen = schritt else { return }
        fehler = nil
        // Ein Grund kam aus der Frage, der Schalter aus der Liste.
        schritt = grund == nil ? .kandidaten : .entfernen
        if grund != nil { grund = nil; dauerhaft = false }
    }

    /// "Übernehmen". `true` = die neue Version steht beim Server, das Sheet
    /// darf zu. Bei jedem Fehler bleibt es offen und nennt ihn.
    func uebernehmen() async -> Bool {
        guard case .bestaetigen(let kandidat) = schritt, !schreibtGerade else { return false }
        guard istOnline() else {
            fehler = .offline
            return false
        }
        schreibtGerade = true
        defer { schreibtGerade = false }
        do throws(APIError) {
            _ = try await client.swapPlanPosition(
                planId: aktuellePlanId() ?? auftrag.planId, einheitKey: auftrag.einheitKey,
                positionKey: auftrag.position.key, exerciseId: kandidat.exerciseId, modelId: kandidat.modelId,
                grund: grund?.serverGrund, ortId: grund == nil ? nil : auftrag.ort)
        } catch {
            fehler = error
            // 409: der Plan ist nicht mehr der aktive (anderes Geraet, Trainer).
            // Neu laden, damit ein Wiederholen die richtige Version trifft.
            if case .conflict = error { await neuLaden() }
            return false
        }
        fehler = nil
        // Vor dem ersten Satz gilt die neue Version schon heute: sofort im
        // Ablauf zeigen, auch falls das Neuladen gleich scheitert. Kommt die
        // neue Version an, ersetzt sie den Ablauf; dort ist die Uebung dann
        // geplant und der Tausch faellt weg (TrainingsplanAblaufStore,
        // `mitHeutigenTauschen`) -- nichts doppelt. Eine laufende Einheit
        // bleibt unberuehrt (Review Focus 2).
        if ablauf.gebundeneSessionId == nil, ablauf.planId == auftrag.planId,
           ablauf.einheitKey == auftrag.einheitKey {
            ablauf.tauschen(positionKey: auftrag.position.key,
                            ersatz: (exerciseId: kandidat.exerciseId, hauptmuskeln: kandidat.hauptmuskeln))
        }
        await neuLaden()
        return true
    }
}

extension BootstrapResponse {
    /// Ein aktives Studio-Geraet, das die Uebung fuehrt und zum Modell passt.
    /// Das Modell einer Planposition ist ein Katalogtyp; ein Studio-Geraet hat
    /// ein eigenes `equipmentModel` und verweist ueber `catalogModelId` darauf.
    func aktivesGeraet(modellId: String, exerciseId: String) -> Machine? {
        machines.first {
            $0.status == "active"
                && ($0.equipmentModel.id == modellId || $0.equipmentModel.catalogModelId == modellId)
                && $0.exercises.contains { $0.id == exerciseId }
        }
    }

    /// Der Katalogtyp des Modells, wenn er die Uebung fuehrt.
    func katalogTyp(modellId: String, exerciseId: String) -> Catalog.EquipmentType? {
        catalog?.equipmentTypes.first { $0.id == modellId && $0.exercises.contains { $0.id == exerciseId } }
    }
}
