#if DEBUG
import Foundation
import OSLog
import Testing
@testable import FitnessMember

struct TestnotizProtokollTests {
    @Test func stufenHabenFesteNamen() {
        #expect(TestnotizProtokoll.stufe(.info) == "info")
        #expect(TestnotizProtokoll.stufe(.error) == "error")
        #expect(TestnotizProtokoll.stufe(.fault) == "fault")
        #expect(TestnotizProtokoll.stufe(.debug) == "debug")
        #expect(TestnotizProtokoll.stufe(.notice) == "notice")
    }

    @Test func liestNurErlaubteKategorienDesEigenenSubsystems() throws {
        let marke = UUID().uuidString
        Logger(subsystem: TestnotizProtokoll.subsystem, category: "tag").notice("erlaubt \(marke, privacy: .public)")
        Logger(subsystem: TestnotizProtokoll.subsystem, category: "konto").notice("verboten \(marke, privacy: .public)")
        Logger(subsystem: "de.anderes.subsystem", category: "tag").notice("fremd \(marke, privacy: .public)")

        let zeilen = TestnotizProtokoll.lesen(seit: 60, bis: Date())
        let meine = zeilen.filter { $0.message.contains(marke) }
        #expect(meine.count == 1)
        #expect(meine.first?.message == "erlaubt \(marke)")
        #expect(meine.first?.category == "tag")
        #expect(meine.first?.level == "notice")
    }

    @Test func modellkennungIstKeineArchitektur() {
        let kennung = Laufzeitkontext.modellkennung()
        #expect(kennung.hasPrefix("iPhone") || kennung.hasPrefix("iPad"))
    }
}
#endif
