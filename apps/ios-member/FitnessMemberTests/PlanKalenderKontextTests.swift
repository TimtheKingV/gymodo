import Foundation
import Testing
@testable import FitnessMember

/// Zeitzone, Kalender und geplanter Tag einer Einheit (Plan-Tab und Detail).
struct PlanKalenderKontextTests {
    private var kalender: Calendar { PlanKalenderKontext.kalender(zeitzone: "Europe/Berlin") }

    private func tag(_ monat: Int, _ tag: Int) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: monat, day: tag))!
    }

    @Test func zeitzoneFolgtDerReihenfolge() {
        #expect(PlanKalenderKontext.zeitzone(
            wochenZone: "Asia/Tokyo", ersteStudioZone: "Europe/Berlin", geraet: "UTC") == "Asia/Tokyo")
        #expect(PlanKalenderKontext.zeitzone(
            wochenZone: nil, ersteStudioZone: "Europe/Berlin", geraet: "UTC") == "Europe/Berlin")
        #expect(PlanKalenderKontext.zeitzone(
            wochenZone: nil, ersteStudioZone: nil, geraet: "UTC") == "UTC")
        #expect(PlanKalenderKontext.kalender(zeitzone: "Asia/Tokyo").timeZone.identifier == "Asia/Tokyo")
    }

    @Test func geplanterTagDerEinheit() {
        let termine: [Date: [PlanTermin]] = [
            tag(11, 5): [.einheit(key: "A", zustand: .erledigt)],
            tag(11, 6): [.einheit(key: "B", zustand: .geplant)],
            tag(11, 9): [.einheit(key: "C", zustand: .geplant)],
        ]
        let heute = tag(11, 5)
        #expect(PlanKalenderKontext.geplanterTag(
            einheitKey: "B", termine: termine, heute: heute, kalender: kalender) == tag(11, 6))
        // Erledigt zaehlt nicht als geplant.
        #expect(PlanKalenderKontext.geplanterTag(
            einheitKey: "A", termine: termine, heute: heute, kalender: kalender) == nil)
        #expect(PlanKalenderKontext.istGeplanterTag(tag(11, 6), heute: tag(11, 6), kalender: kalender))
        #expect(!PlanKalenderKontext.istGeplanterTag(tag(11, 6), heute: heute, kalender: kalender))
        #expect(!PlanKalenderKontext.istGeplanterTag(nil, heute: heute, kalender: kalender))
    }

    @Test func einheitAusserhalbDesFenstersIstNil() {
        let termine: [Date: [PlanTermin]] = [tag(12, 20): [.einheit(key: "B", zustand: .geplant)]]
        #expect(PlanKalenderKontext.geplanterTag(
            einheitKey: "B", termine: termine, heute: tag(11, 5), kalender: kalender) == nil)
        #expect(PlanKalenderKontext.geplanterTag(
            einheitKey: "X", termine: termine, heute: tag(12, 19), kalender: kalender) == nil)
        #expect(PlanKalenderKontext.fenster(heute: tag(11, 5), kalender: kalender).count == 28)
    }
}
