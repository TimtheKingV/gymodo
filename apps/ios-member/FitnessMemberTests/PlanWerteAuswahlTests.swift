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
}
