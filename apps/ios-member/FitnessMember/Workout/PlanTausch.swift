import Foundation
import Observation

/// Der Ausschnitt aus `APIClient`, den der dauerhafte Tausch braucht -- als
/// eigenes Protokoll, damit die Tests eine Attrappe einsetzen (der Debug-Build
/// zeigt auf Prod). `throws(APIError)` wie `ProfilSchreibend`, sonst passte
/// der Actor `APIClient` nicht.
protocol PlanTauschend: Sendable {
    func swapPlanPosition(planId: String, einheitKey: String, positionKey: String, exerciseId: String,
                          modelId: String) async throws(APIError) -> Trainingsplan
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
    /// Der Name der geplanten Uebung (wie die Zeile).
    let name: String
    /// Der heutige Ersatz bei einem Tausch nur heute.
    let ersatzName: String?
    /// "Vorgesehen am Gerät ..."; nil, wenn das nicht sicher stimmt.
    let vorgesehen: String?
    let kandidaten: [TauschKandidat]
    /// Nur offene und heute getauschte Kraftpositionen: der Ablauf tauscht
    /// sonst nichts (`TrainingsplanAblauf.tauschen`), und eine Wahl, die nichts
    /// bewirkt, waere eine Luege.
    let tauschbar: Bool

    var id: String { "\(planId):\(einheitKey):\(position.key)" }

    /// "Andere Übung wählen" nur mit Kandidaten -- nie eine leere Liste
    /// oeffnen (Review Focus 3).
    var zeigtAndereUebung: Bool { tauschbar && !kandidaten.isEmpty }
}

/// Reine Ableitungen fuer den Tausch einer Planposition (Trainingsplan
/// Etappe 3, Task 12, Entwuerfe 3.1-3.3). Die Regeln, was der Server
/// annimmt (Baustein, Studio, "meiden"), stehen nur dort; die Liste kommt
/// schon gefiltert im Bootstrap (`alternativen`).
enum PlanTausch {
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
            let maschine = uebungen?.machines.first {
                $0.equipmentModel.id == alternative.modelId && $0.status == "active"
                    && $0.exercises.contains { $0.id == alternative.exerciseId }
            }
            let primaer = (maschine?.exercises.first { $0.id == alternative.exerciseId }?.muscles ?? [])
                .filter { $0.role == .primary }
            return TauschKandidat(
                exerciseId: alternative.exerciseId,
                modelId: alternative.modelId,
                name: PlanZeilenModell.uebungsname(exerciseId: alternative.exerciseId, maschine: maschine,
                                                   bootstrap: uebungen),
                geraet: maschine?.label,
                muskeln: primaer.isEmpty ? nil : primaer.map(\.name).joined(separator: ", "),
                hauptmuskeln: primaer.map(\.key),
                vorschaubildModell: alternative.modelId)
        }
    }

    /// Der Auftrag zur angetippten Zeile. Status, geplante Uebung und was
    /// die Einheit schon fuehrt, kommen aus dem Ablauf (gebundene Version,
    /// wie die Zeile selbst -- `PlanAnzeige.planstellen`).
    static func auftrag(position: TrainingsplanPosition, heute: PlanAnzeige.Heute,
                        bootstrap: BootstrapResponse?) -> PlanTauschAuftrag {
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
            name: name(geplant, bootstrap),
            ersatzName: stelle?.ersatz.map { name($0, bootstrap) },
            vorgesehen: status == .offen && geplant == position.exerciseId
                ? vorgesehen(position: position, bootstrap: bootstrap) : nil,
            kandidaten: kandidaten(position: position, alternativen: heute.plan.alternativen,
                                   belegt: belegt, uebungen: bootstrap),
            tauschbar: !cardio && (status == .offen || status == .getauscht))
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
        guard let maschine = bootstrap?.machines.first(where: {
            $0.equipmentModel.id == position.modelId && $0.status == "active"
                && $0.exercises.contains(where: { $0.id == position.exerciseId })
        }) else { return nil }
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
        case bestaetigen(TauschKandidat)
    }

    let auftrag: PlanTauschAuftrag
    private(set) var schritt: Schritt = .vorgabe
    private(set) var dauerhaft = false
    /// Die zuletzt gewaehlte Zeile -- "Wählen" steht dort gefuellt (3.2),
    /// auch zurueck aus der Bestaetigung.
    private(set) var gewaehlt: TauschKandidat?
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

    func dauerhaftSetzen(_ an: Bool) {
        // Waehrend "Übernehmen" schreibt, gilt, was bestaetigt wurde: sonst
        // schloesse das Sheet nach Erfolg mit einem Tausch, den der Schalter
        // scheinbar abgesagt hat, und ein Fehler landete in der Liste, die
        // keinen zeigt. Das Sheet sperrt den Schalter dann auch.
        guard !schreibtGerade else { return }
        if an && !istOnline() { return }
        dauerhaft = an
        fehler = nil
        // Ausschalten in der Bestaetigung fuehrt zurueck zur Liste: ohne
        // Schalter gibt es nichts zu bestaetigen.
        if !an, case .bestaetigen = schritt { schritt = .kandidaten }
    }

    /// "Wählen". `true` = nur heute getauscht, das Sheet darf zu.
    func waehlen(_ kandidat: TauschKandidat) -> Bool {
        guard auftrag.tauschbar, auftrag.kandidaten.contains(kandidat) else { return false }
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
        schritt = .kandidaten
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
                positionKey: auftrag.position.key, exerciseId: kandidat.exerciseId, modelId: kandidat.modelId)
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
