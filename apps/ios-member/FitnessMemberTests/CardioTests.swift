import Foundation
import Testing
@testable import FitnessMember

/// Testnotiz 14.10., 18:45 #7: Cardio-Werte in der App.
struct CardioTests {
    @Test func dieReihenfolgeIstDieDesServers() {
        #expect(CardioWert.allCases.map(\.rawValue) == ["zeit", "strecke", "stufe", "kmh", "steigung", "watt", "frequenz", "kcal"])
    }

    @Test func werteLassenSichJeSchluesselSetzen() {
        var w = CardioWerte()
        w[.zeit] = 510
        w[.kmh] = 10.5
        #expect(w.zeit == 510)
        #expect(w.kmh == 10.5)
        #expect(!w.istLeer)
        w[.zeit] = nil
        w[.kmh] = nil
        #expect(w.istLeer)
    }

    /// Review Focus 5: ein Satz ohne load (Cardio) bricht weder Bootstrap noch Verlauf.
    @Test func lastSetMitLoadNullDekodiert() throws {
        let json = #"{"machineId":"m","exerciseId":"e","load":null,"secondaryLoad":null,"volume":null,"rir":null,"performedAt":"2026-10-15T10:00:00Z","cardio":{"zeit":510,"strecke":2000}}"#
        let s = try JSONDecoder().decode(BootstrapResponse.LastSet.self, from: Data(json.utf8))
        #expect(s.load == nil)
        #expect(s.cardio?.strecke == 2000)
    }

    @Test func alterVerlaufOhneCardioDekodiert() throws {
        let json = #"{"setIndex":1,"load":40,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:00:00Z"}"#
        let s = try JSONDecoder().decode(SessionSummary.Block.Set.self, from: Data(json.utf8))
        #expect(s.load == 40)
        #expect(s.cardio == nil)
    }

    @Test func modellOhneCardioWerteIstKraft() throws {
        // Ein Server von vor E2 schickt das Feld nicht.
        #expect(Station.testGeraet("m").equipmentModel.cardioWerte.isEmpty)
    }

    @Test func modellMitCardioWerteIgnoriertUnbekannte() throws {
        let station = Station.testCardio("c", werte: [.zeit, .kmh])
        #expect(station.equipmentModel.cardioWerte == [.zeit, .kmh])
        let json = #"{"id":"t","name":"T","manufacturer":null,"photoPath":null,"category":"cardio","loadUnit":"level","loadStep":1,"loadMin":1,"loadMax":null,"settingDefinitions":[],"exercises":[],"cardioWerte":["zeit","zukunft","watt"]}"#
        let typ = try JSONDecoder().decode(BootstrapResponse.Catalog.EquipmentType.self, from: Data(json.utf8))
        #expect(typ.cardioWerte == [.zeit, .watt])
        #expect(Station(typ: typ, studioId: nil).equipmentModel.cardioWerte == [.zeit, .watt])
    }

    @Test func setWriteSchicktCardioOhneLoad() throws {
        let body = SetWrite(machineId: "m", exerciseId: "e", setIndex: 1, load: nil, volume: nil,
                            cardio: CardioWerte(zeit: 510))
        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        #expect(json.contains(#""cardio":{"zeit":510}"#))
        #expect(!json.contains(#""load""#))
    }

    @Test func alteWarteschlangeMitLoadDekodiert() throws {
        let json = #"{"machineId":"m","exerciseId":"e","setIndex":1,"load":5,"volume":1200,"problemFlag":false,"volumeSource":"eingegeben"}"#
        let body = try JSONDecoder().decode(SetWrite.self, from: Data(json.utf8))
        #expect(body.load == 5)
        #expect(body.cardio == nil)
    }
}
