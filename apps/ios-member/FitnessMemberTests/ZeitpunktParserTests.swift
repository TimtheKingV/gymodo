import Foundation
import Testing
@testable import FitnessMember

/// Die Suche parst bei jedem Durchlauf alle letzten Saetze (Offline-Spec
/// 1b) -- das Ergebnis muss nach dem Umbau auf geteilte Parser gleich sein.
struct ZeitpunktParserTests {
    @Test func parstMitUndOhneBruchteile() {
        #expect(Zeitpunkt.parse("2026-10-15T18:00:00Z") == Date(timeIntervalSince1970: 1_792_087_200))
        #expect(Zeitpunkt.parse("2026-10-15T18:00:00.250Z") == Date(timeIntervalSince1970: 1_792_087_200.25))
        #expect(Zeitpunkt.parse("kein Datum") == nil)
    }

    @Test func parstNebenlaeufigGleich() async {
        let ergebnisse = await withTaskGroup(of: Date?.self) { gruppe in
            for _ in 0..<200 { gruppe.addTask { Zeitpunkt.parse("2026-10-15T18:00:00.250Z") } }
            return await gruppe.reduce(into: [Date?]()) { $0.append($1) }
        }
        #expect(Set(ergebnisse.compactMap { $0 }).count == 1)
    }
}
