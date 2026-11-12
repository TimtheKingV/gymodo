import SwiftUI

/// "Woche anpassen" (Spec P2 §4): wie oft Kraft, wie oft Cardio, wie lange.
/// Schreibt nur die Zaehler ins Trainingsprofil -- der Plan selbst bleibt
/// stabil (F14), die Folge der Einheiten aendert sich nicht.
struct WocheAnpassenSheet: View {
    let profil: TrainingsplanProfil
    /// Liefert einen Fehlertext oder nil (dann schliesst das Sheet).
    let speichern: (TrainingsplanProfil) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var auswahl: WochenAuswahl
    @State private var fehler: String?
    @State private var laeuft = false

    static let hinweis = "Du legst fest, wie oft – nicht wann. Montag beginnt die Woche neu."

    init(ziel: Wochenziel, profil: TrainingsplanProfil, speichern: @escaping (TrainingsplanProfil) async -> String?) {
        self.profil = profil
        self.speichern = speichern
        _auswahl = State(initialValue: WochenAuswahl(ziel: ziel, profil: profil))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    zaehler("Kraft", wert: $auswahl.kraft, grenzen: WochenAuswahl.kraftGrenzen,
                            einheit: { "\($0)× pro Woche" })
                    zaehler("Cardio", wert: $auswahl.cardio, grenzen: WochenAuswahl.cardioGrenzen,
                            einheit: { $0 == 0 ? "kein Cardio" : "\($0)× pro Woche" })
                    if auswahl.cardio >= 1 {
                        zaehler("Minuten je Cardio", wert: $auswahl.cardioMinuten,
                                grenzen: WochenAuswahl.minutenGrenzen, schritt: WochenAuswahl.minutenSchritt,
                                einheit: { "\($0) min" })
                        cardioArten
                    }

                    Text(Self.hinweis)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let fehler {
                        Text(fehler)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.danger)
                    }

                    PrimaryButton(title: "Speichern", isEnabled: !laeuft, isLoading: laeuft) {
                        laeuft = true
                        fehler = await speichern(auswahl.profil(aus: profil))
                        laeuft = false
                        if fehler == nil { dismiss() }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Woche anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private var cardioArten: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("WAS MACHST DU?")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            Fliesslayout(abstand: DesignSystem.Spacing.s8) {
                ForEach(PlanAuswahl.cardioArten, id: \.code) { art in
                    let istAktiv = auswahl.cardioArten.contains(art.code)
                    Button { auswahl.cardioArtUmschalten(art.code) } label: {
                        Chip(text: art.text, isActive: istAktiv, innenabstand: DesignSystem.Spacing.s16, gefuellt: true)
                            .fixedSize()
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel(art.text)
                    .accessibilityAddTraits(istAktiv ? [.isToggle, .isSelected] : .isToggle)
                }
            }
        }
    }

    private func zaehler(
        _ titel: String, wert: Binding<Int>, grenzen: ClosedRange<Int>, schritt: Int = 1,
        einheit: @escaping (Int) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(titel.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            Stepper(value: wert, in: grenzen, step: schritt) {
                Text(einheit(wert.wrappedValue))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(titel)
            .accessibilityValue(einheit(wert.wrappedValue))
        }
    }
}
