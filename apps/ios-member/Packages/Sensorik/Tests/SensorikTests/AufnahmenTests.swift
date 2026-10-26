import Foundation
import Testing
@testable import Sensorik

/// Jede Aufnahme mit bekannter Wahrheit laeuft durch den Zaehler. Hier wird
/// nicht die Guete geprueft (das macht GueteberichtTests), sondern dass der
/// Zaehler echte Daten ohne Absturz, deterministisch und stimmig verarbeitet.
struct AufnahmenTests {
    static let mitWahrheit: [String] = {
        guard let k = try? Korrekturen.laden() else { return [] }
        return k.aufnahmen.filter { $0.value.repsWahr != nil && $0.value.befestigungsart != nil }
            .keys.sorted()
    }()

    @Test func korrekturenSindLesbarUndKennenDieNeuenFelder() throws {
        let k = try Korrekturen.laden()
        #expect(k.aufnahmen["2026-10-08-0836-01"]?.befestigungsart == .langhantel)
        #expect(k.aufnahmen["2026-10-04-0912-01"]?.befestigungsart == nil)
    }

    @Test func heute18OktoberIstEingetragen() throws {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        let ordner = try fm.contentsOfDirectory(atPath: Pfade.aufnahmen.path)
            .filter { $0.hasPrefix("2026-10-18-") }
            .filter { fm.fileExists(atPath: Pfade.aufnahmen.appendingPathComponent($0).appendingPathComponent("messwerte.csv").path) }
        #expect(!ordner.isEmpty)
        for name in ordner { #expect(k.aufnahmen[name] != nil, "\(name) fehlt in korrekturen.json") }
        let echt = ordner.compactMap { k.aufnahmen[$0] }.filter(\.fuerZaehler)
        #expect(echt.count == 36)
        #expect(k.aufnahmen["2026-10-18-1702-01"]?.repsWahr == 25)
        #expect(k.aufnahmen["2026-10-18-1702-01"]?.befestigungsart == .langhantel)
    }

    @Test func bestaetigteGegenprobeVom26OktoberIstVollstaendig() throws {
        let k = try Korrekturen.laden()
        let neu = k.aufnahmen.filter { $0.key.hasPrefix("2026-10-26-") }
        #expect(neu.count == 45)
        #expect(neu.values.filter(\.fuerZaehler).count == 27)
        #expect(neu.values.filter { $0.repsWahr == nil && !$0.fuerZaehler }.count == 18)
        for eintrag in neu.values where eintrag.fuerZaehler {
            #expect(eintrag.grund?.contains("selbst geprüft bestätigt") == true)
        }
        #expect(neu["2026-10-26-1741-01"]?.repsWahr == 20)
    }

    @Test(arguments: mitWahrheit)
    func aufnahmeLaeuftDeterministischUndStimmig(name: String) throws {
        let k = try Korrekturen.laden()
        let art = try #require(k.aufnahmen[name]?.befestigungsart)
        let ordner = Pfade.aufnahmen.appendingPathComponent(name)
        let erster = try AufnahmeLauf.zaehlen(ordner: ordner, art: art)
        let zweiter = try AufnahmeLauf.zaehlen(ordner: ordner, art: art)
        #expect(erster == zweiter)
        #expect(erster.last == .zuende)
        let wiederholungen = erster.compactMap { if case .wiederholung(let w) = $0 { w } else { nil } }
        #expect(wiederholungen.map(\.nummer) == Array(stride(from: 1, through: wiederholungen.count, by: 1)))
        for w in wiederholungen { #expect(w.beginn < w.umkehr && w.umkehr < w.ende) }
        #expect(zip(wiederholungen, wiederholungen.dropFirst()).allSatisfy { $0.beginn < $1.beginn })
    }

    @Test func mitWahrheitIstNichtLeer() {
        #expect(!Self.mitWahrheit.isEmpty)
    }
}
