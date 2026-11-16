import Foundation
import Testing
@testable import FitnessMember

/// Welche Uebung im Plan waehlbar ist (P4, Testnotiz 10.11. #5).
struct PlanUebungWahlTests {
    private static let merkmale: [String: PlanUebungsMerkmal] = [
        "e1": PlanUebungsMerkmal(baustein: "brust", typ: "maschine"),
        "e2": PlanUebungsMerkmal(baustein: "brust", typ: "maschine"),
    ]

    /// Ein Studio-Geraet; `katalog` setzt `catalogModelId`.
    private static func geraet(katalog: String?, uebungen: [String] = ["e1"]) -> Station {
        let katalogFeld = katalog.map { ",\"catalogModelId\":\"\($0)\"" } ?? ""
        let liste = uebungen.map {
            "{\"id\":\"\($0)\",\"name\":\"Übung \($0)\",\"volumeKind\":\"reps\",\"targetMin\":8,\"targetMax\":12}"
        }.joined(separator: ",")
        let json = """
        {"id":"m1","studioId":"s1","label":"Gerät 1",
         "locationNote":null,"status":"active","tokenHashes":["h-m1"],"visitCount":0,
         "equipmentModel":{"id":"em-m1","name":"Modell","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]\(katalogFeld)},
         "exercises":[\(liste)]}
        """
        return Station(maschine: GeraetTestdaten.dekodiere(json))
    }

    private static func typ(uebungen: [String] = ["e1"]) -> Station {
        let liste = uebungen.map {
            "{\"id\":\"\($0)\",\"name\":\"Übung \($0)\",\"volumeKind\":\"reps\",\"targetMin\":8,\"targetMax\":12}"
        }.joined(separator: ",")
        let json = """
        {"id":"kt1","name":"Typ 1","manufacturer":null,"photoPath":null,
         "category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
         "settingDefinitions":[],"exercises":[\(liste)]}
        """
        return Station(typ: GeraetTestdaten.dekodiere(json), studioId: "kat")
    }

    @Test("Studio-Geraet ohne Katalogmodell ist gesperrt")
    func ohneKatalogmodellGesperrt() {
        let sperre = PlanUebungWahl.sperre(station: Self.geraet(katalog: nil), uebungId: "e1",
                                           merkmale: Self.merkmale, belegt: [])
        #expect(sperre == .keinKatalogmodell)
        #expect(PlanUebungWahl.text(.keinKatalogmodell) == "Nicht im Plan möglich")
    }

    @Test("Uebung ohne Planmerkmale ist gesperrt")
    func ohnePlanmerkmaleGesperrt() {
        let sperre = PlanUebungWahl.sperre(station: Self.geraet(katalog: "kt1", uebungen: ["e9"]), uebungId: "e9",
                                           merkmale: Self.merkmale, belegt: [])
        #expect(sperre == .ohnePlanmerkmale)
        #expect(PlanUebungWahl.text(.ohnePlanmerkmale) == "Noch nicht für Pläne freigegeben")
    }

    @Test("Uebung, die schon in der Einheit steht, ist gesperrt -- vor fehlenden Merkmalen")
    func schonInDerEinheitGesperrt() {
        let sperre = PlanUebungWahl.sperre(station: Self.typ(), uebungId: "e1",
                                           merkmale: Self.merkmale, belegt: ["e1"])
        #expect(sperre == .schonInDerEinheit)
        #expect(PlanUebungWahl.text(.schonInDerEinheit) == "Schon in der Einheit")
        let ohneMerkmale = PlanUebungWahl.sperre(station: Self.typ(uebungen: ["e9"]), uebungId: "e9",
                                                 merkmale: Self.merkmale, belegt: ["e9"])
        #expect(ohneMerkmale == .schonInDerEinheit)
        let ohneKatalog = PlanUebungWahl.sperre(station: Self.geraet(katalog: nil), uebungId: "e1",
                                                merkmale: Self.merkmale, belegt: ["e1"])
        #expect(ohneKatalog == .keinKatalogmodell)
    }

