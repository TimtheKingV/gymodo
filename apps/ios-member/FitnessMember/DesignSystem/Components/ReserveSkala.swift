import SwiftUI

/// Die Reserve-Frage am Ende einer Uebung (Trainingsplan-Spec Abschnitt 6).
/// Sechs Chips und "Weiss nicht" -- keine Pflicht: die Knoepfe darunter
/// warten auf nichts, wer nicht antwortet, laesst die Reserve unbekannt.
///
/// Chips statt Rad: eine Zahl aus sechs ist ein Tipp, kein Drehen, und der
/// Screen hat an dieser Stelle ohnehin nur noch eine Entscheidung offen.
struct ReserveSkala: View {
    let auswahl: Reserve?
    /// Einmalig beim allerersten Erscheinen: was mit "noch drin" gemeint ist.
    let mitErklaerung: Bool
    let aendern: (Reserve) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("Wie viele Wiederholungen wären im letzten Satz noch drin gewesen?")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
            if mitErklaerung {
                Text("Gemeint sind saubere Wiederholungen mit demselben Gewicht, ohne Pause.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(Reserve.werte, id: \.self) { zahl in
                    let gewaehlt = auswahl == .wert(zahl)
                    Button { aendern(.wert(zahl)) } label: {
                        Chip(text: zahl == 5 ? "5+" : "\(zahl)", isActive: gewaehlt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reserve \(zahl == 5 ? "5 oder mehr" : "\(zahl)") Wiederholungen")
                    .accessibilityAddTraits(gewaehlt ? .isSelected : [])
                }
            }
            Button { aendern(.unbekannt) } label: {
                Text("Weiß nicht")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(auswahl == .unbekannt ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                    .underline(auswahl == .unbekannt)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(auswahl == .unbekannt ? .isSelected : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ReserveSkala(auswahl: .wert(2), mitErklaerung: true) { _ in }
        .padding()
        .background(DesignSystem.Color.bg)
}
