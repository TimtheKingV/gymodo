import SwiftUI

/// Schritt 2 von 3 -- und zugleich der Screen hinter "aendern" auf
/// GeraetView. Genau dieser Fall ausserhalb des Dreischritts macht den
/// eigenen Endpoint noetig.
struct KalibrierungSchritt: View {
    @Bindable var modell: GeraetModel
    let titel: String
    let beiFertig: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                Text(titel.uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)

                Text(modell.maschine.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)

                Text("Stell das Gerät jetzt so ein, wie es für dich passt. Beim nächsten Mal steht es hier — du musst nicht nachdenken.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(4)

                ForEach(modell.einstellDefinitionen) { definition in
                    Stepper44(
                        definition: definition,
                        wert: Binding(
                            get: { modell.entwurfEinstellung[definition.key] ?? definition.minValue ?? 0 },
                            set: { modell.entwurfEinstellung[definition.key] = $0 }
                        )
                    )
                }

                // Abweichung vom Artboard (Spec Abschnitt 9, wie schon bei
                // "andere Uebung" in GeraetView): dort accent. Der Schalter
                // ist weder die Hauptaktion noch der aktive Wert -- die
                // beiden Rollen, die designsystem.md SS5 dem Akzent
                // zuweist. Ein zweites Accentfeld neben "Speichern und
                // weiter" verletzte "genau eine Akzentflaeche je Screen".
                Toggle("Ein Trainer war dabei", isOn: $modell.trainerDabei)
                    .tint(DesignSystem.Color.text)
                    .foregroundStyle(DesignSystem.Color.text)
                Text("Wird an der Einstellung vermerkt. Ändern darfst du sie trotzdem jederzeit selbst.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let fehler = modell.kalibrierungFehler {
                    InlineBanner(tone: .danger, message: fehler)
                }

                PrimaryButton(title: "Speichern und weiter") {
                    if await modell.kalibrierungSichern() { beiFertig() }
                }

                Text("Deine vorherigen Einstellungen bleiben erhalten — jede Änderung legt eine neue Zeile an.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
        // Fuellt den Entwurf bei jedem Eintritt neu -- ob aus dem Dreischritt
        // (Aufgabe 13) oder ueber "aendern" auf GeraetView (Aufgabe 12). Ohne
        // das startete das Rad immer am Minimum statt an der bisherigen
        // Kalibrierung, weil `entwurfEinstellung` sonst nie befuellt wird.
        .onAppear { modell.kalibrierungVorbereiten() }
    }
}
