import Foundation
import Testing
@testable import FitnessMember

struct HomeZeilenTests {
    private func einheit(
        id: String = "s1",
        startedAt: String = "2026-09-08T16:04:00Z",
        completedAt: String? = "2026-09-08T16:51:00Z",
        completedReason: String? = "manual"
    ) -> SessionSummary {
        SessionSummary(
            id: id, startedAt: startedAt, completedAt: completedAt,
            completedReason: completedReason, machineCount: 3, setCount: 8, blocks: [])
    }

    /// Was heute noch laeuft, ist kein Verlauf -- die laufende Einheit
    /// steht im Training-Tab.
    @Test func dieLaufendeEinheitStehtNichtImVerlauf() {
        let zeilen = HomeZeilen.abgeschlossene([
            einheit(id: "laeuft", completedAt: nil, completedReason: nil),
            einheit(id: "fertig"),
        ])

        #expect(zeilen.map(\.id) == ["fertig"])
    }

    @Test func eineBeendeteEinheitZeigtIhreDauer() {
        #expect(HomeZeilen.dauerText(einheit()) == "47 min")
    }

    /// getSessions setzt das Ende einer vergessenen Einheit auf den
    /// letzten Satz -- die daraus gerechnete Dauer ist eine Untergrenze,
    /// keine Dauer. Das Artboard laesst sie deshalb weg.
    @Test func eineSelbsttaetigBeendeteEinheitZeigtKeineDauer() {
        #expect(HomeZeilen.dauerText(einheit(completedReason: "auto")) == nil)
    }

    @Test func tageHerZaehltKalendertage() {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = Date(timeIntervalSince1970: 1_757_500_000)
        let vorbei = jetzt.addingTimeInterval(-3 * 24 * 60 * 60)

        let iso = ISO8601DateFormatter().string(from: vorbei)
        #expect(HomeZeilen.tageHer(iso, jetzt: jetzt, kalender: kalender) == 3)
    }

    @Test func ohneEinheitGibtEsKeineTageHer() {
        #expect(HomeZeilen.tageHer(nil, jetzt: Date(), kalender: .current) == nil)
    }

    @Test func derGrussNimmtDenErstenNamensteil() {
        #expect(HomeZeilen.vorname("Lena Wagner") == "Lena")
        #expect(HomeZeilen.vorname("Lena") == "Lena")
    }

    /// Ohne gesetzten Namen wird nichts erfunden -- weder Gruss noch
    /// Initialen. Aus einer Mailadresse abgeleitet saehe beides so lange
    /// richtig aus, bis es jemanden trifft.
    @Test func ohneNamenGibtEsWederGrussNochInitialen() {
        #expect(HomeZeilen.vorname(nil) == nil)
        #expect(HomeZeilen.vorname("   ") == nil)
        #expect(HomeZeilen.initialen(nil) == nil)
    }

    @Test func initialenNehmenHoechstensZweiTeile() {
        #expect(HomeZeilen.initialen("Lena Wagner") == "LW")
        #expect(HomeZeilen.initialen("Lena") == "L")
        #expect(HomeZeilen.initialen("Lena Marie Wagner") == "LM")
    }
}
