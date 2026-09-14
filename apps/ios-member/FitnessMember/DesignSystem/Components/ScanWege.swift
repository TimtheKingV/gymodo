import SwiftUI

/// Die Wege zum Geraet (SS11): die beiden Scanwege nebeneinander in einer
/// Zeile, die Suche darunter.
///
/// Bis zur Geraeteauswahl ohne Scan waren es zwei, und beide setzten
/// voraus, dass am Geraet ein AKTIVER Aufkleber klebt. Fehlt er, gab es
/// keinen Weg -- der dritte schliesst diese Luecke.
///
/// Scannen und Antippen sind dasselbe Mittel am selben Aufkleber, deshalb
/// stehen sie in einer Zeile und tragen als einzige die Akzentfarbe in
/// Kontur und Schrift. Die Suche darunter ist der andere Weg -- gleich
/// erreichbar, aber nicht dasselbe, und deshalb neutrale Kontur. Keiner
/// der drei ist Akzentflaeche: die eine Akzentflaeche pro Screen bleibt
/// frei (designsystem.md SS2).
struct ScanWege: View {
    let beiQR: () -> Void
    let beiNFC: () -> Void
    /// Optional: ohne geladenen Prefetch gibt es nichts zu waehlen, und
    /// ein Knopf, der auf einen leeren Screen fuehrt, ist schlechter als
    /// einer, der fehlt.
    let beiListe: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                KonturScanKnopf(symbol: "qrcode", titel: "QR-Code", farbe: .akzent, aktion: beiQR)
                // Auf iPads, aelteren iPhones und im Simulator gibt es keinen
                // aktiven NFC-Scan. Dann steht der QR-Weg allein da, statt dass
                // ein Knopf ins Leere greift -- der passive Weg ueber das
                // Systembanner bleibt davon unberuehrt.
                if NFCTagLeser.verfuegbar {
                    KonturScanKnopf(symbol: "wave.3.right", titel: "NFC", farbe: .akzent, aktion: beiNFC)
                }
            }
            if let beiListe {
                KonturScanKnopf(symbol: "magnifyingglass", titel: "Suchen", farbe: .neutral, aktion: beiListe)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Die gemeinsame Form aller Wege. Werte aus der frueheren qrReihe in
/// TrainingRootView: 60pt hoch, Radius.haupt, Kontur 1pt.
private struct KonturScanKnopf: View {
    enum Farbe {
        case akzent
        case neutral

        var kontur: Color {
            switch self {
            case .akzent: DesignSystem.Color.accent
            case .neutral: DesignSystem.Color.line
            }
        }

        var schrift: Color {
            switch self {
            case .akzent: DesignSystem.Color.accent
            case .neutral: DesignSystem.Color.text
            }
        }
    }

    let symbol: String
    let titel: String
    let farbe: Farbe
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(titel)
                    .font(.system(size: 17, weight: .bold))
                    // Zu zweit in einer Zeile ist die Breite geteilt: lieber
                    // eine Spur enger gesetzt als abgeschnitten.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(farbe.schrift)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                .stroke(farbe.kontur, lineWidth: 1)
        )
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    ScanWege(beiQR: {}, beiNFC: {}, beiListe: {})
        .padding()
        .background(DesignSystem.Color.bg)
}
