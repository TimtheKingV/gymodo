import AVFoundation
import SwiftUI
import UIKit

/// Das Uebungsvideo, einmal durch und stumm. Am Ende bleibt es stehen; Tippen spielt von vorn.
/// Bewegung reduzieren: das erste Bild bleibt stehen.
struct EinmalVideo: UIViewRepresentable {
    let asset: AVAsset
    @Environment(\.accessibilityReduceMotion) private var ruhig

    func makeUIView(context: Context) -> EinmalAnsicht { EinmalAnsicht() }

    func updateUIView(_ ansicht: EinmalAnsicht, context: Context) {
        ansicht.zeige(asset, abspielen: !ruhig)
    }

    static func dismantleUIView(_ ansicht: EinmalAnsicht, coordinator: ()) {
        ansicht.anhalten()
    }
}

final class EinmalAnsicht: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var spielerEbene: AVPlayerLayer { layer as! AVPlayerLayer }

    private var spieler: AVPlayer?
    private var asset: AVAsset?
    private var abspielen = false
    private var begonnen = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(vonVorn)))
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { nil }

    func zeige(_ neu: AVAsset, abspielen: Bool) {
        if asset !== neu {
            let spieler = AVPlayer(playerItem: AVPlayerItem(asset: neu))
            spieler.isMuted = true
            spieler.actionAtItemEnd = .pause
            spieler.preventsDisplaySleepDuringVideoPlayback = false
            self.spieler = spieler
            asset = neu
            begonnen = false
            spielerEbene.player = spieler
        }
        spielerEbene.videoGravity = .resizeAspectFill
        self.abspielen = abspielen
        losspielen()
    }

    func anhalten() {
        spieler?.pause()
        spieler = nil
        spielerEbene.player = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        losspielen()
    }

    private func losspielen() {
        guard abspielen, !begonnen, window != nil else { return }
        begonnen = true
        spieler?.play()
    }

    @objc private func vonVorn() {
        guard let spieler else { return }
        spieler.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            Task { @MainActor in spieler.play() }
        }
    }
}
