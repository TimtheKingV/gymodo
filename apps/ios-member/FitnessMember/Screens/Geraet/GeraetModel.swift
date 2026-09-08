import Foundation
import Observation

/// Eine Uebung, egal ob aus dem Prefetch oder aus tagContext.
///
/// Vereinheitlicht die beiden DTO-Formen, damit der Screen nicht zwei
/// Quellen kennen muss. Das Video kommt nur online (signierte URL).
struct GeraetUebung: Identifiable, Equatable {
    let id: String
    let name: String
    let targetRepsMin: Int
    let targetRepsMax: Int
    let videoURL: URL?
}

/// Ein eigener Einstellwert, fertig zum Anzeigen.
struct Einstellwert: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let anzeige: String
}

/// Der Zustand eines geoeffneten Geraete-Screens.
///
/// Kein weiterer globaler Store: Der Screen wird gepusht, lebt so lange wie
/// der Push und verschwindet mit ihm.
///
/// Erzeugt wird das Modell mit dem PREFETCH-Geraet -- es rendert sofort.
/// tagContext kommt spaeter und ergaenzt nur, was der Server allein hat:
/// signiertes Foto, signierte Videos, Vorschlag (M1-Spec SS8.1 Schritt 3).
@MainActor
@Observable
final class GeraetModel {
    let maschine: BootstrapResponse.Machine
    private(set) var uebungId: String
    private(set) var kontext: TagContextResponse?
    private(set) var pause: Resttimer?

    var gewicht: Double
    var wiederholungen: Int
    var reserve: Double?
    var radOffen = false
    /// Die Kalibrierung ist auch ausserhalb des Dreischritts erreichbar
    /// ("aendern" auf Main) -- genau der Fall, der den eigenen Endpoint
    /// noetig macht.
    var kalibrierungOffen = false
    /// Entwurf der Kalibrierung-Steppers, bevor gespeichert wird.
    /// `kalibrierungVorbereiten()` befuellt ihn.
    var entwurfEinstellung: [String: Double] = [:]
    var trainerDabei = false
    /// Kommt woertlich vom Server -- er kennt die Grenzen des Geraetemodells
    /// und formuliert, was gilt (designsystem.md SS5).
    private(set) var kalibrierungFehler: String?

    private let token: String?
    private let bootstrap: BootstrapResponse
    private let loader: any GeraetLoading
    private let sessions: WorkoutSessionStore
    private let enqueue: (PendingSetWrite) -> Void

    init(
        maschine: BootstrapResponse.Machine,
        uebungId: String,
        token: String?,
        bootstrap: BootstrapResponse,
        loader: any GeraetLoading,
        sessions: WorkoutSessionStore,
        enqueue: @escaping (PendingSetWrite) -> Void
    ) {
        self.maschine = maschine
        self.uebungId = uebungId
        self.token = token
        self.bootstrap = bootstrap
        self.loader = loader
        self.sessions = sessions
        self.enqueue = enqueue

        let letzter = bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }
        // Ohne Historie startet das Rad am Geraetminimum -- ein Vorschlag
        // ohne Daten waere eine Trainingsempfehlung (designsystem.md SS8).
        gewicht = letzter?.weightKg ?? maschine.equipmentModel.minWeightKg
        wiederholungen = letzter?.reps ?? maschine.exercises.first { $0.id == uebungId }?.targetRepsMin ?? 10
        reserve = letzter?.rir

