import AVFoundation
import Koerperbild
import Sensorik
import SwiftUI
import UIKit

/// 7.1: das Uebungsvideo einmal durch, darunter das Tempo als Welle.
struct UebungsvideoSchritt: View {
    @Environment(UebungsVideoVorrat.self) private var vorrat
    @Environment(\.accessibilityReduceMotion) private var ruhig
    let start: KameraStart
    let welle: Sollwelle
    let beiHandyAufstellen: () async -> Void
    let beiOhneKamera: () -> Void

    private enum Videostand { case laedt, da(AVAsset), keins }
    @State private var videostand = Videostand.laedt
    @State private var beginn = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            kopf
            videoflaeche
            Text("Gleich siehst du dich selbst im Bild. Der Punkt folgt deiner Bewegung, halte ihn auf der Welle.")
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            VStack(spacing: DesignSystem.Spacing.s8) {
                PrimaryButton(title: "Handy aufstellen", action: beiHandyAufstellen)
                Button("Ohne Kamera trainieren", action: beiOhneKamera)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.top, DesignSystem.Spacing.s8)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Color.bg.ignoresSafeArea())
        .foregroundStyle(DesignSystem.Color.text)
        .task(id: start.exerciseId) {
            guard let datei = await vorrat.datei(exerciseId: start.exerciseId, ersatz: nil),
                  let asset = await Schleifenvideo.nurBild(datei) else {
                videostand = .keins
                return
            }
            videostand = .da(asset)
        }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(start.name.uppercased())
                .font(DesignSystem.Typography.screentitel)
                .tracking(-0.8)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(untertitel)
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// "Gerät · s Sätze · w Wdh."; was unbekannt ist, entfaellt.
    private var untertitel: String {
        var teile: [String] = []
        if let geraet = start.geraet { teile.append(geraet) }
        teile.append("\(start.satzZiel) \(start.satzZiel == 1 ? "Satz" : "Sätze")")
        if let wdh = start.sollWiederholungen { teile.append("\(wdh) Wdh.") }
        return teile.joined(separator: " · ")
    }

    private var videoflaeche: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.surfaceRaised
            switch videostand {
            case .da(let asset): EinmalVideo(asset: asset)
            case .laedt: platzhalter(text: nil)
            case .keins: platzhalter(text: "Kein Video verfügbar")
            }
            tempoleiste
        }
        .frame(minHeight: 280, maxHeight: 440)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
    }

    private func platzhalter(text: String?) -> some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "play.circle")
                .font(.system(size: 48, weight: .regular))
            if let text { Text(text).font(.system(size: 15)) }
        }
        .foregroundStyle(DesignSystem.Color.textMuted)
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.bottom, 150)
    }

    private var tempoleiste: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("DEIN TEMPO")
                .font(DesignSystem.Typography.label)
                .tracking(0.9)
                .foregroundStyle(DesignSystem.Color.accent)
                .padding(.horizontal, DesignSystem.Spacing.s16)
            // Die Sollzeit laeuft von selbst; bei reduzierter Bewegung steht das Band still.
            TimelineView(.animation(paused: ruhig)) { zeit in
                Wellenband(welle: welle, tempo: start.tempo,
                           sollzeit: ruhig ? 0 : zeit.date.timeIntervalSince(beginn))
            }
            .frame(height: 100)
            Text(start.tempo.inWorten)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, DesignSystem.Spacing.s16)
        }
        .padding(.top, DesignSystem.Spacing.s16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.bg.opacity(0.78))
    }
}

/// 7.1, wenn die Kamera nicht erlaubt ist.
struct ErlaubnisFehltSchritt: View {
    let beiEinstellungen: () -> Void
    let beiOhneKamera: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("Kamera ist nicht erlaubt")
                .font(.system(size: 22, weight: .heavy))
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: DesignSystem.Spacing.s8) {
                PrimaryButton(title: "In den Einstellungen erlauben") { beiEinstellungen() }
                Button("Ohne Kamera trainieren", action: beiOhneKamera)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg.ignoresSafeArea())
        .foregroundStyle(DesignSystem.Color.text)
    }
}

#if DEBUG
#Preview("7.1 Video") {
    let tempo = Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken)
    let vorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
    return UebungsvideoSchritt(
        start: KameraStart(exerciseId: "x", name: "Kniebeuge", geraet: "Langhantel", vorgabe: vorgabe,
                           tempo: tempo, sollWiederholungen: 8, satzZiel: 3),
        welle: Sollwelle(vorgabe: tempo.vorgabe), beiHandyAufstellen: {}, beiOhneKamera: {})
        .environment(UebungsVideoVorrat())
}

#Preview("7.1 Erlaubnis fehlt") {
    ErlaubnisFehltSchritt(beiEinstellungen: {}, beiOhneKamera: {})
}
#endif
