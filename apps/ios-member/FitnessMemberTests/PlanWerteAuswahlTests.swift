import Foundation
import Testing

@testable import FitnessMember

/// Auswahlwerte fuer das Anpassen-Blatt (P4).
struct PlanWerteAuswahlTests {
    @Test func pausenStufenEnthalten150() {
        #expect(PlanWerteAuswahl.pausenStufen(aktuell: 90).contains(150))
    }

    @Test func pausenStufenNehmenUngewoehnlichenWertAuf() {
        let stufen = PlanWerteAuswahl.pausenStufen(aktuell: 75)
        #expect(stufen.contains(75))
        #expect(stufen == stufen.sorted())
    }

    @Test func pausenStufenOhneDubletten() {
        let stufen = PlanWerteAuswahl.pausenStufen(aktuell: 90)
        #expect(stufen.count == Set(stufen).count)
    }

    @Test func wdhBisNieUnterVon() {
        #expect(PlanWerteAuswahl.wdhBisBereich(von: 12) == 12...50)
        #expect(PlanWerteAuswahl.wdhBisBereich(von: 12).lowerBound >= 12)
    }

    @Test func dauerStufenNehmenAktuellAuf() {
        let stufen = PlanWerteAuswahl.dauerStufen(aktuell: 33)
        #expect(stufen.contains(33))
        #expect(stufen == stufen.sorted())
        #expect(PlanWerteAuswahl.dauerStufen(aktuell: 30).count == PlanWerteAuswahl.dauerStufen.count)
    }

    @Test func wdhBisFolgtVon() {
        #expect(PlanWerteAuswahl.wdhBisNachVon(von: 12, bis: 10) == 12)
        #expect(PlanWerteAuswahl.wdhBisNachVon(von: 8, bis: 10) == 10)
    }

    private func ausgang(art: EntwurfsArt, wdh: (Int, Int)?, dauer: Int?) -> EntwurfsPosition {
        EntwurfsPosition(
            id: UUID(), key: "k", exerciseId: "e", modelId: "m", art: art, saetze: 3,
            wdhVon: wdh?.0, wdhBis: wdh?.1, pauseSek: 150, dauerMin: dauer, aufwaermsatz: false)
    }

    @Test func unberuehrtGibtAusgangswerteInklusiveNil() {
        let kraft = ausgang(art: .kraft(typ: "mehrgelenk"), wdh: nil, dauer: nil)
        let e = PlanWerteAuswahl.ergebnis(
            ausgang: kraft, saetze: 5, wdhVon: 8, wdhBis: 8, pauseSek: 60, dauerMin: 20, beruehrt: [])
        #expect(e == .init(saetze: 3, wdhVon: nil, wdhBis: nil, pauseSek: 150, dauerMin: nil))
        let cardio = ausgang(art: .cardio, wdh: nil, dauer: nil)
        let c = PlanWerteAuswahl.ergebnis(
            ausgang: cardio, saetze: 5, wdhVon: 8, wdhBis: 8, pauseSek: 60, dauerMin: 20, beruehrt: [])
        #expect(c.dauerMin == nil)
    }

    @Test func nurBeruehrteFelderWechseln() {
        let kraft = ausgang(art: .kraft(typ: "mehrgelenk"), wdh: (8, 12), dauer: nil)
        let e = PlanWerteAuswahl.ergebnis(
            ausgang: kraft, saetze: 4, wdhVon: 1, wdhBis: 1, pauseSek: 60, dauerMin: 20, beruehrt: [.saetze])
        #expect(e == .init(saetze: 4, wdhVon: 8, wdhBis: 12, pauseSek: 150, dauerMin: nil))
    }
}
