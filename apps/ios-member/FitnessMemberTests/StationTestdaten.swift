import Foundation
@testable import FitnessMember

extension Station {
    /// Ein Geraet mit frei waehlbarer Kennung; es steht immer in einem Studio.
    static func testGeraet(_ id: String, studioId: String = "s1") -> Station {
        let json = """
        {"id":"\(id)","studioId":"\(studioId)","label":"Gerät \(id)",
         "locationNote":null,"status":"active","tokenHashes":["h-\(id)"],"visitCount":0,
         "equipmentModel":{"id":"em-\(id)","name":"Modell","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[]}
        """
        return Station(maschine: GeraetTestdaten.dekodiere(json))
    }

    /// Ein Geraetetyp ohne Geraet an einem Ort (nil = Freies Training).
    static func testTyp(_ id: String, studioId: String? = "s1") -> Station {
        let json = """
        {"id":"\(id)","name":"Typ \(id)","manufacturer":null,"photoPath":null,
         "category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
         "settingDefinitions":[],"exercises":[]}
        """
        return Station(typ: GeraetTestdaten.dekodiere(json), studioId: studioId)
    }
}

extension LokalerBlock {
    /// Der Block an einem Geraet, wenn nur dessen Kennung vorliegt -- so,
    /// wie ihn eine Sessiondatei von vor dem Katalog traegt. Nur die Tests
    /// brauchen ihn; ueber den Decoder, damit er genau dem Altbestand gleicht.
    init(machineId: String, exerciseId: String,
         einheiten: Blockeinheiten = .kilogrammWiederholungen, saetze: [LokalerSatz]) {
        struct Altblock: Encodable {
            let machineId: String
            let exerciseId: String
            let loadUnit: LoadUnit
            let secondaryUnit: LoadUnit?
            let volumeKind: VolumeKind
            let saetze: [LokalerSatz]
        }
        let alt = Altblock(machineId: machineId, exerciseId: exerciseId,
                           loadUnit: einheiten.loadUnit, secondaryUnit: einheiten.secondaryUnit,
                           volumeKind: einheiten.volumeKind, saetze: saetze)
        self = try! JSONDecoder().decode(LokalerBlock.self, from: JSONEncoder().encode(alt))
    }
}
