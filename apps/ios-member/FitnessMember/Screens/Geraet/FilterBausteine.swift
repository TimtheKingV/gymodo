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

/// Die Bullets: Alle und die Muskelgruppen, eine Auswahl. Scrollt
/// waagerecht, wenn sie nicht passt. nil = Alle.
struct GruppenLeiste: View {
    let gruppen: [MuskelHauptgruppe]
    @Binding var auswahl: MuskelHauptgruppe?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Pille(titel: "Alle", aktiv: auswahl == nil) { auswahl = nil }
                ForEach(gruppen, id: \.self) { gruppe in
                    Pille(titel: gruppe.titel, aktiv: auswahl == gruppe) { auswahl = gruppe }
                }
            }
        }
    }
}

/// Die Zeile unter dem Namen einer Uebung. Mit Historie in der Akzentfarbe
/// wie bei den Geraeten ("vor 2 Tagen · 73,0 kg"): sie sagt auf einen Blick,
/// was relevant ist. Ohne Historie gedaempft.
struct UebungsUntertitel: View {
    let text: String
    let hatHistorie: Bool

    var body: some View {
        if hatHistorie {
            HStack(spacing: 7) {
                Circle()
                    .fill(DesignSystem.Color.accent)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.accent)
            }
        } else {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }
}

/// Der Kopf der Uebungsliste eines Geraets: der grosse Schalter
/// Muskelgruppe | Favorit, darunter die Bullets, dann die Liste.
/// Favorit zeigt nur Uebungen mit Historie, in der Reihenfolge von `uebungen`.
/// Bis zu fuenf Uebungen ohne Schalter -- die Liste ist dort schneller zu
/// ueberblicken als zu filtern.
struct UebungsAnsichtBereich<Zeile: View>: View {
    /// In der "Zuletzt"-Reihenfolge des Geraets.
    let uebungen: [GeraetUebung]
    let hatHistorie: (GeraetUebung) -> Bool
    @Binding var ansicht: Uebungsansicht
    @ViewBuilder let zeile: (GeraetUebung) -> Zeile

    @State private var gruppe: MuskelHauptgruppe?

    var body: some View {
        if UebungsGruppierung.bietetSchalterAn(uebungsanzahl: uebungen.count) {
            let angebot = UebungsGruppierung.vorhandeneGruppen(uebungen)
            let filter = gruppe.flatMap { angebot.contains($0) ? $0 : nil }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                SegmentSchalter(werte: Uebungsansicht.allCases, auswahl: $ansicht, titel: \.titel)
                if ansicht == .muskel {
                    GruppenLeiste(gruppen: angebot, auswahl: $gruppe)
                    UebungsAbschnitte(uebungen: uebungen, gruppiert: true, filter: filter, zeile: zeile)
                } else {
                    let favoriten = uebungen.filter(hatHistorie)
                    if favoriten.isEmpty {
                        Text("Hier erscheinen Übungen, die du an diesem Gerät schon gemacht hast.")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .padding(.vertical, DesignSystem.Spacing.s8)
                    } else {
                        UebungsAbschnitte(uebungen: favoriten, gruppiert: false, zeile: zeile)
                    }
                }
            }
        } else {
            UebungsAbschnitte(uebungen: uebungen, gruppiert: false, zeile: zeile)
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
