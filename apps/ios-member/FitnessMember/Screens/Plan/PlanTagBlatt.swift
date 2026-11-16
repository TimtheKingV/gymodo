import SwiftUI

/// Das Blatt zu einem Tag des Wochenstreifens (Spec P2 §3 Punkt 3): was an dem
/// Tag war -- Trainings, Cardio-Haken, Kurse. Die Karten baut der Plan-Tab
/// (dieselben wie in "DIESE WOCHE"); ein Tipp darauf schliesst das Blatt und
/// fuehrt weiter.
struct PlanTagBlatt<Inhalt: View>: View {
    /// "Montag, 9. Nov"
    let ueberschrift: String
    @ViewBuilder let inhalt: () -> Inhalt

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    inhalt()
                }
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s16)
                .padding(.bottom, DesignSystem.Spacing.s32)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle(ueberschrift)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
