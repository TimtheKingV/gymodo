import SwiftUI

/// Ein Sheet fuer beide Scan-Wege: Studio beitreten und Geraet finden.
///
/// Die Kamera-, Erkennungs- und Schliessmechanik ist dieselbe; nur der Text
/// unterscheidet sich. Zwei Sheets haetten geheissen, dass die Maengel aus
/// der Design-Challenge zweimal behoben werden -- oder nur einmal. Der
/// Beitritts-Scan steht im selben schummrigen Keller wie der Geraete-Scan.
///
/// Das Sheet erkennt einen Code und reicht ihn weiter, mehr nicht. Ob ein
/// Tag unbekannt, ungueltig oder gesperrt ist, entscheidet der Weg dahinter
/// -- und antwortet dort fuer alle drei gleich (M1-Spec SS10.4). Ein eigener
/// Fehlerzustand hier wuerde genau die Unterscheidung wieder einfuehren,
/// die der Server bewusst vermeidet.
struct ScannerSheet: View {
    /// Der zweite Weg, gleichwertig danebengestellt (SS11) -- nie eine
    /// kleinere zweite Wahl. Ein Knopf beim Beitritt (Code manuell
    /// eingeben), eine Karte mit Icon bei "Geraet finden" (NFC).
    enum Nebenweg {
        case knopf(titel: String, aktion: () -> Void)
        /// Die NFC-Karte. Bis M1 war sie reine Beschriftung -- sie verwies
        /// aufs Systembanner von iOS, das man erst antippen muss. Jetzt
        /// startet sie den Scan selbst und liefert ihr Ergebnis durch
        /// dieselbe Annahme wie die Kamera.
        case nfc(titel: String, text: String)
    }

    let titel: String
    let hinweis: String
    let nebenweg: Nebenweg?
    let beiCode: (String) -> Void

