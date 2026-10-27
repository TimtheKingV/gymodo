import SwiftUI

/// "Warum so?" aus der Plankarte -- ein Platzhalter, bis Etappe 5 die
/// Erklaertexte liefert. Zeigt die Gruende des Plans als schlichte Liste.
///
/// Datenschutz: `gruende` kann verraten, dass Beschwerden angegeben sind
/// (`beschwerden_*`). Die Codes stehen deshalb nur hier, auf dem eigenen
/// Geraet des Mitglieds, und gehen nie in Log, Testnotiz-Kontext oder
/// Analyse.
struct PlanWarumView: View {
    let gruende: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    Text("Warum dein Plan so aussieht")
                        .font(DesignSystem.Typography.detailScreentitel)
                        .tracking(-0.6)
                        .foregroundStyle(DesignSystem.Color.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("Die Erklärungen zu jedem Punkt folgen bald.")
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    if !gruende.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(gruende.enumerated()), id: \.offset) { index, grund in
                                    if index > 0 {
                                        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                                    }
                                    Text(PlanNamen.lesbar(grund))
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Color.text)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.s16)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.text)
                }
            }
        }
        // Bewusst ohne testnotizScreen(kontext:): die Gruende gehoeren nicht
        // in eine Testnotiz.
    }
}

#Preview {
    PlanWarumView(gruende: ["gk_ab", "zeit_uebungen", "schwerpunkt_po"])
}
