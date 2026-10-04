#if DEBUG
import Foundation
import Observation
import os

/// Zwischen Satzpfad und Sensor (Spec 7.3). GeraetModel sagt, wo der Satz
/// steht; die Quelle sagt, was der Sensor schickt; hier wird daraus ein
/// Aufnahme-Ordner.
///
/// Nichts hier wirft nach aussen. Jeder Fehler landet in `fehler` und im
/// Log -- der Satz des Mitglieds haengt nicht an einem Debug-Mitschnitt.
@MainActor
@Observable
final class SensorAufnahmeKoordinator: SatzMitschnitt {
    static let ratentestDauer: TimeInterval = 300
    /// Eigene Kategorie: in der Konsole getrennt vom Tag-Protokoll filterbar.
    private static let log = Logger(subsystem: "de.gymtaro.member", category: "sensor")

    let quelle: any SensorQuelle
    private(set) var aufnahmeLaeuft = false
    private(set) var fehler: String?
    /// Einmal je Sekunde aktualisiert, nicht je Messwert: bei 50 Hz wuerde
    /// die Zeile sonst fuenfzigmal je Sekunde neu gezeichnet.
    private(set) var anzeigeRateHz: Double = 0
    private(set) var statistik: SensorStatistik.Ergebnis = .leer
    private(set) var verbundenSeit: Date?
    private(set) var ratentestRest: Int?
    private(set) var letzterRatentest: URL?

    @ObservationIgnored private let wurzel: URL
    @ObservationIgnored private let geraet: SensorAufnahmeDatei.Geraet
    @ObservationIgnored private let einstellungen: UserDefaults
    @ObservationIgnored private let uhr: () -> TimeInterval
    @ObservationIgnored private let jetzt: () -> Date

    @ObservationIgnored private var aufnahme: SensorAufnahme?
    @ObservationIgnored private var aufnahmeStatistik = SensorStatistik()
    @ObservationIgnored private var verworfenBeiStart = 0
    /// Gesetzt, solange die Raeder stehen. Verbindet sich der Sensor erst
    /// dann, beginnt die Aufnahme in diesem Moment (Spec 6.4).
    @ObservationIgnored private var offenerKontext: SatzMitschnittKontext?
    @ObservationIgnored private var gesamt = SensorStatistik()
    @ObservationIgnored private var letzteAnzeige: TimeInterval = 0
    /// Merkt sich die letzte Verbunden-Kante, nicht welcher Zustand konkret
    /// vorliegt: jeder Uebergang verbunden -> nicht-verbunden ist EINE Luecke,
    /// egal ob danach .getrennt, .aus, .sucht oder .bluetoothNichtBereit
    /// gemeldet wird. Ohne diese Kante wuerde jeder nicht-verbundene
    /// Nicht-.getrennt-Zustand die Ausfallzeit als normalen Paketabstand in
    /// die Statistik falten und Median/p95/Rate verfaelschen.
    @ObservationIgnored private var warVerbunden: Bool
    @ObservationIgnored private var ratentest: (statistik: SensorStatistik, startT: TimeInterval?, start: Date, verworfen: Int)?
    @ObservationIgnored private var lauscher: Task<Void, Never>?

    init(quelle: any SensorQuelle, wurzel: URL, geraet: SensorAufnahmeDatei.Geraet,
         einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         jetzt: @escaping () -> Date = { Date() }) {
        self.quelle = quelle
        self.wurzel = wurzel
        self.geraet = geraet
        self.einstellungen = einstellungen
        self.uhr = uhr
        self.jetzt = jetzt
        // Ein Koordinator, der erst nach dem Verbinden entsteht (Tests bauen
        // ihn ueber aufbau(zustand: verbunden) so auf), muss die erste
        // Trennung noch als Kante erkennen -- sonst faellt sie unter den Tisch.
        self.warVerbunden = quelle.zustand.istVerbunden
    }

    /// Einmal beim App-Start. Getrennt vom init, damit Tests `empfangen`
    /// direkt und in fester Reihenfolge rufen koennen.
    func starten() {
        guard lauscher == nil else { return }
        SensorAufnahme.verwaisteNachtragen(wurzel: wurzel)
        let strom = quelle.ereignisse()
        lauscher = Task { [weak self] in
            for await ereignis in strom { self?.empfangen(ereignis) }
        }
    }

