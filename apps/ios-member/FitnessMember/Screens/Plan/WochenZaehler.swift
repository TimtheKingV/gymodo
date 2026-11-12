import SwiftUI

/// Ein Zaehler der Woche (Kraft, Cardio, Minuten): Titel in Versalien und ein
/// Stepper mit Wert in Worten. Geteilt von "Woche anpassen" und dem Onboarding.
struct WochenZaehler: View {
    let titel: String
    @Binding var wert: Int
    let grenzen: ClosedRange<Int>
    var schritt: Int = 1
    let einheit: (Int) -> String

    init(
        _ titel: String, wert: Binding<Int>, grenzen: ClosedRange<Int>, schritt: Int = 1,
        einheit: @escaping (Int) -> String
    ) {
        self.titel = titel
        _wert = wert
        self.grenzen = grenzen
        self.schritt = schritt
        self.einheit = einheit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(titel.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            Stepper(value: $wert, in: grenzen, step: schritt) {
                Text(einheit(wert))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(titel)
            .accessibilityValue(einheit(wert))
        }
    }
}