    @Test("Verschlagwortete Katalog-Uebung ist frei, am Geraet wie am Typ")
    func verschlagworteteKatalogUebungFrei() {
        #expect(PlanUebungWahl.sperre(station: Self.geraet(katalog: "kt1"), uebungId: "e1",
                                      merkmale: Self.merkmale, belegt: ["e2"]) == nil)
        #expect(PlanUebungWahl.sperre(station: Self.typ(), uebungId: "e1",
                                      merkmale: Self.merkmale, belegt: []) == nil)
    }

    @Test("modellId: catalogModelId am Geraet, die eigene ID am Typ, sonst nil")
    func modellIdNimmtCatalogModelId() {
        #expect(PlanUebungWahl.modellId(station: Self.geraet(katalog: "kt1")) == "kt1")
        #expect(PlanUebungWahl.modellId(station: Self.typ()) == "kt1")
        #expect(PlanUebungWahl.modellId(station: Self.geraet(katalog: nil)) == nil)
    }

    @Test("Zeile: frei, sobald eine ihrer Uebungen frei ist; ein Suchtreffer zaehlt allein")
    func zeilenSperre() {
        let station = Self.geraet(katalog: "kt1", uebungen: ["e1", "e2"])
        let grund: (Station, String) -> String? = { s, id in
            PlanUebungWahl.sperre(station: s, uebungId: id, merkmale: Self.merkmale, belegt: ["e1"])
                .map(PlanUebungWahl.text)
        }
        #expect(GeraeteAuswahl.sperrgrund(station: station, trefferUebungId: nil, gesperrt: grund) == nil)
        #expect(GeraeteAuswahl.sperrgrund(station: station, trefferUebungId: "e1", gesperrt: grund)
                == "Schon in der Einheit")
        #expect(GeraeteAuswahl.sperrgrund(station: station, trefferUebungId: nil, gesperrt: nil) == nil)
        let alleBelegt: (Station, String) -> String? = { s, id in
            PlanUebungWahl.sperre(station: s, uebungId: id, merkmale: Self.merkmale, belegt: ["e1", "e2"])
                .map(PlanUebungWahl.text)
        }
        #expect(GeraeteAuswahl.sperrgrund(station: station, trefferUebungId: nil, gesperrt: alleBelegt)
                == "Schon in der Einheit")
        // Ohne Uebung gibt es nichts fuer den Plan -- mit Katalogmodell wie ohne
        // (P4, Testnotiz 10.11. #5).
        for leer in [Self.geraet(katalog: nil, uebungen: []), Self.geraet(katalog: "kt1", uebungen: [])] {
            #expect(GeraeteAuswahl.sperrgrund(station: leer, trefferUebungId: nil, gesperrt: grund)
                    == "Nicht im Plan möglich")
            #expect(GeraeteAuswahl.sperrgrund(station: leer, trefferUebungId: nil, gesperrt: nil) == nil)
        }
    }

    @Test("Uebungswahl an einer Station mit mehreren Uebungen: offen nur die freien, die anderen im Hinweis")
    func uebungswahlFiltert() throws {
        let station = Self.geraet(katalog: "kt1", uebungen: ["e1", "e2", "e9"])
        let wahl = try #require(PlanUebungWahl.uebungswahl(station: station, merkmale: Self.merkmale, belegt: ["e1"]))
        #expect(wahl.offen.map(\.exerciseId) == ["e2"])
        #expect(wahl.hinweis == "Nicht wählbar: Übung e1 (Schon in der Einheit), Übung e9 (Noch nicht für Pläne freigegeben)")
        #expect(PlanUebungWahl.uebungswahl(station: station, merkmale: Self.merkmale, belegt: ["e1", "e2"]) == nil)
    }
}