    // MARK: - SatzMitschnitt

    func eingabeBegonnen(_ kontext: SatzMitschnittKontext) {
        beenden(.abgebrochen, satz: nil)
        fehler = nil
        offenerKontext = kontext
        if quelle.zustand.istVerbunden { aufnahmeBeginnen() }
    }

    func satzGesichert(_ satz: GesicherterSatz) {
        beenden(.gesichert, satz: satz)
        offenerKontext = nil
    }

    func screenVerlassen() {
        beenden(.abgebrochen, satz: nil)
        offenerKontext = nil
    }

    // MARK: - Eingang

    func empfangen(_ ereignis: SensorEreignis) {
        switch ereignis {
        case .messwert(let messwert): messwertVerarbeiten(messwert)
        case .zustand(let zustand): zustandVerarbeiten(zustand)
        }
    }

    private func messwertVerarbeiten(_ messwert: SensorMesswert) {
        gesamt.erfassen(t: messwert.t)
        if messwert.t - letzteAnzeige >= 1 {
            letzteAnzeige = messwert.t
            anzeigeRateHz = gesamt.rateLetzteSekunde(bis: messwert.t)
            statistik = gesamt.ergebnis(verworfeneBytes: quelle.verworfeneBytes)
            if let test = ratentest, let startT = test.startT {
                ratentestRest = max(0, Int(Self.ratentestDauer - (messwert.t - startT)))
            }
        }

        // Ein Paket, das vor dem Anlegen der Aufnahme empfangen wurde, kommt
        // trotzdem erst danach aus dem Strom. Es gehoert zur Zeit davor und
        // stuende sonst mit negativem t in der CSV.
        if let aufnahme, messwert.t >= aufnahme.startT {
            aufnahmeStatistik.erfassen(t: messwert.t)
            do { try aufnahme.schreiben(messwert) } catch { abbrechen(wegen: error) }
        }

        if var test = ratentest {
            if test.startT == nil { test.startT = messwert.t }
            test.statistik.erfassen(t: messwert.t)
            ratentest = test
            if let startT = test.startT, messwert.t - startT >= Self.ratentestDauer { ratentestAbschliessen() }
        }
    }

    private func zustandVerarbeiten(_ zustand: SensorZustand) {
        if zustand.istVerbunden {
            warVerbunden = true
            if verbundenSeit == nil { verbundenSeit = jetzt() }
            if let aufnahme {
                do { try aufnahme.lueckeEndet(t: uhr()) } catch { abbrechen(wegen: error) }
            } else if offenerKontext != nil {
                aufnahmeBeginnen()
            }
        } else {
            anzeigeRateHz = 0
            // Die Luecke gehoert an die Kante, nicht an den Zielzustand: sonst
            // wuerde z.B. .getrennt -> .sucht -> .verbindet dieselbe Trennung
            // dreimal zaehlen, und ein Wechsel direkt nach .aus/.bluetoothNichtBereit
            // (Bluetooth aus waehrend des Satzes) wuerde ueberhaupt keine Luecke
            // schreiben -- die Ausfallzeit laege dann als normaler Paketabstand
            // in `abstaende` und verdirbt Median/p95/Rate der Aufnahme.
            if warVerbunden {
                warVerbunden = false
                gesamt.lueckeBegonnen()
                ratentest?.statistik.lueckeBegonnen()
                if let aufnahme {
                    aufnahmeStatistik.lueckeBegonnen()
                    aufnahme.lueckeBeginnt(t: uhr())
                }
            }
            if case .getrennt = zustand {
                // Erwartete kurze Unterbrechung (Spec 6.4/7.3): die Anzeige-
                // Statistik ueberlebt den Reconnect, eine laufende Aufnahme
                // oder ein laufender Ratentest hat ihre Luecke oben schon.
            } else {
                verbundenSeit = nil
                gesamt = SensorStatistik()
                statistik = .leer
            }
        }
    }

    // MARK: - Aufnahme

