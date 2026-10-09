import SwiftUI

/// Schritt 2 des Erstkontakts -- und zugleich der Screen hinter "aendern"
/// auf GeraetView. Genau dieser Fall ausserhalb des Erstkontakts macht den
/// eigenen Endpoint noetig.
///
/// Der Knopf heisst "Einstellung speichern" (Testnotiz 06.10., #18): er
/// speichert die Einstellung, keinen Satz -- beides geht ueber eigene
/// Endpunkte, nichts in der Datenbank verbindet sie.
struct KalibrierungSchritt: View {
    @Bindable var modell: GeraetModel
    let titel: String
    /// Ein Schritt zurueck, nicht "abbrechen" -- zur Einweisung, oder
    /// ausserhalb des Erstkontakts zurueck auf die Satzseite.
    let beiZurueck: () -> Void
    let beiFertig: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf

                Text(modell.station.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)

                Text("Stell das Gerät jetzt so ein, wie es für dich passt. Beim nächsten Mal steht es hier — du musst nicht nachdenken.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(4)

                ForEach(modell.einstellDefinitionen) { definition in
                    // Eine Auswahl (Griffposition: eng / weit / neutral) ist
                    // keine Zahl und bekommt kein Rad (Testnotiz 06.10., #17).
                    if let werte = definition.auswahlwerte {
                        AuswahlKarte(
                            label: definition.label, werte: werte,
                            gewaehlt: Binding(
                                get: { modell.entwurfAuswahl[definition.key] ?? werte[0] },
                                set: { modell.entwurfAuswahl[definition.key] = $0 }
                            )
                        )
                    } else {
                        Stepper44(
                            definition: definition,
                            wert: Binding(
                                get: { modell.entwurfEinstellung[definition.key] ?? definition.minValue ?? 0 },
                                set: { modell.entwurfEinstellung[definition.key] = $0 }
                            )
                        )
                    }
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

                Text("Deine vorherigen Einstellungen bleiben erhalten — jede Änderung legt eine neue Zeile an.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(DesignSystem.Color.bg)
        // Unten buendig wie Einweisung und "Training starten" (Testnotiz
        // 06.10., #6, #15). Der Fehler steht direkt ueber dem Knopf, damit
        // er bei drei Parametern nicht unterhalb des Sichtbaren landet.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignSystem.Spacing.s12) {
                if let fehler = modell.kalibrierungFehler {
                    InlineBanner(tone: .danger, message: fehler)
                }
                PrimaryButton(title: "Einstellung speichern") {
                    if await modell.kalibrierungSichern() { beiFertig() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s8)
            .padding(.bottom, DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.bg)
        }
        // Fuellt den Entwurf bei jedem Eintritt neu -- ob aus dem Dreischritt
        // (Aufgabe 13) oder ueber "aendern" auf GeraetView (Aufgabe 12). Ohne
        // das startete das Rad immer am Minimum statt an der bisherigen
        // Kalibrierung, weil `entwurfEinstellung` sonst nie befuellt wird.
        .onAppear { modell.kalibrierungVorbereiten() }
        .testnotizScreen()
    }

    private var kopf: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Button(action: beiZurueck) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("Zurück")

            Text(titel.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }
}

/// Ein Auswahl-Parameter der Kalibrierung: Label und je erlaubtem Wert ein
/// Chip, auf derselben surface-Karte wie `Stepper44`. Chips statt Menue,
/// weil die Listen der Studios kurz sind und ein Blick genuegen soll.
private struct AuswahlKarte: View {
    let label: String
    let werte: [String]
    @Binding var gewaehlt: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(label)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: DesignSystem.Spacing.s8)],
                      spacing: DesignSystem.Spacing.s8) {
                ForEach(werte, id: \.self) { wert in
                    Button { gewaehlt = wert } label: {
                        Chip(text: wert, isActive: wert == gewaehlt)
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityAddTraits(wert == gewaehlt ? .isSelected : [])
                }
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
