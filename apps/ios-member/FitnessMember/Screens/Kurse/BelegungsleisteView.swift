import SwiftUI

/// Die Belegung als Reihe von Plaetzen -- ein Segment je Platz, belegte
/// eingefaerbt (`Belegungsleiste` traegt die Regeln und ihre Begruendung).
///
/// Immer zusammen mit der Zahl, nie an ihrer Stelle: die Leiste ist fuer
/// den Blick, die Zahl fuer die Gewissheit und fuer VoiceOver. Deshalb ist
/// die Leiste selbst `accessibilityHidden` -- sie wiederholte sonst als
/// "Grafik" nur, was die Zahl daneben schon sagt.
struct BelegungsleisteView: View {
    let belegt: Int
    let kapazitaet: Int
    var breite: CGFloat = 132
    /// In der angemeldeten Zeile ist Grün schon vergeben ("das ist
    /// deiner"). Der Aufrufer kann die Leiste dort zuruecknehmen, ohne
    /// dass diese View davon wissen muss.
    var farbe: Color = DesignSystem.Color.accent

    @ViewBuilder
    var body: some View {
        if Belegungsleiste.zeigtLeiste(kapazitaet: kapazitaet) {
            let gefuellt = Belegungsleiste.belegteSegmente(belegt: belegt, kapazitaet: kapazitaet)
            HStack(spacing: Belegungsleiste.segmentAbstand(kapazitaet: kapazitaet)) {
                ForEach(0..<kapazitaet, id: \.self) { platz in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(platz < gefuellt ? farbe : DesignSystem.Color.line)
                }
            }
            .frame(width: breite, height: 7)
            .accessibilityHidden(true)
        }
    }
}

/// Leiste plus Zahl -- die Form, in der die Belegung im Tagesplan steht.
struct BelegungZeile: View {
    let belegt: Int
    let kapazitaet: Int
    var farbe: Color = DesignSystem.Color.accent

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            BelegungsleisteView(belegt: belegt, kapazitaet: kapazitaet, farbe: farbe)
            // textMuted statt textFaint: die Zahl ist bei 11pt tragend
            // (designsystem.md SS2 laesst textFaint erst ab 15pt zu).
            Text("\(belegt) von \(kapazitaet)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }
}

#Preview("Kapazitäten") {
    VStack(alignment: .leading, spacing: 16) {
        // Die Reihe, an der sich der Entwurf entscheidet: bis hierhin
        // bleibt ein Segment breiter als der Spalt daneben.
        BelegungZeile(belegt: 5, kapazitaet: 8)
        BelegungZeile(belegt: 5, kapazitaet: 11)
        BelegungZeile(belegt: 12, kapazitaet: 16)
        BelegungZeile(belegt: 6, kapazitaet: 20)
        BelegungZeile(belegt: 24, kapazitaet: 30)
        BelegungZeile(belegt: 31, kapazitaet: 40)
        // Darueber bleibt nur die Zahl -- die Leiste faellt weg, ohne
        // dass die Zeile ihre Aussage verliert.
        BelegungZeile(belegt: 31, kapazitaet: 60)
        // Voll: alle Segmente gefaerbt. Die Zahl daneben ist das, was
        // "keine Plaetze mehr" tatsaechlich sagt.
        BelegungZeile(belegt: 20, kapazitaet: 20)
        // In der eigenen Zeile bleibt die Leiste gedeckt, weil Gruen dort
        // schon "das ist deiner" heisst.
        BelegungZeile(belegt: 12, kapazitaet: 16, farbe: DesignSystem.Color.textMuted)
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
