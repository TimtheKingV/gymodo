import Koerperbild
import SwiftUI

/// 7.3: ganz im Bild, Rahmen durchgezogen, "LOS IN" mit der Ziffer.
struct CountdownSchritt: View {
    let start: KameraStart
    let satz: Int
    /// nil: wartet noch auf kurze Ruhe; sonst 3, 2, 1.
    let rest: Int?
    let beiAbbrechen: () -> Void
    let beiOhneKamera: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Spacer(minLength: 0)
            fuss
        }
        .foregroundStyle(DesignSystem.Color.text)
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack {
                Text("SATZ \(satz) VON \(start.satzZiel) · \(start.name.uppercased())")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineLimit(1)
                Spacer()
                OhneKameraKnopf(aktion: beiOhneKamera)
            }
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.accent)
                Text("Du bist ganz im Bild").font(.system(size: 19, weight: .heavy))
            }
            Text("Geh in die Startposition und bleib kurz ruhig stehen.")
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kameraLeiste(.top)
    }

    private var fuss: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LOS IN")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                // Solange die Ruhe fehlt, steht die 3 gedaempft: der Countdown laeuft noch nicht.
                Text(rest.map(String.init) ?? "3")
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(rest == nil ? DesignSystem.Color.textMuted : DesignSystem.Color.accent)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button(action: beiAbbrechen) {
                Text("Abbrechen")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                        .stroke(DesignSystem.Color.text, lineWidth: 1))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.top, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .kameraLeiste(.bottom)
    }
}

#if DEBUG
#Preview("7.3 Countdown") {
    let vorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
    return CountdownSchritt(
        start: KameraStart(exerciseId: "x", name: "Kniebeuge", geraet: "Langhantel", vorgabe: vorgabe,
                           tempo: .standard(beginntMit: .senken), sollWiederholungen: 8, satzZiel: 3),
        satz: 2, rest: 3, beiAbbrechen: {}, beiOhneKamera: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: KameraVorschau.skelett(), profil: vorgabe.profil, bestanden: true) }
}
#endif
