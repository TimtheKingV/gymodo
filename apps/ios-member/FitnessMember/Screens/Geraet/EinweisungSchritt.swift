import SwiftUI

/// Schritt 1 des Erstkontakts.
///
/// "Kenne ich schon" ueberspringt Einweisung UND Einstellung (Testnotiz
/// 06.10., #16). Vorher uebersprang er nur die Einweisung und tat damit
/// genau dasselbe wie die Hauptaktion. Die Einstellung laesst sich spaeter
/// auf der Satzseite ueber "aendern" nachtragen; ohne sie bleibt der Erstkontakt
/// bis zum ersten Satz offen, und "kein Vorschlag beim ersten Mal" gilt
/// weiter, weil es keine Historie gibt. Es gibt eine Variante ohne Video,
/// die als Artboard fehlt: ein Geraet ohne Video ist nutzbar (M1-Spec SS8.2).
struct EinweisungSchritt: View {
    @Environment(UebungsVideoVorrat.self) private var vorrat
    /// Nur fuer das Geschlecht aus dem gespeicherten Bootstrap -- kein
    /// Netzaufruf, die Karte bleibt offline gleich.
    @Environment(CatalogStore.self) private var katalog
    let modell: GeraetModel
    let titel: String
    /// "Einstellungen erfassen", ohne Einstellparameter "Weiter".
    let hauptaktion: String
    /// Verlaesst den ganzen Erstkontakt (Kreuz oben links). Darf NIE
    /// erstkontaktAbschliessen() oder eine Kalibrierung ausloesen -- ohne
    /// gespeicherten Satz bleibt istErstkontakt true, und der Erstkontakt
    /// erscheint beim naechsten Mal zu Recht wieder.
    let beiAbbruch: () -> Void
    let beiWeiter: () -> Void
    /// nil, wenn es nichts zu ueberspringen gibt (kein Einstellschritt).
    let beiUeberspringen: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(modell.station.equipmentModel.name.uppercased())
                        .font(DesignSystem.Typography.geraetename)
                        .tracking(-0.8)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(modell.aktiveUebung?.name ?? "")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                medien

                MuskelKarte(
                    muskeln: modell.muskeln,
                    geschlecht: katalog.bootstrap?.member.sex.flatMap(Geschlecht.init(rawValue:)))

                if let beschreibung = modell.beschreibung {
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(DesignSystem.Color.bg)
        // Die 428-KB-Geometrie wird beim ersten Zugriff synchron dekodiert
        // (~0,13 s Debug). Abseits des Main-Threads vorwaermen, damit das
        // erste Zeichnen der Karte nicht ruckelt; `geometrie` ist eine
        // nonisolated static let und damit thread-sicher initialisiert.
        .task(priority: .utility) {
            guard !modell.muskeln.isEmpty else { return }
            await Task.detached(priority: .utility) { _ = MuskelModell.geometrie }.value
        }
        // Unten buendig in der Daumenzone, wie auf "Training starten"
        // (Testnotiz 06.10., #15). Vorher standen beide Knoepfe direkt
        // unter dem Text, auf grossen iPhones mitten auf dem Screen.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignSystem.Spacing.s4) {
                PrimaryButton(title: hauptaktion) { beiWeiter() }
                if let beiUeberspringen {
                    Button(action: beiUeberspringen) {
                        Text("Kenne ich schon")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .buttonStyle(PressButtonStyle())
                    .accessibilityHint("Überspringt Einweisung und Einstellung")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s8)
            .padding(.bottom, DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.bg)
        }
        .testnotizScreen()
    }

    /// Alle drei Artboards zeigen ein Chevron/Kreuz vor dem Eyebrow-Text in
    /// derselben Zeile (GeraetEinweisung.dc.html Kopfzeile) -- ein
    /// fullScreenCover kennt kein Swipe-to-dismiss, ohne diese Zeile waere
    /// der Erstkontakt eine Falle.
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

            Text(titel.uppercased())
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
    ///
    /// Offline läuft das Video aus der Ablage (Offline-Spec 3c).
    @ViewBuilder
    private var medien: some View {
        let video = modell.aktiveUebung?.videoURL
        if EinweisungMedien.zeigtVideokachel(kontextGeladen: modell.kontext != nil,
                                             kontextVideo: video,
                                             vorratKennt: vorrat.quellen[modell.uebungId] != nil) {
            // Stumm in Schleife und sofort, ohne Tipp auf Play (Testnotiz
            // 11.10., #7). Ohne URL findet die Kachel die zuletzt abgelegte
            // Datei; der Hinweis liegt darunter und bleibt nur sichtbar,
            // wenn keine da ist.
            UebungsVideoKachel(exerciseId: modell.uebungId, hoehe: 200, ersatz: video) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .fill(DesignSystem.Color.surfaceRaised)
                    .overlay {
                        if modell.kontext == nil {
                            Text("Einweisungsvideo braucht Empfang.")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignSystem.Color.textFaint)
                        }
                    }
            }
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
        Geraetefoto(modellId: modell.station.equipmentModelId, url: modell.kontext?.equipmentModel.photoUrl.flatMap(URL.init(string:)), hoehe: 200)
    }
}
