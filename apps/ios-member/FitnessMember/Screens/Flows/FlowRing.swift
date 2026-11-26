import SwiftUI

/// Ring mit Restzeit fuer den Flow-Lauf. Reine Ansicht: Bogen und Ziffer
/// kommen vom Aufrufer (aus FlowLauf.zustand), kein eigener Timer.
struct FlowRing: View {
    /// 0...1, Anteil der noch verbleibenden Zeit der Phase.
    let rest: Double
    let beschriftung: String
    let ziffer: String
    let kante: CGFloat

    @ScaledMetric(relativeTo: .body) private var skala: CGFloat = 1

    var body: some View {
        let strich = max(6, 12 * kante / 240)
        ZStack {
            Circle().stroke(DesignSystem.Color.line, lineWidth: strich)
            Circle()
                .trim(from: 0, to: max(0, min(1, rest)))
                .stroke(DesignSystem.Color.accent, style: StrokeStyle(lineWidth: strich, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: DesignSystem.Spacing.s4) {
                Text(beschriftung)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(ziffer)
                    .font(.system(size: 64 * kante / 240 * 1.2, weight: .black).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, strich * 2)
        }
        .frame(width: kante * skala, height: kante * skala)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(beschriftung), \(ziffer)")
    }
}
