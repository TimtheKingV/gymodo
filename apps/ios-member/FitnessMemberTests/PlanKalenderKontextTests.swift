import Foundation
import Testing
@testable import FitnessMember

/// Zeitzone und Kalender des Plans (Plan-Tab, Detail und Home).
struct PlanKalenderKontextTests {
    private var kalender: Calendar { PlanKalenderKontext.kalender(zeitzone: "Europe/Berlin") }

    @Test func zeitzoneFolgtDerReihenfolge() {
        #expect(PlanKalenderKontext.zeitzone(
            wochenZone: "Asia/Tokyo", ersteStudioZone: "Europe/Berlin", geraet: "UTC") == "Asia/Tokyo")
        #expect(PlanKalenderKontext.zeitzone(
            wochenZone: nil, ersteStudioZone: "Europe/Berlin", geraet: "UTC") == "Europe/Berlin")
        #expect(PlanKalenderKontext.zeitzone(
            wochenZone: nil, ersteStudioZone: nil, geraet: "UTC") == "UTC")
        #expect(PlanKalenderKontext.kalender(zeitzone: "Asia/Tokyo").timeZone.identifier == "Asia/Tokyo")
    }
}
