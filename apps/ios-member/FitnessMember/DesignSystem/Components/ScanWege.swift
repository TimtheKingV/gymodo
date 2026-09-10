import SwiftUI

/// Die drei Wege zum Geraet, gleichwertig uebereinander (SS11).
///
/// Bis zur Geraeteauswahl ohne Scan waren es zwei, und beide setzten
/// voraus, dass am Geraet ein AKTIVER Aufkleber klebt. Fehlt er, gab es
/// keinen Weg -- der dritte schliesst diese Luecke.
///
/// Alle drei sind Kontur, keiner ist Akzentflaeche: gleichwertig heisst
/// gleich aussehend, und die eine Akzentflaeche pro Screen bleibt frei
/// (designsystem.md SS2).
struct ScanWege: View {
    let beiQR: () -> Void
    let beiNFC: () -> Void
    /// Optional: ohne geladenen Prefetch gibt es nichts zu waehlen, und
    /// ein Knopf, der auf einen leeren Screen fuehrt, ist schlechter als
    /// einer, der fehlt.
    let beiListe: (() -> Void)?

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
            if let beiListe {
                KonturScanKnopf(symbol: "list.bullet", titel: "Aus der Liste wählen", aktion: beiListe)
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
    ScanWege(beiQR: {}, beiNFC: {}, beiListe: {})
        .padding()
        .background(DesignSystem.Color.bg)
}
