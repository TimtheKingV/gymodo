import SwiftUI

/// Eine der vier Kacheln aus Onboarding-Schritt 3 ("Dein Ziel") -- Symbol,
/// Titel, Zeile. Gewaehlt = Akzentstrich, keine Flaeche: dieselbe Regel
/// wie beim `Chip` (designsystem.md SS2, Zwei Regeln Nr. 1), damit die
/// Hauptaktion am Fuss des Screens die einzige Akzentflaeche bleibt.
struct Zielkachel: View {
    let symbol: String
    let titel: String
    let zeile: String
    let istGewaehlt: Bool
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    // Gewaehlt = text statt textMuted (Brief Step 2,
                    // Tabellenzeile "Dein Ziel") -- derselbe Kontrast, den
                    // die Kachel-Flaeche selbst nicht tragen darf.
                    .foregroundStyle(istGewaehlt ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titel)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(zeile)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                    .stroke(istGewaehlt ? DesignSystem.Color.accent : DesignSystem.Color.line,
                            lineWidth: istGewaehlt ? 1.5 : 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        // Titel und Zeile in EINEM Element (Brief, VoiceOver-Abschnitt):
        // sonst liest VoiceOver "Abnehmen" und "Gewicht runter, Kraft
        // halten" als zwei Stopps statt einer Aussage.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel), \(zeile)")
        .accessibilityAddTraits(istGewaehlt ? [.isSelected] : [])
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        Zielkachel(symbol: "arrow.down.right", titel: "Abnehmen", zeile: "Gewicht runter, Kraft halten", istGewaehlt: true) {}
        Zielkachel(symbol: "dumbbell", titel: "Muskeln aufbauen", zeile: "Mehr Gewicht je Übung", istGewaehlt: false) {}
        Zielkachel(symbol: "waveform.path.ecg", titel: "Fit bleiben", zeile: "Dranbleiben, regelmäßig", istGewaehlt: false) {}
        Zielkachel(symbol: "arrow.up.right", titel: "Stärker werden", zeile: "Schwerere Sätze", istGewaehlt: false) {}
    }
    .padding(28)
    .background(DesignSystem.Color.bg)
}