    @State private var erkannt = false
    @State private var nfcLeser = NFCTagLeser()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerController(onCode: codeEmpfangen)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                kopf
                Spacer()
                rahmen
                Spacer()
                if erkannt { bestaetigung } else { fuss }
            }
        }
        .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: erkannt)
        .sensoryFeedback(.success, trigger: erkannt)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(DesignSystem.Radius.haupt)
    }

    private var kopf: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            Capsule()
                .fill(DesignSystem.Color.line)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Text(titel.uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(DesignSystem.Color.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("Schließen")
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)

            Text(hinweis)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
        }
    }

    /// Der Sucher-Rahmen: sagt dem Mitglied, wohin der Aufkleber gehoert --
    /// tragend, nicht Zierde (Nachtrag zur Design-Challenge). Werte aus
    /// TrainingScan.dc.html Zeilen 34-42, fuer beide Scan-Wege gleich.
    ///
    /// Reine Dekoration im Bedienungssinn: keine Trefferflaeche, fuer
    /// VoiceOver ausgeblendet, damit er sich nicht zwischen Titel und
    /// Hinweis schiebt. Die Suchlinie bleibt statisch -- das Artboard zeigt
    /// sie so, und statisch gibt es nichts, was Reduce Motion wegnehmen
    /// muesste.
    private var rahmen: some View {
        ZStack {
            winkel(grad: 0).frame(width: 236, height: 236, alignment: .topLeading)
            winkel(grad: 90).frame(width: 236, height: 236, alignment: .topTrailing)
            winkel(grad: 180).frame(width: 236, height: 236, alignment: .bottomTrailing)
            winkel(grad: 270).frame(width: 236, height: 236, alignment: .bottomLeading)

            Rectangle()
                .fill(DesignSystem.Color.accent.opacity(0.55))
                .frame(height: 2)
                .padding(.horizontal, 12)
        }
        .frame(width: 236, height: 236)
        .accessibilityHidden(true)
    }

    /// Eine Ecke des Sucher-Rahmens, oben links konstruiert; die anderen
    /// drei sind dieselbe Form, im Uhrzeigersinn gedreht.
    private func winkel(grad: Double) -> some View {
        EckenWinkel()
            .stroke(DesignSystem.Color.accent, lineWidth: 3)
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(grad))
    }

    @ViewBuilder
    private var fuss: some View {
        switch nebenweg {
        case .knopf(let text, let aktion):
            // .frame(minHeight: 44) INNERHALB des Labels: aussen
            // zentriert der Button bloss seinen Inhalt in einem 44pt
            // hohen Kasten, waehrend die Trefferflaeche die Glyphenhoehe
            // der Schrift behaelt. Dieser Knopf ist der gleichwertig
            // danebengestellte zweite Weg (SS11) -- er darf nicht stumm
            // danebengreifen lassen.
            Button {
                dismiss()
                aktion()
            } label: {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .padding(.bottom, DesignSystem.Spacing.s24)

        case .nfc(let titel, let text):
            nfcWeg(titel: titel, text: text)
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s24)

        case nil:
            EmptyView()
        }
    }

    /// Die NFC-Karte, jetzt tippbar: sie startet den aktiven Scan. Wo es
    /// keinen gibt (iPad, aelteres iPhone, Simulator), bleibt sie die reine
    /// Beschriftung, die sie vorher ueberall war -- der passive Weg ueber
    /// das Systembanner funktioniert dort weiterhin.
    @ViewBuilder
    private func nfcWeg(titel: String, text: String) -> some View {
        if NFCTagLeser.verfuegbar {
            Button {
                nfcLeser.starten { roh in codeEmpfangen(roh) }
            } label: {
                nfcKarte(titel: titel, text: nfcLeser.fehler ?? text)
                    .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            }
            .buttonStyle(PressButtonStyle())
        } else {
            nfcKarte(titel: titel, text: text)
        }
    }

    /// Die Karte selbst. Werte aus TrainingScan.dc.html Zeilen 50-58.
    private func nfcKarte(titel: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            ZStack {
                Circle().stroke(DesignSystem.Color.line, lineWidth: 1)
                Image(systemName: "wave.3.right")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Color.accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(titel)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        // Ohne das liest VoiceOver Symbol, Titel und Text als drei
        // zusammenhanglose Fetzen. Die Karte enthaelt keinen Knopf, das
        // Zusammenfassen nimmt also nichts Bedienbares weg.
        .accessibilityElement(children: .combine)
    }

    /// Sichtbare Bestaetigung, nicht nur haptische (SS6). Die
    /// Design-Challenge fand, dass nach dem Scan gar nichts passierte.
    private var bestaetigung: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "checkmark")
            Text("Erkannt")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(DesignSystem.Color.onAccent)
        .padding(.horizontal, DesignSystem.Spacing.s24)
        .frame(height: 44)
        .background(DesignSystem.Color.accent)
        .clipShape(Capsule())
        .padding(.bottom, DesignSystem.Spacing.s48)
        .accessibilityElement(children: .combine)
    }

    /// QRScannerController feuert je Bild; ohne die Sperre liefe der
    /// Aufrufer mehrfach an, waehrend die Bestaetigung noch steht.
    private func codeEmpfangen(_ code: String) {
        guard !erkannt else { return }
        erkannt = true
        beiCode(code)
    }
}

/// Eine Ecke des Sucher-Rahmens: 34 pt Kantenlaenge, Aussenecke mit
/// DesignSystem.Radius.neben (14 pt) gerundet -- ueber addArc(tangent1End:
/// tangent2End:radius:) konstruiert, damit keine Vorzeichenfehler bei den
/// Bogenwinkeln entstehen koennen.
private struct EckenWinkel: Shape {
    func path(in rect: CGRect) -> Path {
        var pfad = Path()
        let untenLinks = CGPoint(x: rect.minX, y: rect.maxY)
        let obenLinks = CGPoint(x: rect.minX, y: rect.minY)
        let obenRechts = CGPoint(x: rect.maxX, y: rect.minY)
        pfad.move(to: untenLinks)
        pfad.addArc(tangent1End: obenLinks, tangent2End: obenRechts, radius: DesignSystem.Radius.neben)
        pfad.addLine(to: obenRechts)
        return pfad
    }
}
