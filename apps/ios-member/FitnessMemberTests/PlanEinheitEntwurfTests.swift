import Foundation
import Testing
@testable import FitnessMember

struct PlanEinheitEntwurfTests {
    private func position(
        _ key: String, baustein: String = "mehrgelenk", typ: String = "mehrgelenk", saetze: Int = 3,
        wdh: (Int, Int)? = (8, 12), pause: Int = 150, aufwaerm: Bool = true, dauer: Int? = nil
    ) -> TrainingsplanPosition {
        TrainingsplanPosition(
            key: key, baustein: baustein, rolle: "haupt", exerciseId: "e\(key)", modelId: "m\(key)", typ: typ,
            saetze: saetze, wdhVon: wdh?.0, wdhBis: wdh?.1, reserveVon: 1, reserveBis: 2, pauseSek: pause,
            aufwaermsatz: aufwaerm, dauerMin: dauer, hauptmuskeln: [])
    }

    private func einheit(_ ps: [TrainingsplanPosition]) -> TrainingsplanEinheit {
        TrainingsplanEinheit(key: "A", positionen: ps, geschaetzteMinuten: nil)
    }

    private let vorgaben: PlanVorgaben = {
        let json = """
        {"typ":{"mehrgelenk":{"wdhVon":6,"wdhBis":10,"reserveVon":1,"reserveBis":2,"pauseSek":150,"aufwaermsatz":true},
        "isolation":{"wdhVon":10,"wdhBis":15,"reserveVon":0,"reserveBis":1,"pauseSek":90,"aufwaermsatz":false}},
        "saetze":3,"cardioMin":20,"aufwaermenMin":5}
        """
        return try! JSONDecoder().decode(PlanVorgaben.self, from: Data(json.utf8))
    }()

