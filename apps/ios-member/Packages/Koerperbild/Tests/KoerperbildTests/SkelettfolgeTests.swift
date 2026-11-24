import XCTest
@testable import Koerperbild

final class SkelettfolgeTests: XCTestCase {
    func testSkelettfolgeHinUndZurueck() throws {
        let f = Skelettfolge(bildrate: 24, seitenverhaeltnis: 0.5625, bilder: [skelett([.nase: (0.5, 0.1)], sv: 0.5625), nil])
        let g = try Skelettfolge(daten: f.daten())
        XCTAssertEqual(g.bilder.count, 2); XCTAssertNil(g.bilder[1])
        XCTAssertEqual(g.bilder[0]?.punkte[.nase]?.x, 0.5)
    }
    func testSkelettfolgeUnbekanntesGelenkWirdUebergangen() throws {
        let json = #"{"bildrate":24,"seitenverhaeltnis":0.5625,"bilder":[{"schweif":[0.1,0.1,0.9],"nase":[0.5,0.1,0.9]}]}"#
        XCTAssertEqual(try Skelettfolge(daten: Data(json.utf8)).bilder[0]?.punkte.count, 1)
    }
}
