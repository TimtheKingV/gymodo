import AVFoundation
import SwiftUI
import UIKit

/// Das Video einer Uebung als stumme Endlosschleife in einer Kachel
/// (Testnotiz 11.10., #1, #5, #7).
///
/// Der Platzhalter steht darunter und bleibt sichtbar, bis die Datei da
/// ist -- und fuer immer, wenn es kein Video gibt. Die Zeile springt so
/// nicht, wenn das Video eintrifft.
struct UebungsVideoKachel<Platzhalter: View>: View {
    @Environment(UebungsVideoVorrat.self) private var vorrat

    let exerciseId: String?
    var kante: CGFloat = 56
    /// Ohne Video gar keine Kachel statt des Platzhalters -- fuer den Kopf
    /// der Satzseite, wo ein leerer Kasten nur dem Namen Breite naehme.
    var nurMitVideo = false
    /// Gesetzt fuellt die Kachel die Breite in dieser Hoehe -- das grosse
    /// Video der Einweisung (Testnotiz 11.10., #7). Sonst quadratisch.
    var hoehe: CGFloat?
    /// Die Video-URL aus dem Geraetekontext, falls der Vorrat die Uebung
    /// (noch) nicht kennt.
    var ersatz: URL?
    @ViewBuilder let platzhalter: Platzhalter

    @State private var asset: AVAsset?

    var body: some View {
        // ZStack statt Group: Modifier an einer Group landen an jedem Kind
        // einzeln, die Suche haengte dann am leeren Platzhalter und lief
        // nicht verlaesslich an.
        ZStack {
            if nurMitVideo && asset == nil {
                Color.clear.frame(width: 1, height: 1)
            } else if nurMitVideo {
                // Der Abstand zum Nachbarn gehoert hier zur Kachel: als
                // Spacing des HStack bliebe er auch ohne Video stehen.
                kachel.padding(.trailing, DesignSystem.Spacing.s12)
            } else {
                kachel
            }
        }
        // Der Pfad gehoert zur ID: kommt der Vorrat erst nach der Kachel
        // an (erste Oeffnung der Liste), laeuft die Suche neu.
        .task(id: [exerciseId, exerciseId.flatMap { vorrat.quellen[$0]?.pfad }, ersatz?.path]) {
            guard let exerciseId,
                  let datei = await vorrat.datei(exerciseId: exerciseId, ersatz: ersatz)
            else { return }
            asset = await Schleifenvideo.nurBild(datei)
        }
    }

    // Color.clear als Traeger statt des Platzhalters selbst: ohne
    // Platzhalter (EmptyView) verschwaenden frame und overlay mit ihm --
    // und das Video gleich mit.
    private var kachel: some View {
        Color.clear
            .frame(width: hoehe == nil ? kante : nil, height: hoehe ?? kante)
            .frame(maxWidth: hoehe == nil ? nil : .infinity)
            .background { platzhalter }
            .overlay {
                if let asset {
                    Schleifenvideo(asset: asset)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

/// Spielt ein Asset stumm in Schleife.
///
/// AVPlayerLayer statt VideoPlayer: VideoPlayer bringt Bedienelemente mit
/// und zeigt bis zum ersten Tipp ein schwarzes Feld (Screenshot 06 der
/// Sitzung 11.10.).
struct Schleifenvideo: UIViewRepresentable {
    let asset: AVAsset
    @Environment(\.accessibilityReduceMotion) private var ruhig

    func makeUIView(context: Context) -> SchleifenAnsicht {
        SchleifenAnsicht()
    }

    func updateUIView(_ ansicht: SchleifenAnsicht, context: Context) {
        // Bewegung reduzieren: das erste Bild bleibt stehen.
        ansicht.zeige(asset, abspielen: !ruhig)
    }

    static func dismantleUIView(_ ansicht: SchleifenAnsicht, coordinator: ()) {
        ansicht.anhalten()
    }

    /// Nur die Bildspur. Ein Spieler mit Tonspur aktiviert beim Abspielen
    /// die Audio-Session der App -- auch stumm geschaltet --, und die
    /// Musik des Mitglieds verstummt, sobald die Liste aufgeht.
    static func nurBild(_ datei: URL) async -> AVAsset? {
        let quelle = AVURLAsset(url: datei)
        guard let spur = try? await quelle.loadTracks(withMediaType: .video).first,
              let dauer = try? await quelle.load(.duration),
              let drehung = try? await spur.load(.preferredTransform)
        else { return nil }
        let komposition = AVMutableComposition()
        guard let ziel = komposition.addMutableTrack(withMediaType: .video,
                                                     preferredTrackID: kCMPersistentTrackID_Invalid),
              (try? ziel.insertTimeRange(CMTimeRange(start: .zero, duration: dauer), of: spur, at: .zero)) != nil
        else { return nil }
        ziel.preferredTransform = drehung
        return komposition
    }
}

final class SchleifenAnsicht: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var spielerEbene: AVPlayerLayer { layer as! AVPlayerLayer }

    private var spieler: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var asset: AVAsset?
    private var abspielen = false

    func zeige(_ neu: AVAsset, abspielen: Bool) {
        if asset !== neu {
            let spieler = AVQueuePlayer()
            spieler.isMuted = true
            // Eine Kachel in der Liste soll das Display nicht wachhalten.
            spieler.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: spieler, templateItem: AVPlayerItem(asset: neu))
            self.spieler = spieler
            asset = neu
            spielerEbene.player = spieler
            spielerEbene.videoGravity = .resizeAspectFill
        }
        self.abspielen = abspielen
        aktualisieren()
    }

    func anhalten() {
        spieler?.pause()
        looper = nil
        spieler = nil
        spielerEbene.player = nil
    }

    // Laeuft nur, solange die Kachel in einem Fenster haengt: eine
    // weggescrollte Zeile der LazyVStack oder ein verdeckter Screen im
    // Navigationsstapel spielt nicht im Hintergrund weiter.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        aktualisieren()
    }

    private func aktualisieren() {
        if abspielen, window != nil { spieler?.play() } else { spieler?.pause() }
    }
}

extension UebungsVideoKachel where Platzhalter == EmptyView {
    /// Nur das Video, ohne Platzhalter und ohne Platz, solange keins da ist.
    /// Bringt den Abstand nach rechts selbst mit -- im HStack mit Spacing 0.
    init(exerciseId: String?, kante: CGFloat) {
        self.init(exerciseId: exerciseId, kante: kante, nurMitVideo: true) { EmptyView() }
    }
}