        // Snap erst, nachdem alle gespeicherten Eigenschaften stehen --
        // gewichtsWerte und Rastwerte.wiederholungen sind berechnete
        // Zugriffe, die vorher nicht aufgerufen werden duerfen. Ein
        // gespeichertes Gewicht kann abseits des Rasters liegen, wenn das
        // Studio die Schrittweite seither geaendert hat, und eine
        // gespeicherte Wiederholungszahl kann ausserhalb 1...40 liegen --
        // RastRad verlangt, dass die Auswahl ein Element der Werteliste ist.
        gewicht = Rastwerte.naechster(zu: gewicht, in: gewichtsWerte)
        wiederholungen = GeraetModel.geklemmt(wiederholungen)
    }

    /// Klemmt auf Rastwerte.wiederholungen (1...40) -- RastRad verlangt, dass
    /// die Auswahl ein Element der Werteliste ist. Braucht init (gespeicherte
    /// Werte koennen ausserhalb liegen) und uebungWechseln (dieselbe Regel
    /// beim Wechsel der Uebung).
    private static func geklemmt(_ wiederholungen: Int) -> Int {
        min(max(wiederholungen, Rastwerte.wiederholungen.first ?? 1),
            Rastwerte.wiederholungen.last ?? 40)
    }

    // MARK: - Abgeleitetes

    var uebungen: [GeraetUebung] {
        if let kontext {
            return kontext.exercises.map {
                GeraetUebung(id: $0.id, name: $0.name,
                             targetRepsMin: $0.targetRepsMin, targetRepsMax: $0.targetRepsMax,
                             videoURL: $0.instructionVideoUrl.flatMap(URL.init(string:)))
            }
        }
        return maschine.exercises.map {
            GeraetUebung(id: $0.id, name: $0.name,
                         targetRepsMin: $0.targetRepsMin, targetRepsMax: $0.targetRepsMax,
                         videoURL: nil)
        }
    }

    var aktiveUebung: GeraetUebung? { uebungen.first { $0.id == uebungId } }

    private var modell: (schritt: Double, min: Double, max: Double?) {
        if let kontext {
            return (kontext.equipmentModel.weightStepKg,
                    kontext.equipmentModel.minWeightKg,
                    kontext.equipmentModel.maxWeightKg)
        }
        return (maschine.equipmentModel.weightStepKg,
                maschine.equipmentModel.minWeightKg,
                maschine.equipmentModel.maxWeightKg)
    }

    var gewichtsWerte: [Double] {
        Rastwerte.gewichte(min: modell.min, max: modell.max, schritt: modell.schritt)
    }

    /// Nur wo es einen dokumentierten Anschlag gibt.
    var anschlagText: String? {
        modell.max == nil ? nil : "Maximum des Geräts erreicht"
    }

    var kontextzeileGewicht: String {
        let bereich = modell.max.map {
            "\(Zahlformat.gewicht(modell.min)) – \(Zahlformat.gewicht($0))"
        } ?? "ab \(Zahlformat.gewicht(modell.min))"
        return "Schritt \(Zahlformat.gewicht(modell.schritt)) kg · \(bereich)"
    }

    var kontextzeileWiederholungen: String {
        guard let uebung = aktiveUebung else { return "" }
        return "Ziel \(uebung.targetRepsMin) – \(uebung.targetRepsMax)"
    }

    private var definitionen: [TagContextResponse.SettingDefinition] {
        kontext?.settingDefinitions ?? maschine.equipmentModel.settingDefinitions
    }

    /// Fuer KalibrierungSchritt -- dieselben Definitionen, oeffentlich.
    var einstellDefinitionen: [TagContextResponse.SettingDefinition] { definitionen }

    /// tag-context.ts berechnet calibration und suggestion serverseitig fuer
    /// genau eine Uebung (selectedExerciseId). Nach einem Uebungswechsel
    /// gehoert der geladene Kontext noch zur vorherigen Uebung -- ohne diese
    /// Klammer zeigte der Screen A's Sitzposition unter B's Namen, und das
    /// Mitglied stellte das Geraet danach physisch falsch ein.
    private var kontextPasstZurUebung: Bool {
        kontext?.selectedExerciseId == uebungId
    }

    private var kalibrierungswerte: JSONValue? {
        if kontextPasstZurUebung, let kalibrierung = kontext?.calibration {
            return kalibrierung.settingValues
        }
        return bootstrap.calibrations.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }?.settingValues
    }

    /// Beschriftete Einstellwerte -- auch offline, weil bootstrap die
    /// Definitionen mitliefert.
    var einstellwerte: [Einstellwert] {
        guard case .object(let werte)? = kalibrierungswerte else { return [] }
        return definitionen.compactMap { definition in
            guard let wert = werte[definition.key] else { return nil }
            return Einstellwert(key: definition.key, label: definition.label,
                                anzeige: anzeige(fuer: wert, einheit: definition.unit))
        }
    }

    private func anzeige(fuer wert: JSONValue, einheit: String?) -> String {
        let roh: String = switch wert {
        case .number(let zahl): zahl == zahl.rounded() ? String(Int(zahl)) : Zahlformat.gewicht(zahl)
        case .string(let text): text
        default: "–"
        }
        return einheit.map { "\(roh)\($0)" } ?? roh
    }

    var satzNummer: Int {
        sessions.naechsterSetIndex(machineId: maschine.id, exerciseId: uebungId)
    }

    /// "Vorschlag · +2,5" -- eine Rechnung, keine Empfehlung
    /// (designsystem.md SS10). Fehlt offline und beim Erstkontakt.
    var vorschlagText: String? {
        // Derselbe Uebungs-Vorbehalt wie kalibrierungswerte: der Vorschlag
        // gilt fuer selectedExerciseId, nicht fuer die aktuell gewaehlte.
        guard kontextPasstZurUebung,
              let vorschlag = kontext?.suggestion.resultWeightKg,
              let vorher = kontext?.suggestion.inputs.currentWeightKg
        else { return nil }
        let delta = vorschlag - vorher
        guard delta != 0 else { return "Vorschlag · halten" }
        let vorzeichen = delta > 0 ? "+" : "−"
        return "Vorschlag · \(vorzeichen)\(Zahlformat.gewicht(abs(delta)))"
    }

    var zuletztText: String? {
        guard let letzter = bootstrap.lastSets.first(where: {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }) else { return nil }
        return "Zuletzt \(Zahlformat.gewichtMitEinheit(letzter.weightKg)) × \(letzter.reps)"
    }

    func letztesGewicht(fuer uebungId: String) -> Double? {
        bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }?.weightKg
    }

    /// Ganze Tage seit dem letzten Satz -- "vor 8 Tagen" in der
    /// Uebungsliste sagt dem Mitglied, wie alt die Zahl ist, bevor es die
    /// Scheiben auflegt. nil ohne Historie oder wenn performedAt sich nicht
    /// parsen laesst; die Zeile zeigt dann nur das Gewicht.
    func letzteNutzungInTagen(fuer uebungId: String) -> Int? {
        guard let letzter = bootstrap.lastSets.first(where: {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }), let datum = ISO8601DateFormatter().date(from: letzter.performedAt) else { return nil }
        return Calendar.current.dateComponents([.day], from: datum, to: Date()).day
    }

    /// Der Dreischritt laeuft genau einmal je Geraet und Uebung -- nach
    /// seinem Abschluss darf er in dieser Sitzung nicht erneut aufgehen.
    private var erstkontaktErledigt = false

    func erstkontaktAbschliessen() { erstkontaktErledigt = true }

    var istErstkontakt: Bool {
        !erstkontaktErledigt && GeraetEinstiegRechner.istErstkontakt(
            hatKalibrierung: GeraetEinstiegRechner.hatKalibrierung(
                machineId: maschine.id, exerciseId: uebungId, in: bootstrap),
            hatLetztenSatz: GeraetEinstiegRechner.hatLetztenSatz(
                machineId: maschine.id, exerciseId: uebungId, in: bootstrap)
        )
    }

    /// Pflichtort laut designsystem.md SS10.
    let produktgrenze = """
        gymodo misst nichts. Angezeigt wird ausschließlich, was du selbst \
        bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte \
        deines Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo.
        """

    // MARK: - Aktionen

    func kontextLaden() async {
        guard let token else { return }
        // Ein Fehlschlag ist kein Fehlerzustand: der Screen steht bereits
        // aus dem Prefetch. Es fehlen nur Video, Foto und Vorschlag.
        guard let geladen = try? await loader.tagContext(token: token) else { return }
        kontextUebernehmen(geladen)
    }

    func kontextUebernehmen(_ geladen: TagContextResponse) {
        kontext = geladen
        if let vorschlag = geladen.suggestion.resultWeightKg {
            gewicht = Rastwerte.naechster(zu: vorschlag, in: gewichtsWerte)
        }
    }

    func uebungWechseln(zu neue: String) {
        uebungId = neue
        let letzter = bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == neue
        }
        gewicht = Rastwerte.naechster(
            zu: letzter?.weightKg ?? modell.min, in: gewichtsWerte)
        wiederholungen = GeraetModel.geklemmt(letzter?.reps ?? aktiveUebung?.targetRepsMin ?? 10)
        reserve = letzter?.rir
        radOffen = false
    }

    func satzSichern(problemFlag: Bool, problemReason: ProblemReason?) async {
        let geschrieben = sessions.satzSichern(
            machineId: maschine.id, exerciseId: uebungId,
            weightKg: gewicht, reps: wiederholungen, rir: reserve,
            problemFlag: problemFlag, problemReason: problemReason
        )
        // Immer ueber die Warteschlange, nie direkt: so ist "gespeichert,
        // wird gesendet" nie gelogen, und der Offline-Pfad ist derselbe, der
        // jeden Tag laeuft (Spec Abschnitt 8.2).
        enqueue(PendingSetWrite(sessionId: geschrieben.sessionId,
                                setId: geschrieben.setId,
                                body: geschrieben.body))
        radOffen = false
        pause = Resttimer()
    }

    func pauseVerlaengern() { pause = pause?.verlaengert() }
    func pauseBeenden() { pause = nil }

    func kalibrierungOeffnen() { kalibrierungOffen = true }

    /// Fuellt den Entwurf mit den bisherigen Werten, sonst mit dem Minimum.
    func kalibrierungVorbereiten() {
        var entwurf: [String: Double] = [:]
        let bisherige: [String: JSONValue]
        if case .object(let werte)? = kalibrierungswerte { bisherige = werte } else { bisherige = [:] }
        for definition in definitionen {
            if case .number(let zahl)? = bisherige[definition.key] {
                entwurf[definition.key] = zahl
            } else {
                entwurf[definition.key] = definition.minValue ?? 0
            }
        }
        entwurfEinstellung = entwurf
        kalibrierungFehler = nil
    }

    /// Gibt zurueck, ob gespeichert wurde. Die Fehlermeldung kommt vom
    /// Server -- er kennt die Grenzen und formuliert, was gilt
    /// (designsystem.md SS5).
    func kalibrierungSichern() async -> Bool {
        kalibrierungFehler = nil
        let werte = entwurfEinstellung.mapValues { JSONValue.number($0) }
        do {
            _ = try await loader.recordCalibration(
                CalibrationWrite(
                    machineId: maschine.id, exerciseId: uebungId,
                    settingValues: werte, schemaVersion: 1,
                    source: trainerDabei ? "trainer_assisted" : "self"
                )
            )
            kalibrierungOffen = false
            return true
        } catch {
            kalibrierungFehler = switch error {
            case .offline: "Ohne Empfang lässt sich die Einstellung nicht speichern. Deine Sätze gehen trotzdem raus."
            case .validation(let text), .server(let text), .notFound(let text),
                 .conflict(let text), .unauthorized(let text): text
            case .encodingFailed: "Die Einstellung ließ sich nicht senden. Deine Sätze gehen trotzdem raus."
            case .decodingFailed: "Unerwartete Antwort vom Server."
            }
            return false
        }
    }
}
