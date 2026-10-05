import SwiftUI

/// "3 Monate · 6 Monate · Seit Start" ueber den beiden Verlaufsdiagrammen.
///
/// Ein Baustein statt zweier Abschriften, und mit eigenem ButtonStyle: in
/// einer `List`-Zeile (Gewichtsverlauf) loest ein Tipp mit dem
/// Standardstil die Aktion JEDES Knopfs der Zeile aus -- der letzte
/// gewinnt. Wer einmal "Alles" gewaehlt hatte, kam deshalb nie wieder auf
/// "3 Monate" zurueck (Testnotiz 05.10., #4). Mit eigenem Stil ist nur
/// das gestylte Label tippbar; Rahmen und Flaeche stehen deshalb im Label.
///
/// Der Akzent markiert den aktiven Wert -- die eine Akzentflaeche dieser
/// Screens (designsystem.md SS2).
struct FensterUmschalter: View {
    @Binding var fenster: Fortschrittsfenster

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(Fortschrittsfenster.allCases) { wahl in
                Button { fenster = wahl } label: {
                    Text(wahl.titel)
                        .font(DesignSystem.Typography.label)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .frame(height: 44)
                        .background(wahl == fenster ? DesignSystem.Color.accent : DesignSystem.Color.surface)
                        .foregroundStyle(wahl == fenster ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.pille))
                        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.pille))
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityAddTraits(wahl == fenster ? .isSelected : [])
            }
        }
    }
}
