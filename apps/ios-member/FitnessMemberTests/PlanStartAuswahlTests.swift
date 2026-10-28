import Foundation
import Testing
@testable import FitnessMember

/// Tippen auf eine Planzeile oeffnet die Geraeteauswahl, beschraenkt auf die
/// Stationen, die die Uebung der Position anbieten (Spec 5: Position ist
/// eine Uebungsart, kein Geraet).
struct PlanStartAuswahlTests {
    private func uebung(_ id: String) -> String {
        #"{"id":"\#(id)","name":"Uebung \#(id)","volumeKind":"reps","targetMin":8,"targetMax":12}"#
    }

    private func maschine(_ id: String, studio: String = "s1", _ uebungen: [String]) -> String {
        """
        {"id":"\(id)","studioId":"\(studio)","label":"G \(id)","locationNote":null,"status":"active",
         "tokenHashes":["h"],"visitCount":0,
         "equipmentModel":{"id":"em-\(id)","name":"Modell \(id)","manufacturer":null,"category":"kraft",
           "photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5,"loadMax":100,"settingDefinitions":[]},
         "exercises":[\(uebungen.map(uebung).joined(separator: ","))]}
        """
    }

    private func typ(_ id: String, _ uebungen: [String]) -> String {
        """
        {"id":"\(id)","name":"Typ \(id)","manufacturer":"Gymtavo","photoPath":null,"category":"kraft",
         "loadUnit":"kg","loadStep":2.5,"loadMin":5,"loadMax":100,"retired":false,"settingDefinitions":[],
         "exercises":[\(uebungen.map(uebung).joined(separator: ","))]}
        """
    }

    private func bootstrap(maschinen: [String] = [], typen: [String] = []) -> BootstrapResponse {
        GeraetTestdaten.dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},
         "studios":[{"id":"s1","name":"Ost","timezone":"Europe/Berlin"}],
         "machines":[\(maschinen.joined(separator: ","))],"calibrations":[],"lastSets":[],
         "catalog":{"studioId":"s1","equipmentTypes":[\(typen.joined(separator: ","))]},
         "lastTypeSets":[]}
        """)
    }

    @Test("Im Studio nur die Geraete mit der Uebung")
    func imStudioNurGeraeteMitDerUebung() {
        let daten = bootstrap(maschinen: [maschine("m1", ["e1", "e5"]), maschine("m2", ["e2"]),
                                          maschine("m3", ["e1"])])
        let ids = GeraeteAuswahl.stationen(bootstrap: daten, ort: .studio("s1"), uebungId: "e1").map(\.schluessel)
        #expect(Set(ids) == ["geraet:m1", "geraet:m3"])
    }

    @Test("Im Freien Training nur die Katalogtypen mit der Uebung")
    func imFreienTrainingNurTypenMitDerUebung() {
        let daten = bootstrap(typen: [typ("t1", ["e1"]), typ("t2", ["e2"]), typ("t3", ["e1", "e2"])])
        let ids = GeraeteAuswahl.stationen(bootstrap: daten, ort: .freiesTraining, uebungId: "e1").map(\.schluessel)
        #expect(Set(ids) == ["typ:t1", "typ:t3"])
    }

    @Test("Ohne Uebung bleibt die Liste, wie sie war")
    func ohneUebungUnveraendert() {
        let daten = bootstrap(typen: [typ("t1", ["e1"]), typ("t2", ["e2"])])
        #expect(GeraeteAuswahl.stationen(bootstrap: daten, ort: .freiesTraining, uebungId: nil).count == 2)
        #expect(GeraeteAuswahl.stationen(bootstrap: daten, ort: .freiesTraining).count == 2)
    }

    @Test("Die Gruppen der Auswahl tragen nur passende Stationen")
    func gruppenNurPassende() {
        let daten = bootstrap(typen: [typ("t1", ["e1"]), typ("t2", ["e2"])])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "", uebungId: "e2")
        #expect(g.kategorien.isEmpty && g.liste.map(\.id) == ["typ:t2"])
    }

    @Test("Eine Uebung, die kein Geraet anbietet, ergibt eine leere Liste")
    func keinTreffer() {
        let daten = bootstrap(maschinen: [maschine("m1", ["e1"])])
        #expect(GeraeteAuswahl.stationen(bootstrap: daten, ort: .studio("s1"), uebungId: "e9").isEmpty)
    }
}
