#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    private enum Blatt: String, Identifiable {
        case notiz
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            case .ausschnitt:
                AuswahlOverlay(art: .rechteck, beiRechteck: testnotiz.ausschnittGewaehlt, beiPunkt: { _ in }, beiAbbruch: testnotiz.zurRuhe)
            case .element:
                AuswahlOverlay(art: .punkt, beiRechteck: { _ in }, beiPunkt: { punkt in
                    Task { await testnotiz.elementGewaehlt(punkt) }
                }, beiAbbruch: testnotiz.zurRuhe)
            case .notiz:
                Color.clear
            }
        }
        .sheet(item: blatt) { blatt in
            switch blatt {
            case .notiz: NotizBlatt()
            }
        }
    }

    private var blatt: Binding<Blatt?> {
        Binding(
            get: {
                switch testnotiz.modus {
                case .notiz: .notiz
                default: nil
                }
            },
            set: { neu in
                // Wischen schliesst das Blatt; das verwirft den Entwurf.
                if neu == nil, testnotiz.modus == .notiz {
                    testnotiz.zurRuhe()
                }
            }
        )
    }
}
#endif
