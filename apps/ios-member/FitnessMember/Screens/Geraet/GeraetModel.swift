import Foundation
import Observation

/// Eine Uebung, egal ob aus dem Prefetch oder aus tagContext.
///
/// Vereinheitlicht die beiden DTO-Formen, damit der Screen nicht zwei
/// Quellen kennen muss. Das Video kommt nur online (signierte URL).
struct GeraetUebung: Identifiable, Equatable {
    let id: String
    let name: String
    /// Was der Korridor zaehlt -- targetMin/targetMax stehen in dieser
    /// Einheit, und das Umfangsrad nimmt seine Werteliste von hier.
    let volumeKind: VolumeKind
    let targetMin: Int
    let targetMax: Int
    let videoURL: URL?
}

/// Ein eigener Einstellwert, fertig zum Anzeigen.
struct Einstellwert: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let anzeige: String
}

/// Was der Drawer beim Oeffnen des Geraets sagt. nil, wenn er nichts zu
/// sagen haette: beim ersten Mal an diesem Geraet gibt es weder einen
/// letzten Satz noch einen Vorschlag (Sammelstelle Punkt 11).
struct Rueckblick: Equatable {
    /// "77,5 kg x 11" oder "8,5 km/h - 6,0 % x 20:00 min" (im UI mit
    /// Malzeichen und Mittelpunkt) -- der letzte eigene Satz dieser Uebung
    /// an diesem Geraet, aus dem Prefetch, also auch offline.
    let zuletzt: String
    /// "Vorschlag - +2,5 kg" (im UI mit Mittelpunkt), sobald der Kontext
    /// da ist. Offline nil.
    let vorschlag: String?
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
    /// Was der Screen gerade IST -- nicht, was er zusaetzlich einblendet.
    ///
    /// Vorher trug ein `pause: Resttimer?` diese Unterscheidung. Das
    /// reichte, solange die Pause nur ein Band ueber dem Screen war; sobald
    /// sie ihn ganz uebernimmt und es einen dritten Zustand gibt ("an
    /// diesem Geraet ist das Satzziel erreicht"), ist ein Optional die
    /// falsche Form: es kann nicht sagen, dass gerade KEINE Pause laeuft,
    /// WEIL nichts mehr geplant ist.
    enum Phase: Equatable {
        /// Raeder und "Satz N sichern".
        case eingabe
        /// Nur Kopf und Pausenrad. Der Timer traegt seinen Endzeitpunkt
        /// selbst, die Phase muss nichts mitzaehlen.
        case pause(Resttimer)
        /// Das Satzziel ist erreicht: "Geraet abschliessen" oder
        /// "Weiterer Satz".
        case abschluss

        /// Eine Pause in der eingestellten Laenge. Drei Aufrufer, eine
        /// Stelle -- die Dauer aus dem Profil zu lesen ist sonst genau die
        /// Zeile, die beim vierten Aufrufer vergessen wird.
        static func neuePause() -> Phase {
            .pause(Resttimer(dauer: TimeInterval(Einstellungen.resttimerSekunden())))
        }
    }

    let maschine: BootstrapResponse.Machine
    private(set) var uebungId: String
    private(set) var kontext: TagContextResponse?
    private(set) var phase: Phase = .eingabe
    /// Steigt genau einmal je erfolgreich gesichertem Satz -- unabhaengig
    /// von uebungId und Block. satzNummer ist dafuer ungeeignet: es ist
    /// die naechste Satznummer DER GERADE ANGEZEIGTEN Uebung und springt
    /// deshalb auch bei uebungWechseln(zu:) allein, ohne dass ein Satz
    /// gesichert wurde (Review-Fund Task 9: Haptik feuerte beim Wechsel
    /// auf eine Uebung mit mehr bereits gesicherten Saetzen).
    private(set) var gesicherteSaetze = 0

