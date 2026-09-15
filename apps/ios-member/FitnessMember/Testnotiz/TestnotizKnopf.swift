#if DEBUG
import SwiftUI

enum KnopfLage {
    static let durchmesser: CGFloat = 44

    /// Klemmt die Knopfmitte so, dass der ganze Kreis sichtbar bleibt.
    static func mitteY(gewuenscht: CGFloat, hoehe: CGFloat) -> CGFloat {
        let halb = durchmesser / 2
        return min(max(gewuenscht, halb), max(hoehe - halb, halb))
    }

    /// Unter 6 pt Weg ist es ein Tipp, kein Zug.
    static func istTipp(_ zug: CGSize) -> Bool {
        abs(zug.width) < 6 && abs(zug.height) < 6
    }
}

/// Der schwebende Kreis am rechten Rand, vertikal verschiebbar.
struct TestnotizKnopf: View {
    @State private var mitteY: CGFloat?
    @State private var startY: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let y = mitteY ?? geo.size.height * 0.62
            Image(systemName: "note.text")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.accent)
                .frame(width: KnopfLage.durchmesser, height: KnopfLage.durchmesser)
                .background(DesignSystem.Color.surfaceRaised, in: Circle())
                .overlay(Circle().stroke(DesignSystem.Color.line, lineWidth: 1))
                .contentShape(Circle())
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rahmen in
                    Testnotiz.shared.knopfRahmen = rahmen
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { wert in
                            let start = startY ?? y
                            startY = start
                            mitteY = KnopfLage.mitteY(gewuenscht: start + wert.translation.height, hoehe: geo.size.height)
                        }
                        .onEnded { wert in
                            startY = nil
                            if KnopfLage.istTipp(wert.translation) {
                                Testnotiz.shared.knopfGetippt()
                            }
                        }
                )
                .accessibilityLabel("Testnotiz")
                .accessibilityAddTraits(.isButton)
                .position(x: geo.size.width - KnopfLage.durchmesser / 2 - DesignSystem.Spacing.s8, y: y)
        }
    }
}
#endif
