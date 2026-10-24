import SwiftUI

/// Die kleine "Heute dran"-Zeile auf Home (Entwurf 2, Frage 1): welche
/// Einheit dran ist und wie viel davon. Tippen fuehrt in den Training-Tab,
/// wo die Plankarte steht -- Home bekommt keine zweite Planansicht.
///
/// Kein Akzent: Home hat seine eine Akzentflaeche schon.
struct HeuteDranZeile: View {
    let heute: PlanAnzeige.Heute
    let beiTippen: () -> Void

    var body: some View {
        let untertitel = PlanAnzeige.heuteDranUntertitel(heute)
        Button { beiTippen() } label: {
            Card {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text("HEUTE DRAN")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textFaint)
                        Text(EinheitName.text(heute.einheitKey))
                            .font(DesignSystem.Typography.uebungsname)
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(untertitel)
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                .padding(DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heute dran: \(EinheitName.text(heute.einheitKey)), \(untertitel)")
        .accessibilityHint("Öffnet das Training")
        .accessibilityAddTraits(.isButton)
        .testnotizElement("home.heuteDran", typ: "Button")
    }
}
