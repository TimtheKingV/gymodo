import Foundation
import Testing
@testable import Sensorik

/// Die Satzautomatik gegen echte Aufnahmen, so wie die App sie fuettert:
/// jeder Messwert, einmal je Sekunde Messzeit der Takt ueber die letzten
/// 60 s (ZaehlerKoordinator.taktAnstossen).
struct SatzAutomatikReplayTests {
    /// Start relativ zum Aufnahmebeginn, nil ohne Start.
    static func start(_ name: String, art: Befestigungsart) throws -> TimeInterval? {
        let (_, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { return m } else { return nil } }
        guard let profil = TaktProfil.fuer(art), let t0 = werte.first?.t else { return nil }
        var automatik = SatzAutomatik()
        var bis = t0
        for (i, wert) in werte.enumerated() {
            automatik.empfangen(wert)
            guard wert.t - bis >= 1 else { continue }
            bis = wert.t
            let fenster = Array(werte[max(0, i - 3000)...i])
            let reps = Satztakt.auswerten(fenster, rateHz: 50, profil: profil).map(Satztakt.wiederholungen) ?? []
            for ereignis in automatik.wiederholungen(reps) {
                if case .begonnen(_, let beginn, _) = ereignis { return beginn - t0 }
            }
        }
        return nil
    }

    /// Erste Wiederholung der Satzende-Auswertung (aufnahme.json).
    static func ersteWiederholung(_ name: String) throws -> TimeInterval? {
        let (datei, _) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        return datei.zaehler?.ereignisse.wiederholungen.first?.beginn
    }

    /// Testnotiz 10.11. #2: in beiden Aufnahmen startete die Automatik auf
    /// Hantieren, 20 bis 40 s vor dem Satz, und haette vor ihm beendet.
    @Test(arguments: ["2026-11-10-1823-02", "2026-11-10-1830-03"])
    func hantierenVorDemSatzStartetIhnNicht(_ name: String) throws {
        let erste = try #require(try Self.ersteWiederholung(name))
        let start = try #require(try Self.start(name, art: .kurzhantel))
        #expect(start >= erste - 2, "Start bei \(start) s, erste Wiederholung bei \(erste) s")
    }

    /// Jeder gesicherte Kurzhantel-Satz vom 10.11. startet weiter automatisch,
    /// auch die kurzen mit vier Wiederholungen.
    @Test func jederSatzVom10NovemberStartet() throws {
        let k = try Korrekturen.laden()
        let saetze = k.aufnahmen.filter { $0.key.hasPrefix("2026-11-10-") && $0.value.fuerZaehler }
            .map(\.key).filter { $0 != "2026-11-10-1854-01" }.sorted()
        #expect(saetze.count == 12)
        for name in saetze {
            #expect(try Self.start(name, art: .kurzhantel) != nil, "\(name) startet nicht")
        }
    }
}