    private func aufnahmeBeginnen() {
        guard aufnahme == nil, let kontext = offenerKontext else { return }
        do {
            aufnahme = try SensorAufnahme(
                wurzel: wurzel, start: jetzt(), startT: uhr(),
                sensor: .init(name: quelle.zustand.name ?? "unbekannt",
                              rateSollHz: quelle.rate.rawValue,
                              akkuProzent: quelle.zustand.akkuProzent),
                geraet: geraet,
                kontext: .init(machineId: kontext.machineId, machineName: kontext.machineName,
                               exerciseId: kontext.exerciseId, exerciseName: kontext.exerciseName,
                               sessionId: nil, setId: nil, setIndex: nil),
                befestigung: gemerkteBefestigung(kontext.machineId))
            aufnahmeStatistik = SensorStatistik()
            verworfenBeiStart = quelle.verworfeneBytes
            aufnahmeLaeuft = true
        } catch {
            abbrechen(wegen: error)
        }
    }

    private func beenden(_ abschluss: SensorAufnahmeDatei.Abschluss, satz: GesicherterSatz?) {
        guard let aufnahme else { return }
        self.aufnahme = nil
        aufnahmeLaeuft = false
        var kontext = aufnahme.datei.kontext
        kontext.sessionId = satz?.sessionId.uuidString
        kontext.setId = satz?.setId.uuidString
        kontext.setIndex = satz?.setIndex
        do {
            try aufnahme.abschliessen(
                abschluss, kontext: kontext,
                label: .init(weightKg: satz?.weightKg, reps: satz?.reps, problemFlag: satz?.problemFlag),
                akkuProzent: quelle.zustand.akkuProzent,
                statistik: aufnahmeStatistik.ergebnis(verworfeneBytes: quelle.verworfeneBytes - verworfenBeiStart),
                ende: jetzt(), endeT: uhr())
        } catch {
            melden(error)
        }
    }

    private func abbrechen(wegen error: Error) {
        melden(error)
        let kaputt = aufnahme
        aufnahme = nil
        aufnahmeLaeuft = false
        // Bester Versuch: der Ordner soll nicht als "laeuft" liegen bleiben.
        if let kaputt {
            try? kaputt.abschliessen(.abgebrochen, kontext: kaputt.datei.kontext, label: .init(),
                                     akkuProzent: nil, statistik: .leer, ende: jetzt(), endeT: uhr())
        }
    }

    private func melden(_ error: Error) {
        fehler = "Aufnahme fehlgeschlagen: \(error.localizedDescription)"
        Self.log.error("Sensoraufnahme: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Befestigung

    private func schluessel(_ machineId: String) -> String { "sensor.befestigung.\(machineId)" }

    private func gemerkteBefestigung(_ machineId: String) -> String? {
        let text = einstellungen.string(forKey: schluessel(machineId)) ?? ""
        return text.isEmpty ? nil : text
    }

    func befestigung(fuer machineId: String) -> String { gemerkteBefestigung(machineId) ?? "" }

    func befestigungSetzen(_ text: String, fuer machineId: String) {
        einstellungen.set(text.trimmingCharacters(in: .whitespacesAndNewlines), forKey: schluessel(machineId))
    }

    // MARK: - Ratentest

    func ratentestStarten() {
        ratentest = (SensorStatistik(), nil, jetzt(), quelle.verworfeneBytes)
        ratentestRest = Int(Self.ratentestDauer)
        letzterRatentest = nil
    }

    private func ratentestAbschliessen() {
        guard let test = ratentest else { return }
        ratentest = nil
        ratentestRest = nil
        let datei = SensorRatentestDatei(
            format: SensorRatentestDatei.formatkennung, startedAt: test.start, endedAt: jetzt(),
            sensor: .init(name: quelle.zustand.name ?? "unbekannt", rateSollHz: quelle.rate.rawValue,
                          akkuProzent: quelle.zustand.akkuProzent),
            geraet: geraet,
            statistik: test.statistik.ergebnis(verworfeneBytes: quelle.verworfeneBytes - test.verworfen))
        do {
            try FileManager.default.createDirectory(at: wurzel, withIntermediateDirectories: true)
            let url = wurzel.appendingPathComponent("ratentest-\(Zeitformat.ordnername(test.start, zeitzone: .current)).json")
            try JSONEncoder.testnotiz().encode(datei).write(to: url, options: .atomic)
            letzterRatentest = url
        } catch {
            melden(error)
        }
    }
}
#endif