    /// Was am Geraet gedreht wird, in der Einheit des Modells (loadUnit):
    /// Kilogramm an der Beinpresse, km/h am Laufband.
    var belastung: Double
    /// Was das Mitglied geschafft hat, in der Umfangsart der Uebung
    /// (volumeKind): Wiederholungen, Sekunden oder Meter.
    var umfang: Int
    /// Der zweite Intensitaetsregler (Neigung am Laufband). Genau dann
    /// gesetzt, wenn das Modell eine Nebenbelastung hat -- der Server
    /// verlangt sie dann im Satz und weist sie sonst ab (Cardio-Spec 5.1).
    private(set) var nebenbelastung: Double?
    /// Sobald das Mitglied am Rad gedreht hat, gehoert `belastung` ihm --
    /// ein spaeter eintreffender tagContext (die Anfrage lief seit .task
    /// auf GeraetView, kann in einem Keller zehn Sekunden brauchen) darf
    /// den Wert dann nicht mehr unter dem Daumen ersetzen. Zusammen mit
    /// `nebenbelastungVomNutzer` der einzige Ort mit zwei Schreibern auf
    /// denselben Zustand.
    private var belastungVomNutzer = false
    /// Dieselbe Regel fuer die Nebenbelastung, getrennt gefuehrt: wer nur
    /// die Neigung anfasst, soll den Tempo-Vorschlag trotzdem bekommen.
    private var nebenbelastungVomNutzer = false
    /// Die Kalibrierung ist auch ausserhalb des Dreischritts erreichbar
    /// ("aendern" auf Main) -- genau der Fall, der den eigenen Endpoint
    /// noetig macht.
    var kalibrierungOffen = false
    /// Entwurf der Kalibrierung-Steppers, bevor gespeichert wird.
    /// `kalibrierungVorbereiten()` befuellt ihn. Nur Zahlen-Parameter.
    var entwurfEinstellung: [String: Double] = [:]
    /// Entwurf der Auswahl-Parameter (`kind == "enum"`, etwa die
    /// Griffposition). Getrennt vom Zahlenentwurf: bis zur Testnotiz 06.10.
    /// (#17) gab es nur den, jede Auswahl bekam ein Zahlenrad und ging als
    /// Zahl an den Server -- der wies sie ab, egal was gewaehlt war.
    var entwurfAuswahl: [String: String] = [:]
    var trainerDabei = false
    /// Kommt woertlich vom Server -- er kennt die Grenzen des Geraetemodells
    /// und formuliert, was gilt (designsystem.md SS5).
    private(set) var kalibrierungFehler: String?

    private let token: String?
    private let bootstrap: BootstrapResponse
    private let loader: any GeraetLoading
    private let sessions: WorkoutSessionStore
    private let enqueue: (PendingSetWrite) -> Void
    /// Als Closure statt als Zahl: die Einstellung darf sich waehrend des
    /// Trainings aendern (Profil ist ein Tab weiter), und ein beim Push
    /// eingefrorener Wert waere dann still falsch. Injizierbar, weil
    /// `Einstellungen.satzZiel()` sonst auf `UserDefaults.standard` laege
    /// und Tests sich gegenseitig die Vorgabe verstellten.
    private let satzZielLesen: () -> Int
    /// Im Release immer nil. Im Debug-Build der Sensor-Koordinator; das
    /// Modell weiss davon nichts ausser diesen drei Aufrufen (Spec
    /// Sensor-Anbindung 7.3).
    private let mitschnitt: (any SatzMitschnitt)?

    /// Wie das Mitglied an diesem Geraet gelandet ist.
    ///
    /// Nach einem Scan war das Telefon am Geraet. Nach einer Auswahl aus
    /// der Liste hat jemand etwas angetippt -- die App weiss nicht, wo er
    /// steht. Das Wort auf dem Screen darf den Unterschied nicht
    /// verwischen (designsystem.md SS10).
    enum Einstiegsart: Equatable {
        case erkannt
        case ausgewaehlt

        init(token: String?) {
            self = token == nil ? .ausgewaehlt : .erkannt
        }

        var beschriftung: String {
            switch self {
            case .erkannt: "ERKANNT"
            case .ausgewaehlt: "AUSGEWÄHLT"
            }
        }

        var symbol: String {
            switch self {
            case .erkannt: "wave.3.right"
            case .ausgewaehlt: "list.bullet"
            }
        }
    }

    var einstiegsart: Einstiegsart { Einstiegsart(token: token) }

    init(
        maschine: BootstrapResponse.Machine,
        uebungId: String,
        token: String?,
        bootstrap: BootstrapResponse,
        loader: any GeraetLoading,
        sessions: WorkoutSessionStore,
        enqueue: @escaping (PendingSetWrite) -> Void,
        satzZiel: @escaping () -> Int = { Einstellungen.satzZiel() },
        mitschnitt: (any SatzMitschnitt)? = nil
    ) {
        self.maschine = maschine
        self.uebungId = uebungId
        self.token = token
        self.bootstrap = bootstrap
        self.loader = loader
        self.sessions = sessions
        self.enqueue = enqueue
        satzZielLesen = satzZiel
        self.mitschnitt = mitschnitt

        let letzter = bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }
        // Ohne Historie startet das Rad am Geraetminimum -- ein Vorschlag
        // ohne Daten waere eine Trainingsempfehlung (designsystem.md SS8).
        belastung = letzter?.load ?? maschine.equipmentModel.loadMin
        umfang = letzter?.volume ?? maschine.exercises.first { $0.id == uebungId }?.targetMin ?? 10

