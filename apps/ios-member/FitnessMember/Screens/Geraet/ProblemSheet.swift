import SwiftUI

/// Boolean plus feste Liste, kein Freitext -- Freitext ueber Schmerzen waeren
/// besondere Kategorien nach Art. 9 DSGVO. Ein Feld, das nicht existiert,
/// muss nicht geschuetzt, exportiert oder geloescht werden (M1-Spec SS5.8).
///
/// Die Meldung braucht keinen eigenen Endpoint: sie sind zwei Felder im
/// Satz-PUT (M1-Spec SS6.3).
struct ProblemSheet: View {
    let modell: GeraetModel
    let beiSichern: () -> Void

    @State private var grund: ProblemReason?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf
                    Text("Was ist los?")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("Wird an diesem Satz vermerkt. Solange etwas gemeldet ist, schlägt gymodo keine Steigerung vor.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .lineSpacing(3)

                    VStack(spacing: DesignSystem.Spacing.s8) {
                        ForEach(ProblemReason.allCases, id: \.self) { ursache in
                            Button { grund = ursache } label: { zeile(ursache) }
                                .buttonStyle(PressButtonStyle())
                        }
                    }

                    Text("Kein Freitextfeld — mit Absicht. Was du nicht schreiben kannst, muss auch niemand schützen, exportieren oder löschen. Sprich mit deinem Studio, wenn mehr dahintersteckt.")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(3)

                    PrimaryButton(
                        title: "Melden und Satz sichern",
                        isEnabled: grund != nil,
                        disabledHint: "Wähle aus, was los ist."
                    ) {
                        await modell.satzSichern(problemFlag: true, problemReason: grund)
                        beiSichern()
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Problem melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(modell.maschine.equipmentModel.name) · \(modell.aktiveUebung?.name ?? "")")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
            Spacer()
            Text(Zahlformat.gewichtMitEinheit(modell.gewicht))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
        }
    }

    private func zeile(_ ursache: ProblemReason) -> some View {
        let gewaehlt = grund == ursache
        return HStack(spacing: DesignSystem.Spacing.s12) {
            // warn NUR als Umriss, nie als Flaeche -- das Artboard fuellt hier
            // faelschlich (Spec Abschnitt 9). Eine warngelbe Flaeche liesse
            // die Meldung als Fehlverhalten lesen.
            Circle()
                .strokeBorder(gewaehlt ? DesignSystem.Color.warn : DesignSystem.Color.line,
                              lineWidth: gewaehlt ? 2.5 : 1.5)
                .frame(width: 22, height: 22)
            Text(beschriftung(ursache))
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer()
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der Kontur weg und laesst eine halbe uebrig
        // (Vorlage: InlineBanner).
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(gewaehlt ? DesignSystem.Color.warn : Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : .isButton)
    }

    private func beschriftung(_ ursache: ProblemReason) -> String {
        switch ursache {
        case .schmerz: "Schmerzen"
        case .geraetePasstNicht: "Gerät passt mir nicht"
        case .zuSchwer: "Zu schwer"
        case .sonstiges: "Etwas anderes"
        }
    }
}
