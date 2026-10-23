import SwiftUI

/// Die offene Frage "Welche Übung?" einer Station mit mehreren Uebungen
/// (Finding I-2): `offen` steht zur Wahl, `schonDabei` nur im Hinweis.
struct ZirkelUebungswahl: Identifiable {
    let station: Station
    let offen: [ZirkelUebung]
    let schonDabei: [ZirkelUebung]

    var id: String { station.schluessel }

    func name(_ uebung: ZirkelUebung) -> String {
        station.exercises.first { $0.id == uebung.exerciseId }?.name ?? "Übung"
    }

    var hinweis: String? {
        schonDabei.isEmpty ? nil : "Schon im Zirkel: " + schonDabei.map(name).joined(separator: ", ")
    }
}

/// Blatt statt Aktionsdialog: der Dialog hing an der Wurzel des Auswahl-
/// Stacks und blieb unter der Kategorie-Seite unsichtbar.
struct ZirkelUebungswahlSheet: View {
    let wahl: ZirkelUebungswahl
    let beiWahl: (ZirkelUebung) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                    ForEach(wahl.offen, id: \.self) { uebung in
                        Button { beiWahl(uebung) } label: { zeile(uebung) }
                            .buttonStyle(PressButtonStyle())
                    }
                    if let hinweis = wahl.hinweis {
                        Text(hinweis)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Welche Übung?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ uebung: ZirkelUebung) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: uebung.exerciseId) { Uebungsbild() }
            Text(wahl.name(uebung))
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer()
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
