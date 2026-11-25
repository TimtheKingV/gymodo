import Koerperbild
import SwiftUI

/// 7.5: Tracking verloren. Die Welle wartet, die Wiederholungen bleiben gezaehlt.
struct VerlorenSchritt: View {
    let start: KameraStart
    let satz: Int
    let wiederholungen: Int
    let beiOhneKamera: () -> Void
    let beiSatzBeenden: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Spacer(minLength: 0)
            panel
        }
        .foregroundStyle(DesignSystem.Color.text)
    }

    private var kopf: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text("SATZ \(satz) VON \(start.satzZiel) · PAUSIERT")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Text(start.name.uppercased()).font(.system(size: 19, weight: .heavy))
            }
            Spacer()
            OhneKameraKnopf(aktion: beiOhneKamera)
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kameraLeiste(.top)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.warn)
                Text("Wir sehen dich nicht mehr")
                    .font(.system(size: 24, weight: .black))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Die Welle wartet. \(wiederholungen == 1 ? "Deine Wiederholung bleibt" : "Deine \(wiederholungen) Wiederholungen bleiben") gezählt. Stell dich wieder in den Rahmen, dann geht es von allein weiter.")
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: DesignSystem.Spacing.s8) {
                PrimaryButton(title: "Ohne Kamera weiterzählen") { beiOhneKamera() }
                Button { Task { await beiSatzBeenden() } } label: {
                    Text("Satz bei \(wiederholungen) Wdh. beenden")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                            .stroke(DesignSystem.Color.text, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.top, DesignSystem.Spacing.s24)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.bg.clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            .ignoresSafeArea(edges: .bottom))
    }
}

/// Vorlauf nach dem Wiedereinstieg: "Gleich geht es weiter" mit 2, 1.
struct VorlaufSchritt: View {
    let start: KameraStart
    let satz: Int
    let rest: Int
    let beiOhneKamera: () -> Void
    var bildrateZuNiedrig = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SATZ \(satz) VON \(start.satzZiel) · \(start.name.uppercased())")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineLimit(1)
                Spacer()
                OhneKameraKnopf(aktion: beiOhneKamera)
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .padding(.bottom, DesignSystem.Spacing.s12)
            .kameraLeiste(.top)
            if bildrateZuNiedrig { BildrateBanner(beiOhneKamera: beiOhneKamera) }
            Spacer(minLength: 0)
            HStack {
                Text("Gleich geht es weiter").font(.system(size: 19, weight: .heavy))
                Spacer()
                Text("\(rest)")
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.accent)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .padding(.vertical, DesignSystem.Spacing.s16)
            .frame(maxWidth: .infinity)
            .kameraLeiste(.bottom)
        }
        .foregroundStyle(DesignSystem.Color.text)
    }
}

#if DEBUG
#Preview("7.5 Verloren") {
    VerlorenSchritt(start: .vorschau, satz: 2, wiederholungen: 5, beiOhneKamera: {}, beiSatzBeenden: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: nil, profil: .ganzkoerperStehend) }
}

#Preview("7.5 Vorlauf") {
    VorlaufSchritt(start: .vorschau, satz: 2, rest: 2, beiOhneKamera: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: KameraVorschau.skelett(), profil: .ganzkoerperStehend, bestanden: true) }
}
#endif
