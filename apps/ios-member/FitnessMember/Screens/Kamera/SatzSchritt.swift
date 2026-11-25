import AVFoundation
import Koerperbild
import Sensorik
import SwiftUI

/// Was `SatzSchritt` von der Zustandsmaschine zeigt; als Wert, damit die Vorschau keine Kamera braucht.
struct Satzanzeige {
    let welle: Sollwelle
    let sollzeit: TimeInterval
    let spur: [KameraSatzAblauf.Spurpunkt]
    let takt: KameraSatzAblauf.Takt
    let phase: Tempophase?
    let wiederholungen: Int
    let bildrateZuNiedrig: Bool

    init(_ ablauf: KameraSatzAblauf) {
        welle = ablauf.welle; sollzeit = ablauf.sollzeit ?? 0; spur = ablauf.spur; takt = ablauf.takt
        phase = ablauf.phase; wiederholungen = ablauf.wiederholungen; bildrateZuNiedrig = ablauf.bildrateZuNiedrig
    }

    init(welle: Sollwelle, sollzeit: TimeInterval, spur: [KameraSatzAblauf.Spurpunkt], takt: KameraSatzAblauf.Takt,
         phase: Tempophase?, wiederholungen: Int, bildrateZuNiedrig: Bool = false) {
        self.welle = welle; self.sollzeit = sollzeit; self.spur = spur; self.takt = takt
        self.phase = phase; self.wiederholungen = wiederholungen; self.bildrateZuNiedrig = bildrateZuNiedrig
    }
}

/// Das Fenster des Wellenbands: Spur und Punkt aus der Anzeige.
extension Wellenband {
    init(anzeige: Satzanzeige, tempo: Uebungstempo, gedaempft: Bool = false, wartend: Bool = false) {
        self.init(welle: anzeige.welle, tempo: tempo, sollzeit: anzeige.sollzeit, spur: anzeige.spur,
                  punkt: anzeige.spur.last?.lage, takt: anzeige.takt, gedaempft: gedaempft, wartend: wartend,
                  punktSicher: anzeige.spur.last?.sicher ?? true)
    }
}

/// 7.4: der Satz mit der Welle. Livebild und Strichfigur liegen darunter (KameraAblaufAnsicht).
struct SatzSchritt: View {
    let start: KameraStart
    let satz: Int
    let anzeige: Satzanzeige
    @Binding var videoOffen: Bool
    let beiSatzBeenden: () async -> Void
    let beiOhneKamera: () -> Void

