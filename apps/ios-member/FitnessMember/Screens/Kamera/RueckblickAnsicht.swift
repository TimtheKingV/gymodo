import Koerperbild
import SwiftUI

/// 7.6: der Rueckblick nach dem Satz mit Balken je Wiederholung, Pausenuhr und dem Weg weiter.
struct RueckblickAnsicht: View {
    let start: KameraStart
    /// Der Satz, auf den sich der Rueckblick bezieht.
    let satz: Int
    let daten: KameraAblaufModell.Rueckblickdaten
    let pauseEnde: Date?
    let beiSchliessen: () -> Void
    let beiNaechsterSatz: () async -> Void
    let beiKorrigieren: (Int) -> Void

    @State private var korrigierenOffen = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            kopf
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kacheln
                    tempokarte
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            fuss
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.top, DesignSystem.Spacing.s8)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Color.bg.ignoresSafeArea())
        .foregroundStyle(DesignSystem.Color.text)
        .sheet(isPresented: $korrigierenOffen) {
            WiederholungKorrigieren(wiederholungen: daten.wiederholungen) { n in
                korrigierenOffen = false
                beiKorrigieren(n)
            }
        }
    }

    // MARK: Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            HStack {
                Button(action: beiSchliessen) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Rückblick schließen")
                .padding(.leading, -12)
                Spacer()
            }
            Text("\(start.name.uppercased()) · SATZ \(satz) VON \(start.satzZiel)")
                .font(DesignSystem.Typography.label)
                .tracking(0.9)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineLimit(1)
            Text("SATZ GESCHAFFT")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-0.8)
            if let abgelehnt = daten.abgelehnt {
                Text(abgelehnt)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.warn)
                    .padding(.top, DesignSystem.Spacing.s4)
            }
        }
    }

    // MARK: Kacheln

    private var kacheln: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            kachel("WDH.") {
                Text("\(daten.wiederholungen)").font(.system(size: 44, weight: .black).monospacedDigit())
            }
            if let r = daten.rueckblick, r.bewertet > 0 {
                kachel("IM TAKT") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(r.imTakt)")
                            .font(.system(size: 44, weight: .black).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.accent)
                        Text("von \(r.bewertet)")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                }
            }
        }
    }

    private func kachel<Inhalt: View>(_ titel: String, @ViewBuilder inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(titel)
                .font(DesignSystem.Typography.label)
                .tracking(0.9)
                .foregroundStyle(DesignSystem.Color.textMuted)
            inhalt()
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: Tempokarte

    @ViewBuilder private var tempokarte: some View {
        if let r = daten.rueckblick {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                Text("TEMPO JE WIEDERHOLUNG")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                balken(r)
                if let satz = Ausreisser.satz(rueckblick: r, tempo: daten.tempo) {
                    Text(satz).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        } else {
            Text("Zu kurz für einen Rückblick")
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Hoehe je Urteil: im Takt 64 pt, zu schnell 96 pt, zu langsam 88 pt; leer ohne Bewertung.
    static func balkenhoehe(_ u: Wiederholungsurteil) -> CGFloat {
        guard u.imTakt == false else { return 64 }
        if u.rueck == .zuSchnell || u.hin == .zuSchnell { return 96 }
        return 88
    }

    private func balken(_ r: Koerperbild.Rueckblick) -> some View {
        let abstand: CGFloat = r.urteile.count > 12 ? 4 : 8
        return VStack(spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .bottom, spacing: abstand) {
                ForEach(Array(r.urteile.enumerated()), id: \.offset) { _, u in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(u.imTakt == nil ? DesignSystem.Color.surfaceRaised
                              : u.imTakt == true ? DesignSystem.Color.accent : DesignSystem.Color.warn.opacity(0.7))
                        .frame(height: u.imTakt == nil ? 64 : Self.balkenhoehe(u))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
            HStack(spacing: abstand) {
                ForEach(Array(r.urteile.enumerated()), id: \.offset) { i, u in
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(u.imTakt == false ? DesignSystem.Color.warn : DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(r.imTakt) von \(r.bewertet) Wiederholungen im Takt")
    }

    // MARK: Fuss

    private var fuss: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            if let ende = pauseEnde, ende > Date() {
                HStack(alignment: .firstTextBaseline) {
                    Text("PAUSE")
                        .font(DesignSystem.Typography.label)
                        .tracking(0.9)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { zeit in
                        let rest = max(0, Int(ende.timeIntervalSince(zeit.date).rounded(.up)))
                        Text(String(format: "%d:%02d", rest / 60, rest % 60))
                            .font(.system(size: 32, weight: .black).monospacedDigit())
                    }
                }
            }
            if daten.letzterSatz {
                PrimaryButton(title: "Gerät abschließen") { beiSchliessen() }
                textknopf("Weiterer Satz") { Task { await beiNaechsterSatz() } }
            } else {
                PrimaryButton(title: "Satz \(satz + 1) starten") { await beiNaechsterSatz() }
            }
            if daten.abgelehnt == nil {
                textknopf("Wdh. korrigieren") { korrigierenOffen = true }
            }
        }
    }

    private func textknopf(_ titel: String, aktion: @escaping () -> Void) -> some View {
        Button(titel, action: aktion)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.text)
            .frame(maxWidth: .infinity, minHeight: 48)
    }
}

#if DEBUG
#Preview("7.6 Rückblick") {
    let urteile = (1...8).map { i -> Wiederholungsurteil in
        let schnell = i == 4 || i == 7
        return Wiederholungsurteil(anteilInBahn: 0.9, imTakt: !schnell, hin: schnell ? .zuSchnell : .imTempo, rueck: .imTempo)
    }
    return RueckblickAnsicht(
        start: .vorschau, satz: 2,
        daten: .init(wiederholungen: 8, rueckblick: Koerperbild.Rueckblick(urteile: urteile), abgelehnt: nil,
                     letzterSatz: false, tempo: KameraStart.vorschau.tempo),
        pauseEnde: Date().addingTimeInterval(90), beiSchliessen: {}, beiNaechsterSatz: {}, beiKorrigieren: { _ in })
}

#Preview("7.6 Zu kurz, letzter Satz") {
    RueckblickAnsicht(
        start: .vorschau, satz: 3,
        daten: .init(wiederholungen: 2, rueckblick: nil, abgelehnt: "Satz konnte nicht gesichert werden.",
                     letzterSatz: true, tempo: KameraStart.vorschau.tempo),
        pauseEnde: nil, beiSchliessen: {}, beiNaechsterSatz: {}, beiKorrigieren: { _ in })
}
#endif
