import SwiftUI

/// Ein kleiner Schalter in Pillenform; der gewaehlte in der Akzentfarbe.
struct Pille: View {
    let titel: String
    let aktiv: Bool
    let aktion: () -> Void

    var body: some View {
        Button {
            withAnimation(DesignSystem.Motion.press) { aktion() }
        } label: {
            Text(titel)
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

/// Eine Reihe Pillen, linksbuendig.
struct PillenLeiste<Wert: Hashable>: View {
    let werte: [Wert]
    @Binding var auswahl: Wert
    let titel: (Wert) -> String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(werte, id: \.self) { wert in
                Pille(titel: titel(wert), aktiv: wert == auswahl) { auswahl = wert }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Zwei Seiten in voller Breite, die gewaehlte in der Akzentfarbe -- der
/// uebergeordnete Schalter "Übungen | Geräte".
struct SegmentSchalter<Wert: Hashable>: View {
    let werte: [Wert]
    @Binding var auswahl: Wert
    let titel: (Wert) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(werte, id: \.self) { wert in
                let aktiv = wert == auswahl
                Button {
                    withAnimation(DesignSystem.Motion.press) { auswahl = wert }
                } label: {
                    Text(titel(wert))
                        .font(.system(size: 14, weight: aktiv ? .bold : .medium))
                        .foregroundStyle(aktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(aktiv ? DesignSystem.Color.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(aktiv ? .isSelected : [])
            }
        }
        .padding(3)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

/// Der Streifen: Alle, Zuletzt, Trenner, dann die Muskelgruppen. Scrollt
/// waagerecht, wenn er nicht passt.
struct UebungsFilterLeiste: View {
    let gruppen: [MuskelHauptgruppe]
    @Binding var auswahl: Uebungsfilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Pille(titel: Uebungsfilter.alle.titel, aktiv: auswahl == .alle) { auswahl = .alle }
                Pille(titel: Uebungsfilter.zuletzt.titel, aktiv: auswahl == .zuletzt) { auswahl = .zuletzt }
                Rectangle().fill(DesignSystem.Color.line).frame(width: 1, height: 24)
                    .accessibilityHidden(true)
                ForEach(gruppen, id: \.self) { gruppe in
                    Pille(titel: gruppe.titel, aktiv: auswahl == .gruppe(gruppe)) { auswahl = .gruppe(gruppe) }
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

    private func kopf(_ abschnitt: UebungsGruppierung.Abschnitt) -> String {
        let titel = abschnitt.gruppe.titel.uppercased()
        guard filter != nil else { return titel }
        let anzahl = abschnitt.uebungen.count
        return "\(titel) · \(anzahl) \(anzahl == 1 ? "ÜBUNG" : "ÜBUNGEN")"
    }

    var body: some View {
        if gruppiert {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                ForEach(UebungsGruppierung.gruppieren(uebungen, nur: filter), id: \.gruppe) { abschnitt in
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        Text(kopf(abschnitt))
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