    private var sollErreicht: Bool {
        start.sollWiederholungen.map { anzeige.wiederholungen >= $0 } ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            kopf
            if anzeige.bildrateZuNiedrig {
                BildrateBanner(beiOhneKamera: beiOhneKamera)
            }
            Spacer(minLength: 0)
            band
            fuss
        }
        .overlay(alignment: .topTrailing) {
            if videoOffen {
                KleinesVideo(exerciseId: start.exerciseId)
                    .padding(.trailing, DesignSystem.Spacing.s16)
                    .padding(.top, 90)
            }
        }
        .foregroundStyle(DesignSystem.Color.text)
    }

    private var kopf: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text("\(Satzkopf.text(satz: satz, ziel: start.satzZiel))")
                    .font(DesignSystem.Typography.label)
                    .tracking(0.9)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Text(start.name.uppercased())
                    .font(.system(size: 19, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            OhneKameraKnopf(aktion: beiOhneKamera)
            Button { videoOffen.toggle() } label: {
                Image(systemName: "play")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                        .stroke(DesignSystem.Color.line, lineWidth: 1))
            }
            .accessibilityLabel("Übungsvideo noch einmal ansehen")
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s12)
        .kameraLeiste(.top)
    }

    // MARK: Band

    private var band: some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            HStack {
                Text(Self.phasenwort(anzeige.phase))
                    .font(.system(size: 19, weight: .black))
                    .tracking(0.4)
                Spacer()
                pille
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)
            Wellenband(anzeige: anzeige, tempo: start.tempo, gedaempft: sollErreicht)
                .frame(height: 100)
        }
        .padding(.top, DesignSystem.Spacing.s12)
        .frame(maxWidth: .infinity)
        .frame(height: 160, alignment: .top)
        .background(DesignSystem.Color.bg.opacity(0.78))
        .overlay(alignment: .top) {
            if anzeige.takt != .imTakt { Rectangle().fill(DesignSystem.Color.warn).frame(height: 2) }
        }
    }

    static func phasenwort(_ phase: Tempophase?) -> String {
        switch phase {
        case .senken: "SENKEN"
        case .halten: "HALTEN"
        case .heben: "HEBEN"
        case nil: ""
        }
    }

    /// "Im Takt" / "Zu schnell, langsamer senken" / "Zu langsam, zügiger heben"; im Halten
    /// "Zu schnell, länger halten" / "Zu langsam, jetzt <nächster Weg>".
    static func pillentext(takt: KameraSatzAblauf.Takt, phase: Tempophase?, tempo: Uebungstempo) -> String {
        func verb(_ p: Tempophase) -> String {
            switch p { case .senken: "senken"; case .halten: "halten"; case .heben: "heben" }
        }
        switch takt {
        case .imTakt: return "Im Takt"
        case .zuSchnell:
            guard let phase, phase != .halten else { return "Zu schnell, länger halten" }
            return "Zu schnell, langsamer \(verb(phase))"
        case .zuLangsam:
            guard let phase, phase != .halten else { return "Zu langsam, jetzt \(verb(tempo.phase(.ablassen)))" }
            return "Zu langsam, zügiger \(verb(phase))"
        }
    }

    private var pille: some View {
        let imTakt = anzeige.takt == .imTakt
        return HStack(spacing: 6) {
            if !imTakt { Image(systemName: "chevron.forward.2").font(.system(size: 12, weight: .heavy)) }
            Text(Self.pillentext(takt: anzeige.takt, phase: anzeige.phase, tempo: start.tempo))
                .font(.system(size: 13, weight: .heavy))
        }
        .foregroundStyle(DesignSystem.Color.onAccent)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(imTakt ? DesignSystem.Color.accent : DesignSystem.Color.warn, in: Capsule())
    }

    // MARK: Fuss

    private var fuss: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
                Text("\(anzeige.wiederholungen)")
                    .font(DesignSystem.Typography.wertHeld)
                    .contentTransition(.numericText())
                Text(start.sollWiederholungen.map { "von \($0) Wdh." } ?? "Wdh.")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button { Task { await beiSatzBeenden() } } label: {
                Text("Satz beenden")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                        .stroke(DesignSystem.Color.text, lineWidth: 1))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.vertical, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Color.bg.ignoresSafeArea(edges: .bottom))
    }
}

/// Das Uebungsvideo klein oben rechts (40 % der Breite), waehrend Welle und Zaehlung weiterlaufen.
private struct KleinesVideo: View {
    @Environment(UebungsVideoVorrat.self) private var vorrat
    let exerciseId: String
    @State private var asset: AVAsset?

    var body: some View {
        ZStack {
            DesignSystem.Color.surface
            if let asset { EinmalVideo(asset: asset) }
        }
        .containerRelativeFrame(.horizontal) { breite, _ in breite * 0.4 }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(DesignSystem.Color.line, lineWidth: 1))
        .task(id: exerciseId) {
            guard let datei = await vorrat.datei(exerciseId: exerciseId, ersatz: nil) else { return }
            asset = await Schleifenvideo.nurBild(datei)
        }
    }
}

