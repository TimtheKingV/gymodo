import SwiftUI

/// Eine Reihe kleiner Schalter, linksbündig; der gewählte in der
/// Akzentfarbe. Fuer "Übungen | Geräte", "Muskel | Zuletzt" und die
/// Muskelfilter -- bei vielen Eintraegen scrollt sie waagerecht.
struct PillenLeiste<Wert: Hashable>: View {
    let werte: [Wert]
    @Binding var auswahl: Wert
    let titel: (Wert) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(werte, id: \.self) { wert in
                    let aktiv = wert == auswahl
                    Button {
                        withAnimation(DesignSystem.Motion.press) { auswahl = wert }
                    } label: {
                        Text(titel(wert))
                            .font(.system(size: 13, weight: aktiv ? .bold : .medium))
                            .foregroundStyle(aktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(aktiv ? DesignSystem.Color.accent : Color.clear)
                            .overlay(Capsule().stroke(aktiv ? Color.clear : DesignSystem.Color.line, lineWidth: 1))
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(aktiv ? .isSelected : [])
                }
            }
        }
    }
}

/// Die Uebungsliste, flach oder in Gruppen. Die Zeile zeichnet der
/// Aufrufer; hier entscheidet sich nur, wie gruppiert wird.
struct UebungsAbschnitte<Zeile: View>: View {
    /// Schon in der "Zuletzt"-Reihenfolge.
    let uebungen: [GeraetUebung]
    let gruppiert: Bool
    /// Nur diese Gruppe; nil = alle. Wirkt nur mit `gruppiert`.
    var filter: MuskelHauptgruppe? = nil
    @ViewBuilder let zeile: (GeraetUebung) -> Zeile

    var body: some View {
        if gruppiert {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                ForEach(UebungsGruppierung.gruppieren(uebungen, nur: filter), id: \.gruppe) { abschnitt in
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        Text(abschnitt.gruppe.titel.uppercased())
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textFaint)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(abschnitt.uebungen) { zeile($0) }
                    }
                }
            }
        } else {
            LazyVStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(uebungen) { zeile($0) }
            }
        }
    }
}
