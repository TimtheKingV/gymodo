import Koerperbild
import SwiftUI

/// 7.2: Livebild mit Strichfigur und Rahmen, Checkliste oben, die eine Anweisung unten.
struct AufstellSchritt: View {
    let start: KameraStart
    let anweisung: Aufstellanweisung
    let fehlendeGruppen: Set<Gelenkgruppe>
    let beiOhneKamera: () -> Void

    private var profil: Kameraprofil { start.vorgabe.profil }

    var body: some View {
        // Livebild, Strichfigur und Rahmen liegen unter allen Kamera-Schritten (KameraAblaufAnsicht).
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
                Text("AUFSTELLEN · \(start.name.uppercased())")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineLimit(1)
                Spacer()
                OhneKameraKnopf(aktion: beiOhneKamera)
            }
            Text(zeile)
                .font(.system(size: 19, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                ForEach(Self.gruppen(vorgabe: start.vorgabe), id: \.self) { gruppe in
                    pruefzeile(gruppe)
                }
                if profil == .oberkoerper {
                    HStack(spacing: 10) {
                        Image(systemName: "minus").frame(width: 20)
                        Text("Beine müssen nicht ins Bild")
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kameraLeiste(.top)
    }

    private var zeile: String {
        profil == .oberkoerper ? "Oberkörper von vorn reicht."
                               : "Lehn das Handy an und stell dich in den Rahmen."
    }

    /// Die Gruppen, die diese Uebung sehen muss (beide Seiten, die Seite wechselt mit der Person).
    static func gruppen(vorgabe: Kameravorgabe) -> [Gelenkgruppe] {
        let pflicht = vorgabe.pflichtgelenke(.links).union(vorgabe.pflichtgelenke(.rechts))
        return Gelenkgruppe.allCases.filter { gruppe in
            !gruppe.gelenke(.links).union(gruppe.gelenke(.rechts)).isDisjoint(with: pflicht)
        }
    }

    static func gruppenname(_ gruppe: Gelenkgruppe) -> String {
        switch gruppe {
        case .schultern: "Kopf und Schultern"
        case .arme: "Ellbogen und Hände"
        case .hueftenKnie: "Hüfte und Knie"
        case .fuesse: "Füße"
        }
    }

    private func pruefzeile(_ gruppe: Gelenkgruppe) -> some View {
        let fehlt = fehlendeGruppen.contains(gruppe)
        return HStack(spacing: 10) {
            Image(systemName: fehlt ? "exclamationmark.circle" : "checkmark")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 20)
                .foregroundStyle(fehlt ? DesignSystem.Color.warn : DesignSystem.Color.accent)
            Text("\(Self.gruppenname(gruppe)) \(fehlt ? "fehlen im Bild" : "erkannt")")
                .font(.system(size: 15, weight: fehlt ? .bold : .regular))
                .foregroundStyle(fehlt ? DesignSystem.Color.warn : DesignSystem.Color.text)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Anweisung unten

    @ViewBuilder private var fuss: some View {
        Group {
            if anweisung == .passt { aufstellhilfe } else { anweisungskarte }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s32)
    }

    private var anweisungskarte: some View {
        let (symbol, text) = Self.anweisungstext(anweisung)
        return HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(DesignSystem.Color.warn)
            Text(text).font(.system(size: 17, weight: .heavy))
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.bg.opacity(0.88), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt).stroke(DesignSystem.Color.warn, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    static func anweisungstext(_ anweisung: Aufstellanweisung) -> (symbol: String, text: String) {
        switch anweisung {
        case .inDenRahmen: ("person.crop.rectangle", "Stell dich in den Rahmen")
        case .schrittZurueck: ("arrow.down", "Geh einen Schritt zurück")
        case .nachLinks: ("arrow.left", "Geh etwas nach links")
        case .nachRechts: ("arrow.right", "Geh etwas nach rechts")
        case .mehrLicht: ("sun.max", "Mehr Licht oder näher ran")
        case .passt: ("checkmark", "")
        }
    }

    private var aufstellhilfe: some View {
        let oberkoerper = profil == .oberkoerper
        return HStack(spacing: 14) {
            Image(systemName: "iphone")
                .font(.system(size: 30, weight: .regular))
            VStack(alignment: .leading, spacing: 2) {
                Text(oberkoerper ? "Handy hochkant auf Hüfthöhe" : "Handy hochkant an den Boden lehnen")
                    .font(.system(size: 16, weight: .heavy))
                Text(oberkoerper ? "Etwa 1,5 m vor dir, zum Beispiel auf der Hantelablage."
                                 : "Etwa 2 m vor dir, der ganze Körper muss ins Bild.")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.bg.opacity(0.88), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt).stroke(DesignSystem.Color.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// 7.2, wenn die Kamera nicht startet.
struct KameraFehltSchritt: View {
    let beiOhneKamera: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("Die Kamera startet gerade nicht.")
                .font(.system(size: 22, weight: .heavy))
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Ohne Kamera trainieren") { beiOhneKamera() }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg.ignoresSafeArea())
        .foregroundStyle(DesignSystem.Color.text)
    }
}

#if DEBUG
#Preview("7.2 Ganzkörper, Füße fehlen") {
    let vorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
    return AufstellSchritt(
        start: KameraStart(exerciseId: "x", name: "Kniebeuge", geraet: "Langhantel", vorgabe: vorgabe,
                           tempo: .standard(beginntMit: .senken), sollWiederholungen: 8, satzZiel: 3),
        anweisung: .schrittZurueck, fehlendeGruppen: [.fuesse], beiOhneKamera: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: KameraVorschau.skelett(), profil: vorgabe.profil, warnend: true) }
}

#Preview("7.2 Oberkörper, passt") {
    let vorgabe = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .beide)!
    return AufstellSchritt(
        start: KameraStart(exerciseId: "x", name: "Bizeps-Curl", geraet: "Kurzhantel", vorgabe: vorgabe,
                           tempo: .standard(beginntMit: .heben), sollWiederholungen: 10, satzZiel: 3),
        anweisung: .passt, fehlendeGruppen: [], beiOhneKamera: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: KameraVorschau.skelett(), profil: vorgabe.profil) }
}

#Preview("7.2 Kamera fehlt") {
    KameraFehltSchritt(beiOhneKamera: {})
}
#endif