/// "Dein Handy kommt nicht mehr mit." mit dem Weg ohne Kamera.
struct BildrateBanner: View {
    let beiOhneKamera: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DesignSystem.Color.warn)
            Text("Dein Handy kommt nicht mehr mit.")
                .font(.system(size: 15, weight: .bold))
            Spacer(minLength: 0)
            Button("Ohne Kamera weiterzählen", action: beiOhneKamera)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(DesignSystem.Spacing.s12)
        .background(DesignSystem.Color.bg.opacity(0.88), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(DesignSystem.Color.warn, lineWidth: 1))
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.top, DesignSystem.Spacing.s8)
        .foregroundStyle(DesignSystem.Color.text)
    }
}

/// Karte ueber dem Livebild fuer `keineBewegung` und `bewegungZuKlein`.
struct HinweisSchritt: View {
    let start: KameraStart
    let satz: Int
    let titel: String
    var text: String?
    /// Der Knopf der Karte; nil: die ganze Karte ist der Knopf `beiKarte`.
    var knopf: (titel: String, aktion: () -> Void)?
    var beiKarte: (() -> Void)?
    let beiOhneKamera: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(Satzkopf.text(satz: satz, ziel: start.satzZiel)) · \(start.name.uppercased())")
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
            Spacer(minLength: 0)
            karte
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .padding(.bottom, DesignSystem.Spacing.s32)
        }
        .foregroundStyle(DesignSystem.Color.text)
    }

    @ViewBuilder private var karte: some View {
        if let beiKarte {
            Button(action: beiKarte) { inhalt }.buttonStyle(.plain)
        } else {
            inhalt
        }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(titel).font(.system(size: 22, weight: .black))
            if let text {
                Text(text).font(.system(size: 16)).foregroundStyle(DesignSystem.Color.textMuted)
            }
            if let knopf { PrimaryButton(title: knopf.titel) { knopf.aktion() } }
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.bg.opacity(0.9), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt).stroke(DesignSystem.Color.warn, lineWidth: 1))
    }
}

#if DEBUG
extension KameraStart {
    static var vorschau: KameraStart {
        let tempo = Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken)
        let vorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
        return KameraStart(exerciseId: "x", name: "Kniebeuge", geraet: "Langhantel", vorgabe: vorgabe,
                           tempo: tempo, sollWiederholungen: 8, satzZiel: 3)
    }
}

private func vorschauAnzeige(takt: KameraSatzAblauf.Takt) -> Satzanzeige {
    let welle = Sollwelle(vorgabe: KameraStart.vorschau.tempo.vorgabe)
    let spur = stride(from: 0.0, through: 2.2, by: 0.1).map {
        KameraSatzAblauf.Spurpunkt(sollzeit: $0, lage: welle.lage(bei: $0) + (takt == .zuSchnell && $0 > 1.4 ? 0.3 : 0),
                                   sicher: true)
    }
    return Satzanzeige(welle: welle, sollzeit: 2.2, spur: spur, takt: takt, phase: .senken, wiederholungen: 5)
}

#Preview("7.4 Im Takt") {
    @Previewable @State var video = false
    SatzSchritt(start: .vorschau, satz: 2, anzeige: vorschauAnzeige(takt: .imTakt), videoOffen: $video,
                beiSatzBeenden: {}, beiOhneKamera: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: KameraVorschau.skelett(), profil: .ganzkoerperStehend, bestanden: true, dezent: true, hervor: [.hueftL, .knieL, .fussL]) }
        .environment(UebungsVideoVorrat())
}

#Preview("7.4 Zu schnell") {
    @Previewable @State var video = false
    SatzSchritt(start: .vorschau, satz: 2, anzeige: vorschauAnzeige(takt: .zuSchnell), videoOffen: $video,
                beiSatzBeenden: {}, beiOhneKamera: {})
        .background { KameraBildflaeche(ziel: .leer, skelett: KameraVorschau.skelett(), profil: .ganzkoerperStehend, bestanden: true, dezent: true) }
        .environment(UebungsVideoVorrat())
}
#endif
