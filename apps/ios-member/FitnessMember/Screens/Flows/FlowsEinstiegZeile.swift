import SwiftUI

/// Die "Flows"-Zeile im Training-Tab; schiebt die Flow-Liste auf den Stack.
/// Geteilt von der Plan-Auswahl und der Geraeteliste (ohne Plan / freies Training).
struct FlowsEinstiegZeile: View {
    var body: some View {
        NavigationLink {
            FlowListeView()
        } label: {
            HStack(spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flows")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("Angeleitete Workouts zum Mitmachen")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(DesignSystem.Spacing.s16)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityHint("Öffnet die Liste der Flows")
    }
}
