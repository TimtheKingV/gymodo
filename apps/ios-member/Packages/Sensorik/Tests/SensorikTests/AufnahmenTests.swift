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
