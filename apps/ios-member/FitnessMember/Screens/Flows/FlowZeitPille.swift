import SwiftUI

/// Die Restzeit der Phase oben rechts, in jeder Phase an derselben Stelle.
/// Reine Ansicht: die Sekunden kommen vom Aufrufer (aus FlowLauf.zustand).
struct FlowZeitPille: View {
    let restS: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .bold))
            Text(FlowAnzeige.uhrKurz(restS))
                .font(.system(size: 17, weight: .heavy).monospacedDigit())
        }
        .foregroundStyle(DesignSystem.Color.text)
        .padding(.horizontal, DesignSystem.Spacing.s12)
        .padding(.vertical, DesignSystem.Spacing.s8)
        .background(DesignSystem.Color.surfaceRaised, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Restzeit \(FlowAnzeige.uhrKurz(restS))")
    }
}

#if DEBUG
#Preview("Zeitpille") {
    FlowZeitPille(restS: 14)
        .padding()
        .background(DesignSystem.Color.bg)
}
#endif
