import AVKit
import SwiftUI

/// Schritt 1 von 3.
///
/// Zwei Abweichungen vom Artboard (Spec Abschnitt 9): Der Link heisst nur
/// "Kenne ich schon" und ueberspringt NUR die Einweisung -- uebersprunge er
/// den ganzen Dreischritt, gaebe es weder Kalibrierung noch Startwert, und
/// die Regel "kein Vorschlag beim ersten Mal" haette nichts, worauf sie
/// fallen koennte. Und es gibt eine Variante ohne Video, die als Artboard
/// fehlt: ein Geraet ohne Video ist nutzbar (M1-Spec SS8.2).
struct EinweisungSchritt: View {
    let modell: GeraetModel
    /// Verlaesst den ganzen Dreischritt (Kreuz oben links). Darf NIE
    /// erstkontaktAbschliessen() oder eine Kalibrierung ausloesen -- ohne
    /// gespeicherten Satz bleibt istErstkontakt true, und der Dreischritt
    /// erscheint beim naechsten Mal zu Recht wieder.
    let beiAbbruch: () -> Void
    let beiWeiter: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(modell.maschine.equipmentModel.name.uppercased())
                        .font(DesignSystem.Typography.geraetename)
                        .tracking(-0.8)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(modell.aktiveUebung?.name ?? "")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                medien

                if let beschreibung = modell.kontext?.exercises
                    .first(where: { $0.id == modell.uebungId })?.description {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        Text("Worauf du achten musst")
                            .font(DesignSystem.Typography.uebungsname)
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(beschreibung)
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .lineSpacing(4)
                    }
                }

                Text(modell.produktgrenze)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .lineSpacing(3)

                PrimaryButton(title: "Einstellungen erfassen") { beiWeiter() }

                Button("Kenne ich schon", action: beiWeiter)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
    }

    /// Alle drei Artboards zeigen ein Chevron/Kreuz vor dem Eyebrow-Text in
    /// derselben Zeile (GeraetEinweisung.dc.html Kopfzeile) -- ein
    /// fullScreenCover kennt kein Swipe-to-dismiss, ohne diese Zeile waere
    /// der Dreischritt eine Falle.
    private var kopf: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Button(action: beiAbbruch) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("Schließen")

            Text("SCHRITT 1 VON 3 · EINWEISUNG")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }

    /// Die Variante ohne Video ist kein Fehlerzustand -- ein Geraet ohne
    /// Video ist nutzbar. Nur das Skelett ist hier erlaubt (SS5: Skelette
    /// ausschliesslich fuer Medien), und nur solange der Kontext noch laedt
    /// -- ist er da, ist "kein Video" ein feststehendes Faktum, kein
    /// Ladezustand mehr.
    ///
    /// M1-Spec SS7.3: "Fehlt ein Einweisungsvideo ... ist das kein
    /// Fehlerzustand: der Schritt zeigt Foto und Einstellhinweise ohne
    /// Player." Dasselbe AsyncImage/photoUrl-Muster wie GeraetErkanntView.
    @ViewBuilder
    private var medien: some View {
        if let video = modell.aktiveUebung?.videoURL {
            VideoPlayer(player: AVPlayer(url: video))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        } else if modell.kontext == nil {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .frame(height: 200)
                .overlay(
                    Text("Einweisungsvideo braucht Empfang.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                )
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                geraetefoto
                Text("Für diese Übung hat dein Studio kein Video hinterlegt.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
    }

    private var geraetefoto: some View {
        AsyncImage(url: modell.kontext?.equipmentModel.photoUrl.flatMap(URL.init(string:))) { bild in
            bild.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                DesignSystem.Color.surfaceRaised
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityHidden(true)
    }
}
