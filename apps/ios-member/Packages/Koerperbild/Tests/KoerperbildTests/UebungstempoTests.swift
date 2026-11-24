import XCTest
@testable import Koerperbild
import Sensorik

final class UebungstempoTests: XCTestCase {
    func testKniebeugeBeginntMitSenken() {
        let t = Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken)
        XCTAssertEqual(t.vorgabe, Tempovorgabe(kraftweg: 3, ablassen: 2, halten: 1))
        XCTAssertEqual(t.phase(.kraftweg), .senken); XCTAssertEqual(t.phase(.halten), .halten); XCTAssertEqual(t.phase(.ablassen), .heben)
        XCTAssertEqual(t.inWorten, "3 s senken · 1 s halten · 2 s heben")
    }

    func testCurlBeginntMitHeben() {
        let t = Uebungstempo.standard(beginntMit: .heben)
        XCTAssertEqual(t.vorgabe, Tempovorgabe(kraftweg: 1.5, ablassen: 2.5, halten: 0))
        XCTAssertEqual(t.inWorten, "1,5 s heben · 2,5 s senken")
        XCTAssertEqual(t.phase(.kraftweg), .heben); XCTAssertEqual(t.phase(.ablassen), .senken)
    }

    func testStandardMitSenkenZuerst() {
        let t = Uebungstempo.standard(beginntMit: .senken)
        XCTAssertEqual(t.vorgabe, Tempovorgabe(kraftweg: 2.5, ablassen: 1.5, halten: 0))
        XCTAssertEqual(t.inWorten, "2,5 s senken · 1,5 s heben")
    }
}
