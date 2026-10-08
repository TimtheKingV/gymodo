import SwiftUI

/// "Training starten" -- der Screen zwischen Uebungswahl und Satzpfad, nur
/// ohne laufendes Training (TrainingStart.ziel). Mit dem Tap unten entsteht
/// die Einheit und die Uhr laeuft (Sammelstelle Punkt 10, entschieden
/// 15. September; hebt M1-Spec SS5.6 "es gibt keinen Startknopf" auf).
///
/// Kein Geraetefoto: es steht auf "Geraet erkannt" davor, und hier kostete
/// es 204 pt von 510 auf einem 667-pt-iPhone (Plan Schnitt 4, Task 3).
/// Kein Rueckblick, kein Vorschlag, keine Raeder: die gehoeren zum
/// Satzpfad, und "die App misst nichts" beginnt erst mit einem Satz.
///
/// Seit der Testnotiz 06.10. (#5) auch der letzte Schritt des
/// Erstkontakts: dort steht er im fullScreenCover ohne Navigationsleiste
/// und bringt deshalb seinen eigenen Zurueck-Pfeil mit Schrittzeile mit.
struct TrainingStartView: View {
    let modell: GeraetModel
    /// "Schritt 3 von 3 · Training starten" im Erstkontakt, sonst nil.
    var titel: String? = nil
    /// Nur im Erstkontakt: ein Schritt zurueck zur Einstellung.
    var beiZurueck: (() -> Void)? = nil
    let beiStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let titel, let beiZurueck {
                    schrittkopf(titel: titel, beiZurueck: beiZurueck)
                        .padding(.bottom, DesignSystem.Spacing.s16)
                }
                kopfzeile
                geraetUndUebung
                    .padding(.top, DesignSystem.Spacing.s8)
                erklaerung
                    .padding(.top, DesignSystem.Spacing.s24)
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
        }
        // Der Inhalt ist 243 pt hoch, das kleinste iPhone laesst 510: die
        // Seite soll nicht federn wie eine, die mehr zu zeigen haette.
        .scrollBounceBehavior(.basedOnSize)
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            // Die eine Akzentflaeche des Screens (designsystem.md SS2), 64 pt
            // (SS4). Nie deaktiviert: sie haengt an nichts, was vom Netz
            // kommen koennte.
            PrimaryButton(title: "Training starten") { beiStart() }
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s24)
                .background(DesignSystem.Color.bg)
                .testnotizElement("training.starten", typ: "PrimaryButton")
        }
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["station": modell.station.schluessel, "exerciseId": modell.uebungId])
    }

    /// Dieselbe Zeile wie auf "Geraet erkannt": wer ueber den Scan kommt,
    /// sieht "ERKANNT", wer ueber die Liste kommt, "AUSGEWAEHLT" -- die App
    /// weiss im zweiten Fall nicht, wo das Mitglied steht (designsystem.md
    /// SS10).
    private var kopfzeile: some View {
        HStack {
            Text(modell.ortsangabe.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer()
            Label(modell.einstiegsart.beschriftung, systemImage: modell.einstiegsart.symbol)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Wie die Kopfzeile der anderen Erstkontakt-Schritte: Pfeil und
    /// Schrittzeile in einer Zeile.
    private func schrittkopf(titel: String, beiZurueck: @escaping () -> Void) -> some View {
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

    private var geraetUndUebung: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            // Schrumpfen statt kuerzen, wie im Satzpfad (Schnitt 3): ein
            // abgeschnittener Name sagt nicht, an welchem Geraet man steht.
            Text(modell.station.equipmentModel.name.uppercased())
                .font(DesignSystem.Typography.geraetename)
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(DesignSystem.Color.text)
            Text(modell.aktiveUebung?.name ?? "")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Sagt, was der Tap tut und was ohne Satz passiert -- der eine Ort,
    /// an dem das Mitglied die Regel aus Entschieden 2 zu lesen bekommt.
    /// Kein textFaint: das ist tragende Information (designsystem.md SS2).
    private var erklaerung: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("WAS JETZT PASSIERT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            // Ohne "auch waehrend Einweisung und Einstellung": die kommen seit
            // der Testnotiz 06.10. (#5) vor diesem Screen, nicht danach.
            Text("Mit „Training starten“ läuft die Uhr. Sicherst du keinen Satz, wird das Training verworfen und taucht nirgends auf.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .lineSpacing(3)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // Ein gesprochener Satz statt zweier Bruchstuecke; kein
        // Bedienelement darin, das dabei verschwinden koennte.
        .accessibilityElement(children: .combine)
    }
}