        // Snap erst, nachdem alle gespeicherten Eigenschaften stehen --
        // belastungsWerte und umfangsWerte sind berechnete Zugriffe, die
        // vorher nicht aufgerufen werden duerfen. Eine gespeicherte
        // Belastung kann abseits des Rasters liegen, wenn das Studio die
        // Schrittweite seither geaendert hat, und ein gespeicherter Umfang
        // ausserhalb der Liste seiner Umfangsart -- RastRad verlangt, dass
        // die Auswahl ein Element der Werteliste ist.
        belastung = Rastwerte.naechster(zu: belastung, in: belastungsWerte)
        umfang = Rastwerte.naechster(zu: umfang, in: umfangsWerte)
        nebenbelastung = nebenbelastungVorbelegt(aus: letzter?.secondaryLoad)
    }

    /// Letzter Satz an diesem Geraet und dieser Uebung, sonst das Minimum
    /// -- dieselbe Regel wie bei der Belastung. Im Normalfall bleibt die
    /// Neigung gleich, und das Mitglied fasst den Regler gar nicht an
    /// (Cardio-Spec 3.1b). nil, wenn das Modell keine Nebenbelastung hat.
    private func nebenbelastungVorbelegt(aus letzte: Double?) -> Double? {
        guard let neben = nebenmodell else { return nil }
        return Rastwerte.naechster(zu: letzte ?? neben.min, in: nebenbelastungsWerte)
    }

    // MARK: - Abgeleitetes

    var uebungen: [GeraetUebung] {
        if let kontext {
            return kontext.exercises.map {
                GeraetUebung(id: $0.id, name: $0.name, volumeKind: $0.volumeKind,
                             targetMin: $0.targetMin, targetMax: $0.targetMax,
                             videoURL: $0.instructionVideoUrl.flatMap(URL.init(string:)))
            }
        }
        return maschine.exercises.map {
            GeraetUebung(id: $0.id, name: $0.name, volumeKind: $0.volumeKind,
                         targetMin: $0.targetMin, targetMax: $0.targetMax,
                         videoURL: nil)
        }
    }

    var aktiveUebung: GeraetUebung? { uebungen.first { $0.id == uebungId } }

    /// Ob es an diesem Geraet ueberhaupt etwas zu wechseln gibt. Ein
    /// Geraet mit genau einer Uebung bekommt kein "andere Übung" -- ein
    /// Knopf, der eine Liste mit einem Eintrag oeffnet, verspricht eine
    /// Wahl, die es nicht gibt.
    var hatWeitereUebungen: Bool { uebungen.count > 1 }

    /// Ob "Uebung abschliessen" erst fragt: "Weitere Uebung an dem Geraet"
    /// oder "Geraet abschliessen" (Testnotiz 06.10., #12). Entschieden:
    /// immer, sobald das Geraet mehr als eine Uebung kennt -- auch wenn
    /// alle schon dran waren; die Liste zeigt dann, wie viele Saetze.
    var abschlussFragtNach: Bool { hatWeitereUebungen }

    /// Der Block dieser Uebung an DIESEM Geraet in der laufenden Einheit,
    /// sonst nil. Fuer die Uebungsliste: "2 Sätze · 7,5 kg" wie in der
    /// Blockliste des Trainings (Testnotiz 06.10., #12).
    func blockInEinheit(fuer uebungId: String) -> LokalerBlock? {
        sessions.aktiveSession()?.bloecke.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId && !$0.saetze.isEmpty
        }
    }

    /// Seit wann die Trainingsuhr laeuft: seit dem Tap auf "Training
    /// starten" -- die Einheit traegt ihren Beginn selbst, ein gemerkter
    /// Geraetekontakt daneben gibt es seit Schnitt 4 nicht mehr.
    var trainingsbeginn: Date? { sessions.trainingsbeginn() }

    private var modell: (schritt: Double, min: Double, max: Double?) {
        if let kontext {
            return (kontext.equipmentModel.loadStep,
                    kontext.equipmentModel.loadMin,
                    kontext.equipmentModel.loadMax)
        }
        return (maschine.equipmentModel.loadStep,
                maschine.equipmentModel.loadMin,
                maschine.equipmentModel.loadMax)
    }

    /// Die Einheit der Belastung. Ein Wert, den Rad und Formatierer lesen
    /// -- keine Stelle im Modell verzweigt danach.
    var loadUnit: LoadUnit {
        kontext?.equipmentModel.loadUnit ?? maschine.equipmentModel.loadUnit
    }

    /// Die Umfangsart der aktiven Uebung. `.reps` nur, wenn es die Uebung
    /// nicht gibt -- derselbe Notfall, fuer den init die 10 bereithaelt.
    var volumeKind: VolumeKind { aktiveUebung?.volumeKind ?? .reps }

    /// Einheit und Rastung der Nebenbelastung, oder nil, wenn das Modell
    /// keine hat. Alle vier Felder zusammen: so erzwingt es der Constraint
    /// aus Migration 0046, und ein halber Satz waere kein Regler.
    private var nebenmodell: (einheit: LoadUnit, schritt: Double, min: Double, max: Double)? {
        let quelle: (LoadUnit?, Double?, Double?, Double?) =
            if let modell = kontext?.equipmentModel {
                (modell.secondaryUnit, modell.secondaryStep, modell.secondaryMin, modell.secondaryMax)
            } else {
                (maschine.equipmentModel.secondaryUnit, maschine.equipmentModel.secondaryStep,
                 maschine.equipmentModel.secondaryMin, maschine.equipmentModel.secondaryMax)
            }
        guard let einheit = quelle.0, let schritt = quelle.1,
              let min = quelle.2, let max = quelle.3 else { return nil }
        return (einheit, schritt, min, max)
    }

    /// nil an jedem Geraet ohne Nebenbelastung -- der Screen zeigt dann
    /// keine Zeile dafuer und ist der eines Kraftgeraets.
    var secondaryUnit: LoadUnit? { nebenmodell?.einheit }

    /// Schritt und Grenzen fuer den Regler der Nebenbelastung.
    var nebenbelastungSchritt: Double { nebenmodell?.schritt ?? 1 }
    var nebenbelastungBereich: ClosedRange<Double>? {
        nebenmodell.map { $0.min...Swift.max($0.min, $0.max) }
    }

    var belastungsWerte: [Double] {
        Rastwerte.belastung(min: modell.min, max: modell.max, schritt: modell.schritt)
    }

    var nebenbelastungsWerte: [Double] {
        guard let neben = nebenmodell else { return [] }
        return Rastwerte.belastung(min: neben.min, max: neben.max, schritt: neben.schritt)
    }

    var umfangsWerte: [Int] { Rastwerte.umfang(volumeKind) }

    /// Was der Block ueber seine Zahlen wissen muss -- geht mit dem Satz
    /// in die lokale Einheit, damit TrainingLaeuft und Abschluss ohne
    /// Prefetch formatieren koennen.
    var einheiten: Blockeinheiten {
        Blockeinheiten(loadUnit: loadUnit, secondaryUnit: secondaryUnit, volumeKind: volumeKind)
    }

    /// Nur wo es einen dokumentierten Anschlag gibt.
    var anschlagText: String? {
        modell.max == nil ? nil : Rastwerte.maximumErreicht
    }

    /// "Schritt 2,5 kg · 5,0 – 150,0", "Schritt 0,5 km/h · 0,0 – 20,0".
    /// Die Einheit steht hinter der Schrittweite, auch bei Level: "Schritt
    /// 1 Level" ist eine Aenderung um eine Stufe, nicht die Stufe 1.
    var kontextzeileBelastung: String {
        let bereich = modell.max.map {
            "\(Zahlformat.belastung(modell.min, loadUnit)) – \(Zahlformat.belastung($0, loadUnit))"
        } ?? "ab \(Zahlformat.belastung(modell.min, loadUnit))"
        return "Schritt \(Zahlformat.belastung(modell.schritt, loadUnit)) \(loadUnit.kurz) · \(bereich)"
    }

    /// "Ziel 8 – 12", "Ziel 15 – 20 min".
    var kontextzeileUmfang: String {
        guard let uebung = aktiveUebung else { return "" }
        return "Ziel \(Zahlformat.korridor(uebung.targetMin, uebung.targetMax, uebung.volumeKind))"
    }

    private var definitionen: [TagContextResponse.SettingDefinition] {
        kontext?.settingDefinitions ?? maschine.equipmentModel.settingDefinitions
    }

    /// Fuer KalibrierungSchritt -- dieselben Definitionen, oeffentlich.
    var einstellDefinitionen: [TagContextResponse.SettingDefinition] { definitionen }

    /// Ob es an diesem Modell ueberhaupt etwas einzustellen gibt. Liest
    /// dieselbe Quelle wie `einstellDefinitionen`, damit Dreischritt und
    /// Kalibrierungsschritt nie verschiedener Meinung sind.
    var hatEinstellparameter: Bool { !definitionen.isEmpty }

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
        sessions.naechsterSetIndex(station: Station(maschine: maschine), exerciseId: uebungId)
    }

    /// Wie viele Saetze an diesem Geraet geplant sind (Profil, Vorgabe 3).
    ///
    /// Die eine Stelle, an der die Umfangsart eine Regel traegt: bei Zeit
    /// und Strecke ist ein Satz die ganze Einheit am Geraet ("20 Minuten
    /// Dauerlauf", Cardio-Spec 3.4). Nach 20 Minuten Laufband eine
    /// 90-Sekunden-Pause vor einem zweiten Satz zu starten, waere falsch --
    /// stattdessen kommt nach dem ersten Satz gleich die Frage "Geraet
    /// abschliessen / Weiterer Satz". Das Profil-Satzziel ist ein Ziel
    /// fuer Wiederholungsuebungen und gilt nur dort.
    var satzZiel: Int { volumeKind == .reps ? satzZielLesen() : 1 }

    /// Die Pause, solange sie WIRKLICH laeuft.
    ///
    /// `.pause` mit abgelaufenem Timer kann einen Wimpernschlag lang
    /// existieren, bevor der Ablauf-Task in GeraetView greift. In dieser
    /// Spanne darf der Screen kein Rad auf 00:00 zeigen -- er faellt
    /// stattdessen auf die Raeder zurueck.
    var laufendePause: Resttimer? {
        guard case .pause(let timer) = phase, timer.laeuft() else { return nil }
        return timer
    }

    /// "Vorschlag · +2,5 kg", "Vorschlag · +0,5 km/h" -- eine Rechnung,
    /// keine Empfehlung (designsystem.md SS10). Fehlt offline und beim
    /// Erstkontakt. Mit Einheit: an einem Geraet mit zwei Reglern sagte
    /// eine nackte Zahl nicht, welcher gemeint ist.
    var vorschlagText: String? {
        // Derselbe Uebungs-Vorbehalt wie kalibrierungswerte: der Vorschlag
        // gilt fuer selectedExerciseId, nicht fuer die aktuell gewaehlte.
        guard kontextPasstZurUebung,
              let vorschlag = kontext?.suggestion.resultLoad,
              let vorher = kontext?.suggestion.inputs.currentLoad
        else { return nil }
        let delta = vorschlag - vorher
        guard delta != 0 else { return "Vorschlag · halten" }
        return "Vorschlag · \(Zahlformat.belastungDelta(delta, loadUnit))"
    }

    var rueckblick: Rueckblick? {
        guard let letzter = bootstrap.lastSets.first(where: {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }) else { return nil }
        return Rueckblick(
            zuletzt: Zahlformat.satz(letzter.load, loadUnit,
                                     neben: letzter.secondaryLoad, secondaryUnit,
                                     umfang: letzter.volume, volumeKind),
            vorschlag: vorschlagText
        )
    }

    /// Die Regel "wann kommt der Drawer": nur vor dem ersten Satz DIESES
    /// Geraeteblocks, und nur, wenn es einen Rueckblick gibt. satzNummer liest
    /// live aus der lokalen Session -- im Zirkel zurueck am selben Geraet ist
    /// der erste Satz laengst gesichert, auch wenn bootstrap ihn nicht kennt.
    var rueckblickFaellig: Bool { satzNummer == 1 && rueckblick != nil }

    /// Ob der Drawer gerade steht. GeraetScreen bindet sein Sheet daran.
    var rueckblickOffen = false

    /// Einmal beim Oeffnen des Screens -- nicht nach jedem Satz und nicht beim
    /// Uebungswechsel. Der Drawer ist der Blick zurueck VOR dem ersten Satz;
    /// danach waere er eine Karte, die den Satzpfad wieder hoeher macht
    /// (Punkt 12).
    func geraetGeoeffnet() {
        rueckblickOffen = rueckblickFaellig
        // Kommt das Mitglied per Zurueck wieder auf den Screen, laeuft .task
        // erneut und der Mitschnitt beginnt neu. In Pause und Abschluss
        // stehen keine Raeder da -- dort laeuft nichts.
        if phase == .eingabe { mitschnittBeginnen() }
    }

    func letzteBelastung(fuer uebungId: String) -> Double? {
        bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }?.load
    }

    /// Ganze Tage seit dem letzten Satz -- "vor 8 Tagen" in der
    /// Uebungsliste sagt dem Mitglied, wie alt die Zahl ist, bevor es die
    /// Scheiben auflegt. nil ohne Historie oder wenn performedAt sich nicht
    /// parsen laesst; die Zeile zeigt dann nur die Belastung.
    func letzteNutzungInTagen(fuer uebungId: String) -> Int? {
        guard let letzter = bootstrap.lastSets.first(where: {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }), let datum = ISO8601DateFormatter().date(from: letzter.performedAt) else { return nil }
        return Calendar.current.dateComponents([.day], from: datum, to: Date()).day
    }

    /// Der Dreischritt laeuft genau einmal je Geraet UND Uebung -- deshalb
    /// je Uebungs-Id vermerkt, nicht als ein einzelnes Bool fuer die ganze
    /// Modellinstanz. Ein Bool wuerde nach dem Abschluss fuer Uebung A auch
    /// den Dreischritt fuer eine ganz andere, nie benutzte Uebung B
    /// unterdruecken -- uebungWechseln(zu:) muesste es sonst zuruecksetzen,
    /// haette dabei aber keine Ahnung, ob B ihn schon hinter sich hat.
    private var erledigt: Set<String> = []

    func erstkontaktAbschliessen() { erledigt.insert(uebungId) }

    /// `bootstrap` ist eine Momentaufnahme vom letzten Prefetch -- weder
    /// eine Kalibrierung noch ein frisch gesicherter Satz schreiben sie neu.
    /// `sessions.naechsterSetIndex(...) == 1` ist deshalb die tragende
    /// Bedingung: sie liest live aus der lokalen Session und weiss damit
    /// auch von einem Satz, den `bootstrap` noch nicht kennt -- etwa nach
    /// einem abgeschlossenen Dreischritt und drei Saetzen an diesem Geraet,
    /// wenn das Mitglied ueber die Blockliste zurueckkommt und ein neues
    /// GeraetModel entsteht.
    var istErstkontakt: Bool {
        !erledigt.contains(uebungId)
            && GeraetEinstiegRechner.brauchtErstkontakt(
                station: Station(maschine: maschine).schluessel, exerciseId: uebungId, in: bootstrap,
                naechsterSetIndex: sessions.naechsterSetIndex(station: Station(maschine: maschine), exerciseId: uebungId))
    }

    /// Ob gerade ein Training laeuft -- der Erstkontakt haengt
    /// "Training starten" nur ohne an (Testnotiz 06.10., #5).
    var trainingLaeuft: Bool { sessions.aktiveSession() != nil }

    /// Der letzte Schritt des Erstkontakts ohne laufendes Training. Derselbe
    /// Store-Aufruf wie hinter TrainingStartView.
    func trainingStarten() { sessions.trainingStarten() }

    /// Pflichtort laut designsystem.md SS10.
    let produktgrenze = """
        Gymtavo misst nichts. Angezeigt wird ausschließlich, was du selbst \
        bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte \
        deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.
        """

    // MARK: - Aktionen

    /// Laedt, was der Prefetch nicht hat: Foto, Einweisungsvideo und den
    /// Vorschlag fuer die Belastung.
    ///
    /// Hier stand bis zur Geraeteauswahl ohne Scan ein
    /// `guard let token else { return }`. Damit blieb ein aus der Liste
    /// gewaehltes Geraet dauerhaft ohne diese drei Dinge -- und ohne Foto
    /// fehlt genau das, was die Auswahl ohne ein Wort bestaetigt.
    ///
    /// Ein Fehlschlag ist weiterhin kein Fehlerzustand: der Screen steht
    /// bereits aus dem Prefetch.
    func kontextLaden() async {
        let geladen: TagContextResponse? =
            if let token {
                try? await loader.tagContext(token: token)
            } else {
                try? await loader.machineContext(machineId: maschine.id)
            }
        guard let geladen else { return }
        kontextUebernehmen(geladen)
    }

    func kontextUebernehmen(_ geladen: TagContextResponse) {
        kontext = geladen
        // Unangetastet uebernehmen; hat das Mitglied schon am Rad gedreht,
        // gehoert ihm der Wert -- ein spaeter Vorschlag darf ihn nicht mehr
        // unter dem Daumen ersetzen.
        if !belastungVomNutzer, let vorschlag = geladen.suggestion.resultLoad {
            belastung = Rastwerte.naechster(zu: vorschlag, in: belastungsWerte)
        }
        // Der Kontext kann ein anderes Modell zeigen als der Prefetch (das
        // Studio hat seither eine Nebenbelastung eingetragen oder
        // gestrichen). `nebenbelastung` muss genau dann gesetzt sein, wenn
        // das Modell eine hat -- sonst weist der Server den Satz ab.
        guard nebenmodell != nil else {
            nebenbelastung = nil
            return
        }
        // Die Regel steigert die Nebenbelastung nie, sie gibt nur mit, bei
        // welcher der Vorschlag gilt (Cardio-Spec 5.2). Uebernommen wird
        // sie wie die Belastung: nur, solange das Mitglied sie nicht
        // selbst angefasst hat.
        if !nebenbelastungVomNutzer, let vorschlag = geladen.suggestion.resultSecondaryLoad {
            nebenbelastung = Rastwerte.naechster(zu: vorschlag, in: nebenbelastungsWerte)
        } else if let bisher = nebenbelastung {
            nebenbelastung = Rastwerte.naechster(zu: bisher, in: nebenbelastungsWerte)
        } else {
            nebenbelastung = nebenbelastungVorbelegt(aus: letzterSatz(fuer: uebungId)?.secondaryLoad)
        }
    }

    /// Der einzige Weg, auf dem das Mitglied selbst die Belastung setzt:
    /// das Rad schreibt hierher, nicht direkt in `belastung`. init,
    /// uebungWechseln und kontextUebernehmen setzen `belastung`
    /// programmatisch und lassen die Markierung in Ruhe -- sonst schuetzte
    /// ein Vorschlag sich vor sich selbst.
    func belastungGewaehlt(_ neu: Double) {
        belastung = neu
        belastungVomNutzer = true
    }

    /// Dasselbe fuer die Nebenbelastung. An einem Geraet ohne sie gibt es
    /// keinen Regler, der hierher schreiben koennte; kaeme der Aufruf
    /// trotzdem, bliebe sie nil -- ein gesetzter Wert liesse den Server
    /// den Satz abweisen.
    func nebenbelastungGewaehlt(_ neu: Double) {
        guard nebenmodell != nil else { return }
        nebenbelastung = Rastwerte.naechster(zu: neu, in: nebenbelastungsWerte)
        nebenbelastungVomNutzer = true
    }

    private func letzterSatz(fuer uebungId: String) -> BootstrapResponse.LastSet? {
        bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }
    }

    func uebungWechseln(zu neue: String) {
        uebungId = neue
        let letzter = letzterSatz(fuer: neue)
        belastung = Rastwerte.naechster(
            zu: letzter?.load ?? modell.min, in: belastungsWerte)
        // umfangsWerte liest die Umfangsart der NEUEN Uebung: von
        // "Dauerlauf" (Sekunden) auf "Intervall 400 m" (Meter) wechselt
        // damit auch die Liste, auf die der Wert rastet.
        umfang = Rastwerte.naechster(
            zu: letzter?.volume ?? aktiveUebung?.targetMin ?? 10, in: umfangsWerte)
        nebenbelastung = nebenbelastungVorbelegt(aus: letzter?.secondaryLoad)
        // Eine andere Uebung hat ihren eigenen Satzzaehler -- eine Pause
        // oder eine Abschlussentscheidung, die zur vorherigen gehoerte,
        // gilt hier nicht mehr.
        phase = .eingabe
        // Neue Uebung, neuer Wert -- ein spaeter fuer diese Uebung
        // eintreffender Vorschlag darf wieder greifen.
        belastungVomNutzer = false
        nebenbelastungVomNutzer = false
        // Ein laufender Mitschnitt gehoert zur alten Uebung;
        // eingabeBegonnen bricht ihn ab und beginnt mit dem neuen Kontext.
        mitschnittBeginnen()
    }

    func satzSichern(problemFlag: Bool, problemReason: ProblemReason?) async {
        let geschrieben = sessions.satzSichern(
            station: Station(maschine: maschine), exerciseId: uebungId,
            einheiten: einheiten,
            load: belastung, secondaryLoad: nebenbelastung, volume: umfang,
            problemFlag: problemFlag, problemReason: problemReason
        )
        // Immer ueber die Warteschlange, nie direkt: so ist "gespeichert,
        // wird gesendet" nie gelogen, und der Offline-Pfad ist derselbe, der
        // jeden Tag laeuft (Spec Abschnitt 8.2).
        enqueue(PendingSetWrite(sessionId: geschrieben.sessionId,
                                setId: geschrieben.setId,
                                body: geschrieben.body))
        // sessions.satzSichern() oben ist der einzige Fehlschlagpfad, und
        // der wirft nicht -- lokal wird immer geschrieben, auch offline
        // (Spec Abschnitt 8.2). Der Zaehler steigt deshalb hier, nicht
        // hinter einem Erfolgs-Guard, den es nicht gibt.
        gesicherteSaetze += 1
        // Nach dem Schreiben, mit genau den geschriebenen Werten: das ist
        // das Label der Aufnahme. Wirft nicht, wartet nicht.
        mitschnitt?.satzGesichert(GesicherterSatz(
            sessionId: geschrieben.sessionId, setId: geschrieben.setId,
            setIndex: geschrieben.body.setIndex,
            // Das Label ist fuer den Wiederholungszaehler: an einem Cardio-
            // Geraet gibt es weder Kilogramm noch Wiederholungen, die Felder
            // bleiben dort leer statt eine Watt- oder Meterzahl zu tragen.
            weightKg: loadUnit == .kg ? belastung : nil,
            reps: volumeKind == .reps ? umfang : nil,
            problemFlag: problemFlag))
        // satzNummer liest live aus der Session und ist nach dem Schreiben
        // oben schon die NAECHSTE Nummer: bei Ziel 3 steht nach dem dritten
        // Satz eine 4 -- an diesem Geraet ist dann nichts mehr geplant, und
        // eine Pause vor einem Satz, der nicht kommt, ist nur Wartezeit.
        phase = satzNummer > satzZiel ? .abschluss : .neuePause()
    }

    func pauseVerlaengern() {
        guard case .pause(let timer) = phase else { return }
        phase = .pause(timer.verlaengert())
    }

    /// "Weiter" und der Ablauf der Pause nehmen denselben Weg zurueck zu
    /// den Raedern -- ein Mitglied, das vorzeitig weitermacht, landet nicht
    /// in einem anderen Zustand als eines, das die Pause aussitzt.
    func pauseBeenden() {
        // Ablauf-Task und "Weiter" koennen beide feuern. Der zweite Aufruf
        // wuerde den eben begonnenen Mitschnitt sofort wieder abbrechen.
        guard phase != .eingabe else { return }
        phase = .eingabe
        mitschnittBeginnen()
    }

    /// "Weiterer Satz" aus der Abschlussentscheidung heraus. Auch der
    /// Zusatzsatz bekommt seine Pause -- er ist ein Satz wie jeder andere,
    /// nur ausserhalb des Ziels.
    func weitererSatz() { phase = .neuePause() }

    private func mitschnittBeginnen() {
        mitschnitt?.eingabeBegonnen(SatzMitschnittKontext(
            machineId: maschine.id, machineName: maschine.equipmentModel.name,
            exerciseId: uebungId, exerciseName: aktiveUebung?.name ?? ""))
    }

    /// GeraetView ruft das aus onDisappear.
    func screenVerlassen() { mitschnitt?.screenVerlassen() }

    func kalibrierungOeffnen() { kalibrierungOffen = true }

    /// Fuellt den Entwurf mit den bisherigen Werten, sonst mit dem Minimum
    /// bzw. dem ersten erlaubten Wert einer Auswahl.
    func kalibrierungVorbereiten() {
        var entwurf: [String: Double] = [:]
        var auswahl: [String: String] = [:]
        let bisherige: [String: JSONValue]
        if case .object(let werte)? = kalibrierungswerte { bisherige = werte } else { bisherige = [:] }
        for definition in definitionen {
            if let erlaubt = definition.auswahlwerte {
                // Ein alter Wert, den das Studio inzwischen gestrichen hat,
                // wuerde am Server abgewiesen -- dann lieber neu waehlen.
                if case .string(let text)? = bisherige[definition.key], erlaubt.contains(text) {
                    auswahl[definition.key] = text
                } else if let erster = erlaubt.first {
                    auswahl[definition.key] = erster
                }
            } else if case .number(let zahl)? = bisherige[definition.key] {
                entwurf[definition.key] = zahl
            } else {
                entwurf[definition.key] = definition.minValue ?? 0
            }
        }
        entwurfEinstellung = entwurf
        entwurfAuswahl = auswahl
        kalibrierungFehler = nil
    }

    /// Gibt zurueck, ob gespeichert wurde. Die Fehlermeldung kommt vom
    /// Server -- er kennt die Grenzen und formuliert, was gilt
    /// (designsystem.md SS5).
    func kalibrierungSichern() async -> Bool {
        kalibrierungFehler = nil
        // Zahlen als Zahl, Auswahlen als Text -- calibration.ts prueft die
        // Form je Definition (Testnotiz 06.10., #17).
        var werte = entwurfEinstellung.mapValues { JSONValue.number($0) }
        for (key, text) in entwurfAuswahl { werte[key] = .string(text) }
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
