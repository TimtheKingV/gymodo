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
    /// Nur Chips und "Weiss nicht", ohne Frage: wo mehrere Skalen unter
    /// einer gemeinsamen Frage stehen (Zirkel-Uebersicht, je Station).
    var kompakt: Bool = false
    let aendern: (Reserve) -> Void

    static let frage = "Wie viele Wiederholungen wären im letzten Satz noch drin gewesen?"
    static let erklaerung = "Gemeint sind saubere Wiederholungen mit demselben Gewicht, ohne Pause."

    init(auswahl: Reserve?, mitErklaerung: Bool, kompakt: Bool = false, aendern: @escaping (Reserve) -> Void) {
        self.auswahl = auswahl
        self.mitErklaerung = mitErklaerung
        self.kompakt = kompakt
        self.aendern = aendern
    }

    var body: some View {
        VStack(alignment: .leading, spacing: kompakt ? DesignSystem.Spacing.s4 : DesignSystem.Spacing.s12) {
            if !kompakt {
                Text(Self.frage)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if mitErklaerung && !kompakt {
                Text(Self.erklaerung)
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
