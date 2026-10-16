import SwiftUI

/// Kleiner Pillen-Schalter "Muskel | Zuletzt" neben der Listenueberschrift.
/// Die Wahl liegt in den Einstellungen und gilt an allen Stellen, die eine
/// Uebungsliste zeigen.
struct UebungsAnsichtSchalter: View {
    @Binding var ansicht: Uebungsansicht

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(Uebungsansicht.allCases, id: \.self) { fall in
                let aktiv = fall == ansicht
                Button {
                    withAnimation(DesignSystem.Motion.press) { ansicht = fall }
                } label: {
                    Text(fall.titel)
                        .font(.system(size: 12, weight: aktiv ? .semibold : .regular))
                        .foregroundStyle(aktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(aktiv ? DesignSystem.Color.text : Color.clear)
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

/// Die Uebungsliste in der gewaehlten Ansicht. Die Zeile zeichnet der
/// Aufrufer; hier entscheidet sich nur, ob und wie gruppiert wird.
struct UebungsAbschnitte<Zeile: View>: View {
    /// Schon in der "Zuletzt"-Reihenfolge.
    let uebungen: [GeraetUebung]
    let ansicht: Uebungsansicht
    @ViewBuilder let zeile: (GeraetUebung) -> Zeile

    var body: some View {
        if ansicht == .muskel && UebungsGruppierung.bietetSchalterAn(uebungsanzahl: uebungen.count) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                ForEach(UebungsGruppierung.gruppieren(uebungen), id: \.gruppe) { abschnitt in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
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
            VStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(uebungen) { zeile($0) }
            }
        }
    }
}
