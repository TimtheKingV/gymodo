import SwiftUI

/// Chip aus dem Onboarding ("Über dich", gen.py `.chip`/`.chip.on`) und
/// jeder kuenftigen Mehrfachauswahl aus einer kleinen Menge. 44 pt hoch
/// (globale Trefferflaechen-Regel); gewaehlt = `surface`-Flaeche + 1,5-pt-
/// Akzentstrich + `text` -- die Flaeche ist `surface`, nicht `accent`: die
/// eine Akzentflaeche des Screens bleibt der Hauptaktion vorbehalten
/// (designsystem.md SS2), der Chip traegt den Akzent nur als Strich, genau
/// wie der Fokusrand der Felder.
struct Chip: View {
    let text: String
    var isActive: Bool = false
    /// Abstand zwischen Text und Rand, wenn der Chip so breit wird wie sein
    /// Text (Studiofilter der Kurse, Testnotiz 11.10., #15). Im Onboarding
    /// fuellt er die Spalte und braucht keinen.
    var innenabstand: CGFloat = 0

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isActive ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
            .padding(.horizontal, innenabstand)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isActive ? DesignSystem.Color.surface : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? DesignSystem.Color.accent : DesignSystem.Color.line,
                                 lineWidth: isActive ? 1.5 : 1)
            )
    }
}

#Preview {
    HStack {
        Chip(text: "Weiblich", isActive: true)
        Chip(text: "Männlich")
        Chip(text: "Divers")
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
