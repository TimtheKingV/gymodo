import SwiftUI

/// Die Scanwege zum Geraet (SS11): QR-Code und NFC nebeneinander, unten
/// ueber der Geraeteliste des Training-Tabs schwebend.
///
/// Seit der Testnotiz 06.10. (#2, #13) ist die Liste "Gerät wählen" selbst
/// der Training-Tab -- einen eigenen Knopf "Suchen" gibt es nicht mehr, die
/// Suche sitzt in der Leiste. Die beiden Scanwege tragen dafuer die
/// Signalfarbe als Flaeche und einen Schatten: sie sind die Hauptaktion des
/// Screens und muessen sich von der Liste darunter abheben, ueber der sie
/// liegen (designsystem.md SS2, eine Akzentflaeche je Screen -- hier eine
/// Gruppe aus zwei gleichrangigen Wegen).
struct ScanWege: View {
    let beiQR: () -> Void
    let beiNFC: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            ScanKnopf(symbol: "qrcode", titel: "QR-Code", aktion: beiQR)
            // Auf iPads, aelteren iPhones und im Simulator gibt es keinen
            // aktiven NFC-Scan. Dann steht der QR-Weg allein da, statt dass
            // ein Knopf ins Leere greift -- der passive Weg ueber das
            // Systembanner bleibt davon unberuehrt.
            if NFCTagLeser.verfuegbar {
                ScanKnopf(symbol: "wave.3.right", titel: "NFC", aktion: beiNFC)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 56 pt hoch, Radius.haupt, Akzentflaeche mit Schatten.
private struct ScanKnopf: View {
    let symbol: String
    let titel: String
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
            .foregroundStyle(DesignSystem.Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(DesignSystem.Color.accent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            // Schwarz statt Akzent: ein gruener Schein laese sich wie ein
            // Fokus- oder Aktivzustand.
            .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
        }
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    ScanWege(beiQR: {}, beiNFC: {})
        .padding()
        .background(DesignSystem.Color.bg)
}