    private func merkmal(_ baustein: String, _ typ: String) -> PlanUebungsMerkmal {
        try! JSONDecoder().decode(PlanUebungsMerkmal.self, from: Data(#"{"baustein":"\#(baustein)","typ":"\#(typ)"}"#.utf8))
    }

    private var merkmale: [String: PlanUebungsMerkmal] {
        ["neuKraft": merkmal("druecken", "isolation"), "neuMehr": merkmal("druecken", "mehrgelenk"),
         "bike": merkmal("cardio", "isolation")]
    }

    private func entwurf(_ ps: [TrainingsplanPosition], vorgaben: PlanVorgaben? = nil) -> PlanEinheitEntwurf {
        PlanEinheitEntwurf(einheit: einheit(ps), vorgaben: vorgaben ?? self.vorgaben, merkmale: merkmale)
    }

    @Test func unveraendertIstNichtGeaendert() {
        var e = entwurf([position("0"), position("1")])
        #expect(!e.geaendert)
        e.verschieben(von: [1], nach: 0)
        #expect(e.geaendert)
        e.verschieben(von: [0], nach: 2)
        #expect(!e.geaendert)
    }

    @Test func verschiebenWieArrayMove() {
        var e = entwurf((0..<4).map { position("\($0)") })
        e.verschieben(von: [0, 2], nach: 4)
        var referenz = ["0", "1", "2", "3"]
        referenz.move(fromOffsets: [0, 2], toOffset: 4)
        #expect(e.positionen.map(\.key) == referenz.map { Optional($0) })
    }

    @Test func letztePositionLaesstSichNichtEntfernen() {
        var e = entwurf([position("0"), position("1")])
        #expect(e.darfEntfernen)
        let erstes = e.entfernen(id: e.positionen[0].id)
        #expect(erstes)
        #expect(!e.darfEntfernen)
        let zweites = e.entfernen(id: e.positionen[0].id)
        #expect(!zweites)
        #expect(e.positionen.count == 1)
    }

    @Test func hinzufuegenSetztVorgabenUndKeinenKey() {
        var e = entwurf([position("0")])
        e.hinzufuegen(exerciseId: "neuKraft", modelId: "mn")
        let p = e.positionen[1]
        #expect(p.key == nil && p.neu)
        #expect(p.art == .kraft(typ: "isolation"))
        #expect(p.saetze == 3 && p.wdhVon == 10 && p.wdhBis == 15 && p.pauseSek == 90 && p.dauerMin == nil)
        #expect(!p.aufwaermsatz)
        #expect(e.geaendert)
    }

    @Test func tauschKraftBehaeltWerteUndMerktAltenNamen() {
        var e = entwurf([position("0", saetze: 4, wdh: (5, 8), pause: 120)])
        e.tauschen(id: e.positionen[0].id, exerciseId: "neuKraft", modelId: "mn", alterName: "Beinpresse")
        let p = e.positionen[0]
        #expect(p.key == "0" && p.exerciseId == "neuKraft" && p.ersetzt == "Beinpresse")
        #expect(p.saetze == 4 && p.wdhVon == 5 && p.wdhBis == 8 && p.pauseSek == 120)
        #expect(p.art == .kraft(typ: "isolation") && !p.aufwaermsatz)
    }

    @Test func tauschKraftZuCardioSetztDauer() {
        var e = entwurf([position("0")])
        e.tauschen(id: e.positionen[0].id, exerciseId: "bike", modelId: "mb", alterName: "Beinpresse")
        let p = e.positionen[0]
        #expect(p.art == .cardio && p.saetze == 1 && p.wdhVon == nil && p.wdhBis == nil)
        #expect(p.pauseSek == 0 && p.dauerMin == 20)
    }

    @Test func werteSetzenMarkiertGeaenderteFelder() {
        var e = entwurf([position("0")])
        let id = e.positionen[0].id
        #expect(e.geaenderteWerte(id: id).isEmpty)
        e.werteSetzen(id: id, saetze: 4, wdhVon: 8, wdhBis: 12, pauseSek: 90, dauerMin: nil)
        #expect(e.geaenderteWerte(id: id) == [.saetze, .pause])
    }

    @Test func minutenWieDomain() {
        // Fixture wie plan-einheit-ersetzen.test.ts: 3 Saetze, 150 s Pause, Aufwaermsatz
        // = 1.5 + 3*0.75 + 2*2.5 + 1.5 = 10.25 (positionMinuten-Test). Dazu Isolation
        // 3 Saetze, 90 s: 1.5 + 2.25 + 3 = 6.75; Cardio 20; Aufwaermen 5 -> 42.
        let e = entwurf([
            position("0"),
            position("1", typ: "isolation", pause: 90, aufwaerm: false),
            position("2", baustein: "cardio", typ: "isolation", saetze: 1, wdh: nil, pause: 0, aufwaerm: false, dauer: 20),
        ])
        #expect(abs(entwurf([position("0")]).geschaetzteMinuten - 15.25) < 1e-9)
        #expect(abs(e.geschaetzteMinuten - 42) < 1e-9)
    }

    @Test func rumpfSendetNurAbweichungenUndNeues() throws {
        var e = entwurf([position("0"), position("1"), position("2", baustein: "cardio", typ: "isolation", saetze: 1, wdh: nil, pause: 0, aufwaerm: false, dauer: 20)])
        #expect(e.rumpf.allSatisfy { $0.saetze == nil && $0.pauseSek == nil && $0.dauerMin == nil && $0.wdhVon == nil })
        e.werteSetzen(id: e.positionen[0].id, saetze: 4, wdhVon: 8, wdhBis: 12, pauseSek: 150, dauerMin: nil)
        e.werteSetzen(id: e.positionen[2].id, saetze: 1, wdhVon: nil, wdhBis: nil, pauseSek: 0, dauerMin: 30)
        e.hinzufuegen(exerciseId: "neuKraft", modelId: "mn")
        let r = e.rumpf
        #expect(r[0] == ErsetzenPosition(key: "0", exerciseId: "e0", modelId: "m0", saetze: 4))
        #expect(r[1] == ErsetzenPosition(key: "1", exerciseId: "e1", modelId: "m1"))
        #expect(r[2] == ErsetzenPosition(key: "2", exerciseId: "e2", modelId: "m2", dauerMin: 30))
        #expect(r[3] == ErsetzenPosition(key: nil, exerciseId: "neuKraft", modelId: "mn", saetze: 3, wdhVon: 10, wdhBis: 15, pauseSek: 90))
        let daten = try JSONEncoder().encode(r[3])
        let json = try JSONSerialization.jsonObject(with: daten) as! [String: Any]
        #expect(json["key"] is NSNull && json["dauerMin"] == nil)
    }

    @Test func rumpfSendetNieWerteDerFalschenArt() {
        var e = entwurf([position("0"), position("1", baustein: "cardio", typ: "isolation", saetze: 1, wdh: nil, pause: 0, aufwaerm: false, dauer: 20)])
        e.tauschen(id: e.positionen[0].id, exerciseId: "bike", modelId: "mb", alterName: "x")
        e.tauschen(id: e.positionen[1].id, exerciseId: "neuKraft", modelId: "mn", alterName: "y")
        let r = e.rumpf
        #expect(r[0] == ErsetzenPosition(key: "0", exerciseId: "bike", modelId: "mb", dauerMin: 20))
        #expect(r[1].dauerMin == nil && r[1].saetze == 3 && r[1].pauseSek == 90)
    }

    @Test func ohneVorgabenBleibenWerteOffen() {
        var e = PlanEinheitEntwurf(einheit: einheit([position("0")]), vorgaben: nil, merkmale: merkmale)
        e.tauschen(id: e.positionen[0].id, exerciseId: "bike", modelId: "mb", alterName: "x")
        e.hinzufuegen(exerciseId: "neuKraft", modelId: "mn")
        #expect(e.positionen.allSatisfy { $0.werteOffen })
        #expect(e.rumpf == [
            ErsetzenPosition(key: "0", exerciseId: "bike", modelId: "mb"),
            ErsetzenPosition(key: nil, exerciseId: "neuKraft", modelId: "mn"),
        ])
    }

    @Test func nachKonfliktWerdenFehlendeKeysNeu() {
        var e = entwurf([position("0"), position("1")])
        e.nachKonflikt(neueEinheit: einheit([position("1"), position("2")]))
        #expect(e.positionen.map(\.key) == [nil, "1"])
        #expect(e.rumpf[0].saetze == 3)
    }

    @Test func darfBearbeitenNurOhneLaufendeSessionAnDieserEinheit() {
        #expect(!PlanEinheitEntwurf.darfBearbeiten(einheitKey: "A", laufEinheitKey: "A", gebunden: true))
        #expect(PlanEinheitEntwurf.darfBearbeiten(einheitKey: "A", laufEinheitKey: "B", gebunden: true))
        #expect(PlanEinheitEntwurf.darfBearbeiten(einheitKey: "A", laufEinheitKey: "A", gebunden: false))
        #expect(PlanEinheitEntwurf.darfBearbeiten(einheitKey: "A", laufEinheitKey: nil, gebunden: true))
    }
}
