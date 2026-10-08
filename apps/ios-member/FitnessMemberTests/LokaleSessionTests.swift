import Foundation
import Testing
@testable import FitnessMember

struct LokaleSessionTests {
    @Test func eineAlteSessionDateiDekodiertMitGeraeteSchluessel() throws {
        // Format von vor dem Katalog: Bloecke nur mit machineId, ohne Einheiten.
        let json = """
        {"id":"8F0A1C3E-5B6D-4E7F-8A9B-0C1D2E3F4A5B","startedAt":780000000,
         "bloecke":[{"machineId":"m1","exerciseId":"e1","saetze":[]}]}
        """
        let session = try JSONDecoder().decode(LokaleSession.self, from: Data(json.utf8))
        let block = try #require(session.bloecke.first)
        #expect(block.stationSchluessel == "geraet:m1")
        #expect(block.machineId == "m1")
        #expect(block.equipmentModelId == nil)
        #expect(block.id == "geraet:m1:e1")
    }

    @Test func einBlockAmTypUeberlebtDenKreislauf() throws {
        let block = LokalerBlock(station: .testTyp("t1"), exerciseId: "e1", saetze: [])
        let zurueck = try JSONDecoder().decode(LokalerBlock.self, from: JSONEncoder().encode(block))
        #expect(zurueck == block)
        #expect(zurueck.stationSchluessel == "typ:t1")
        #expect(zurueck.machineId == nil)
        #expect(zurueck.equipmentModelId == "t1")
    }

    @Test func einBlockOhneStationLaesstSichNichtDekodieren() {
        let json = #"{"exerciseId":"e1","saetze":[]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LokalerBlock.self, from: Data(json.utf8))
        }
    }
}
