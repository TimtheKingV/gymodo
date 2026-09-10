import SwiftUI

/// Die zwei Wege zum Geraet, gleichwertig uebereinander (SS11).
///
/// Bis M1 stand hier nur eine QR-Zeile, und NFC war eine Zeichnung mit dem
/// Satz "halt dein iPhone an den Aufkleber" -- also gar kein Knopf, sondern
/// ein Verweis auf das Systembanner von iOS. Beim Geraetetest hiess das:
/// Handy an den Tag halten, dann oben noch aufs Banner tippen. Zwei
/// Schritte fuer den Weg, der eigentlich der schnellere sein sollte.
///
/// Beide Knoepfe sind Kontur, keiner ist Akzentflaeche: gleichwertig heisst
/// gleich aussehend, und die eine Akzentflaeche pro Screen bleibt frei
/// (designsystem.md SS2).
struct ScanWege: View {
    let beiQR: () -> Void
    let beiNFC: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            KonturScanKnopf(symbol: "qrcode", titel: "QR-Code scannen", aktion: beiQR)
            // Auf iPads, aelteren iPhones und im Simulator gibt es keinen
            // aktiven NFC-Scan. Dann steht der QR-Weg allein da, statt dass
            // ein Knopf ins Leere greift -- der passive Weg ueber das
            // Systembanner bleibt davon unberuehrt.
            if NFCTagLeser.verfuegbar {
                KonturScanKnopf(symbol: "wave.3.right", titel: "NFC-Tag scannen", aktion: beiNFC)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Die gemeinsame Form beider Wege. Werte aus der frueheren qrReihe in
/// TrainingRootView: 60pt hoch, Radius.haupt, Kontur in Color.line.
private struct KonturScanKnopf: View {
    let symbol: String
    let titel: String
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(titel)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(DesignSystem.Color.text)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    ScanWege(beiQR: {}, beiNFC: {})
        .padding()
        .background(DesignSystem.Color.bg)
}
