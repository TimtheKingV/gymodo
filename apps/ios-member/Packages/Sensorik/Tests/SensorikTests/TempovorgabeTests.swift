import Testing
import Foundation
@testable import Sensorik

@Suite struct TempovorgabeTests {
    @Test func haltenStandardIstNull() {
        #expect(Tempovorgabe(kraftweg: 2, ablassen: 3).halten == 0)
        #expect(Tempovorgabe.standard.periode == 4.0)
    }

    @Test func haltenRundetUndBegrenzt() {
        #expect(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1.2).halten == 1.0)
        #expect(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 9).halten == 3.0)
        #expect(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: -1).halten == 0)
        #expect(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: .nan).halten == 0)
    }

    @Test func periodeMitHalten() {
        #expect(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1).periode == 6.0)
    }

    @Test func altesJSONOhneHaltenDekodiert() throws {
        let v = try JSONDecoder().decode(Tempovorgabe.self, from: Data(#"{"kraftweg":2,"ablassen":3}"#.utf8))
        #expect(v == Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 0))
    }
}
