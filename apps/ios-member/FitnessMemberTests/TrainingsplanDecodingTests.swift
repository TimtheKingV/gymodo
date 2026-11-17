import Foundation
import Testing
@testable import FitnessMember

/// Dekodierung der Bootstrap-Felder `vorgaben` und `planUebungen` (P4, Testnotiz 10.11.).
struct TrainingsplanDecodingTests {
    private static let kopf = #""planId":"p1","studioId":"s1","version":1,"regelVersion":"1.2.0","struktur":"gk_ab","einheiten":[]"#

    private func dekodiere(_ json: String) throws -> Trainingsplan {
        try JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    @Test("vorgaben und planUebungen werden dekodiert")
    func vorgabenUndPlanUebungen() throws {
        let json = """
        {\(Self.kopf),
         "vorgaben":{"typ":{
           "mehrgelenk":{"typ":"mehrgelenk","wdhVon":8,"wdhBis":12,"reserveVon":1,"reserveBis":3,"pauseSek":90,"aufwaermsatz":true},
           "isolation":{"typ":"isolation","wdhVon":10,"wdhBis":15,"reserveVon":0,"reserveBis":2,"pauseSek":60,"aufwaermsatz":false}},
          "saetze":3,"cardioMin":10,"aufwaermenMin":7.5},
         "planUebungen":{"e1":{"baustein":"druecken","typ":"mehrgelenk"},"e2":{"baustein":"cardio","typ":"isolation"}}}
        """
        let plan = try dekodiere(json)
        let v = try #require(plan.vorgaben)
        #expect(v.mehrgelenk == PlanVorgaben.Typ(wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 3, pauseSek: 90, aufwaermsatz: true))
        #expect(v.isolation.wdhBis == 15)
        #expect(v.isolation.aufwaermsatz == false)
        #expect(v.saetze == 3)
        #expect(v.cardioMin == 10)
        #expect(v.aufwaermenMin == 7.5)
        #expect(plan.planUebungen["e1"] == PlanUebungsMerkmal(baustein: "druecken", typ: "mehrgelenk"))
        #expect(plan.planUebungen["e1"]?.istCardio == false)
        #expect(plan.planUebungen["e2"]?.istCardio == true)
    }

    @Test("fehlende vorgaben und planUebungen brechen die Dekodierung nicht")
    func fehlenDarfNichtBrechen() throws {
        let plan = try dekodiere("{\(Self.kopf)}")
        #expect(plan.vorgaben == nil)
        #expect(plan.planUebungen.isEmpty)
    }

    @Test("kaputte vorgaben brechen den Plan nicht")
    func kaputteVorgabenBrechenDenPlanNicht() throws {
        // `isolation` fehlt: das Objekt ist unbrauchbar, der Plan soll trotzdem laden.
        let json = """
        {\(Self.kopf),
         "vorgaben":{"typ":{
           "mehrgelenk":{"typ":"mehrgelenk","wdhVon":8,"wdhBis":12,"reserveVon":1,"reserveBis":3,"pauseSek":90,"aufwaermsatz":true}},
          "saetze":3,"cardioMin":10,"aufwaermenMin":7.5}}
        """
        let plan = try dekodiere(json)
        #expect(plan.vorgaben == nil)
        #expect(plan.version == 1)
    }
}
