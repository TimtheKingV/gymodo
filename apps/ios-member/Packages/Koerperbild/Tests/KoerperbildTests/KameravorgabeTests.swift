import XCTest
@testable import Koerperbild

final class KameravorgabeTests: XCTestCase {
    func testPflichtgelenkeGanzkoerperMitKnie() {
        let v = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
        XCTAssertEqual(v.pflichtgelenke(.links), [.schulterL, .hueftL, .knieL, .fussL])
    }
    func testPflichtgelenkeLiegendNurSignal() {
        let v = Kameravorgabe(profil: .liegend, signal: .ellbogen, seite: .beide)!
        XCTAssertEqual(v.pflichtgelenke(.rechts), [.schulterR, .ellbogenR, .handR])
    }
    func testSignalGelenkeImmerPflicht() {
        let v = Kameravorgabe(profil: .oberkoerper, signal: .schulter, seite: .beide)!
        XCTAssertTrue(v.pflichtgelenke(.links).contains(.hueftL))
    }
    func testVorgabeOhneSignalNurOhneKamera() {
        XCTAssertNil(Kameravorgabe(profil: .oberkoerper, signal: nil, seite: .beide))
        XCTAssertNotNil(Kameravorgabe(profil: .ohneKamera, signal: nil, seite: .beide))
    }
    func testOhneKameraVerwirftSignal() {
        let v = Kameravorgabe(profil: .ohneKamera, signal: .knie, seite: .beide)!
        XCTAssertNil(v.signal)
        XCTAssertTrue(v.pflichtgelenke(.links).isEmpty)
    }
    func testGelenkgruppenSeitenrichtig() {
        XCTAssertEqual(Gelenkgruppe.arme.gelenke(.rechts), [.ellbogenR, .handR])
        XCTAssertEqual(Gelenkgruppe.hueftenKnie.gelenke(.links), [.hueftL, .knieL])
        XCTAssertEqual(Gelenkgruppe.schultern.gelenke(.links), [.schulterL])
        XCTAssertEqual(Gelenkgruppe.fuesse.gelenke(.rechts), [.fussR])
    }
}
