import SwiftUI

/// Die eine Karte "Heute dran" auf Home (Leinwand 2d): welche Einheit dran
/// ist und wie viel davon. "Training starten" fuehrt in den Training-Tab, wo
/// die Uebungsliste steht -- Home bekommt keine zweite Planansicht, und der
/// Training-Tab keine zweite Ueberschrift "Heute dran" (E8).
///
/// Der Knopf ist ein Umriss, keine Akzentflaeche: Home hat seine eine
/// Akzentflaeche schon (designsystem.md SS2). Nur die Marke "HEUTE DRAN"
/// steht im Akzent, als Schrift.
struct HeuteDranZeile: View {
    let heute: PlanAnzeige.Heute
    let muskeln: [String: [GeraetMuskel]]
    let beiTippen: () -> Void

    var body: some View {
        let untertitel = PlanAnzeige.heuteDranUntertitel(heute)
        let name = EinheitNamen(plan: heute.plan, muskeln: muskeln).name(heute.einheitKey)
        Card {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HEUTE DRAN")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.accent)
                    Text(name)
                        .font(DesignSystem.Typography.detailScreentitel)
                        .foregroundStyle(DesignSystem.Color.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(untertitel)
                        .font(DesignSystem.Typography.fliesstext)
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Heute dran: \(name), \(untertitel)")
                .accessibilityAddTraits(.isHeader)
                SecondaryButton(title: "Training starten") { beiTippen() }
                    .accessibilityHint("Öffnet das Training")
                    .testnotizElement("home.heuteDran", typ: "Button")
            }
            .padding(20)
        }
    }
}
