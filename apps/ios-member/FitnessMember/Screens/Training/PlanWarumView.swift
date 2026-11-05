import SwiftUI

/// "Warum so?" aus der Plankarte: drei kurze Abschnitte (Aufteilung, Gewicht,
/// Wiederholungen) aus den festen Textbausteinen in `PlanWarumText`.
///
/// Datenschutz: `gruende` kann verraten, dass Beschwerden angegeben sind
/// (`beschwerden_*`). Die Texte dazu stehen deshalb nur hier, auf dem eigenen
/// Geraet des Mitglieds, und gehen nie in Log, Testnotiz-Kontext oder
/// Analyse.
struct PlanWarumView: View {
    let struktur: String
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
                    ForEach(PlanWarumText.abschnitte(struktur: struktur, gruende: gruende), id: \.titel) { abschnitt in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                            Text(abschnitt.titel.uppercased())
                                .font(DesignSystem.Typography.label)
                                .tracking(1.5)
                                .foregroundStyle(DesignSystem.Color.textMuted)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(abschnitt.absaetze, id: \.self) { absatz in
                                Text(absatz)
                                    .font(DesignSystem.Typography.fliesstext)
                                    .foregroundStyle(DesignSystem.Color.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
    PlanWarumView(struktur: "gk_ab", gruende: ["struktur_ganzkoerper_ab", "zeit_uebungen", "fokus_po"])
}
