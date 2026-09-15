#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            case .ausschnitt:
                AuswahlOverlay(art: .rechteck, beiRechteck: testnotiz.ausschnittGewaehlt, beiPunkt: { _ in }, beiAbbruch: testnotiz.zurRuhe)
            }
        }
    }
}
#endif
