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
    let titel: String
    let hinweis: String
    /// Der zweite Weg, gleichwertig danebengestellt (SS11). Bei "Geraet
    /// finden" der NFC-Satz, beim Beitritt die manuelle Code-Eingabe.
    let nebenweg: String?
    var nebenwegAktion: (() -> Void)? = nil
    let beiCode: (String) -> Void

    @State private var erkannt = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerController(onCode: codeEmpfangen)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                kopf
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

    @ViewBuilder
    private var fuss: some View {
        if let nebenweg {
            VStack(spacing: DesignSystem.Spacing.s8) {
                if let nebenwegAktion {
                    Button(nebenweg) {
                        dismiss()
                        nebenwegAktion()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(minHeight: 44)
                    .buttonStyle(PressButtonStyle())
                } else {
                    // Kein Knopf, sondern ein Hinweis: NFC braucht diesen
                    // Bildschirm gar nicht, es gibt also nichts zu tippen.
                    Text(nebenweg)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.s24)
                }
            }
            .padding(.bottom, DesignSystem.Spacing.s24)
        }
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
