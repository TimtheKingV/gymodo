import SwiftUI

/// Chip aus dem Onboarding ("Über dich", gen.py `.chip`/`.chip.on`) und
/// jeder kuenftigen Mehrfachauswahl aus einer kleinen Menge. 44 pt hoch
/// (globale Trefferflaechen-Regel); gewaehlt = `surface`-Flaeche + 1,5-pt-
/// Akzentstrich + `text` -- die Flaeche ist `surface`, nicht `accent`: die
/// eine Akzentflaeche des Screens bleibt der Hauptaktion vorbehalten
/// (designsystem.md SS2), der Chip traegt den Akzent nur als Strich, genau
/// wie der Fokusrand der Felder.
///
/// `gefuellt`: die Auswahl der Trainingsplan-Entwuerfe (Etappe 3, 1.1-1.4,
/// Korrektur Tim): gewaehlt = weisse Flaeche (`text`) mit dunkler Schrift
/// (`onAccent`). Weiss ist keine Akzentflaeche, die eine Hauptaktion bleibt
/// die einzige. Ein eigener Parameter statt einer neuen Vorgabe: Reserve-
/// Skala, Kursfilter, Kalibrierung und "Über dich" zeigen weiter den
/// Akzentstrich, die Entwuerfe aendern sie nicht.
struct Chip: View {
    let text: String
    var isActive: Bool = false
    /// Abstand zwischen Text und Rand, wenn der Chip so breit wird wie sein
    /// Text (Studiofilter der Kurse, Testnotiz 11.10., #15). Im Onboarding
    /// fuellt er die Spalte und braucht keinen.
    var innenabstand: CGFloat = 0
    var gefuellt: Bool = false

    private var schrift: SwiftUI.Color {
        guard isActive else { return DesignSystem.Color.textMuted }
        return gefuellt ? DesignSystem.Color.onAccent : DesignSystem.Color.text
    }

    private var flaeche: SwiftUI.Color {
        guard isActive else { return .clear }
        return gefuellt ? DesignSystem.Color.text : DesignSystem.Color.surface
    }

    private var rand: SwiftUI.Color {
        guard isActive else { return DesignSystem.Color.line }
        return gefuellt ? DesignSystem.Color.text : DesignSystem.Color.accent
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(schrift)
            .padding(.horizontal, innenabstand)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(flaeche)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(rand, lineWidth: isActive && !gefuellt ? 1.5 : 1)
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

#Preview("Gefüllt") {
    HStack {
        Chip(text: "60", isActive: true, gefuellt: true)
        Chip(text: "75", gefuellt: true)
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
