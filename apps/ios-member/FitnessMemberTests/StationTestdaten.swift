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
