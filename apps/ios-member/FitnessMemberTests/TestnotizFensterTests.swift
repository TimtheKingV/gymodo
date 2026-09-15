#if DEBUG
import CoreGraphics
import Testing
@testable import FitnessMember

@MainActor
struct TestnotizFensterTests {
    private let knopf = CGRect(x: 350, y: 500, width: 44, height: 44)

    @Test func inRuheFaengtNurDerKnopf() {
        #expect(TestnotizFenster.faengt(punkt: CGPoint(x: 372, y: 522), modus: .ruhe, knopfRahmen: knopf))
        #expect(!TestnotizFenster.faengt(punkt: CGPoint(x: 40, y: 300), modus: .ruhe, knopfRahmen: knopf))
    }

    @Test func einFingerbreitNebenDemKnopfFaengtNoch() {
        #expect(TestnotizFenster.faengt(punkt: CGPoint(x: 345, y: 522), modus: .ruhe, knopfRahmen: knopf))
        #expect(!TestnotizFenster.faengt(punkt: CGPoint(x: 340, y: 522), modus: .ruhe, knopfRahmen: knopf))
    }

    @Test func inJedemModusFaengtDieGanzeFlaeche() {
        #expect(TestnotizFenster.faengt(punkt: CGPoint(x: 40, y: 300), modus: .menue, knopfRahmen: knopf))
    }

    @Test func knopfBleibtGanzSichtbar() {
        #expect(KnopfLage.mitteY(gewuenscht: -50, hoehe: 700) == 22)
        #expect(KnopfLage.mitteY(gewuenscht: 900, hoehe: 700) == 678)
        #expect(KnopfLage.mitteY(gewuenscht: 300, hoehe: 700) == 300)
    }

    @Test func kleinerWegIstEinTipp() {
        #expect(KnopfLage.istTipp(CGSize(width: 3, height: -4)))
        #expect(!KnopfLage.istTipp(CGSize(width: 0, height: 12)))
    }
}
#endif
