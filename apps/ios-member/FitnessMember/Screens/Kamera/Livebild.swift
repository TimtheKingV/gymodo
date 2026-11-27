import AVFoundation
import SwiftUI
import UIKit

/// Wohin das Livebild geht: die Ebene der Quelle und ob die Anzeige gespiegelt wird
/// (nur die Frontkamera; Vision laeuft auf dem ungespiegelten Bild).
struct Livebildziel {
    var ebene: AVSampleBufferDisplayLayer?
    var gespiegelt: Bool

    static var leer: Livebildziel { Livebildziel(ebene: nil, gespiegelt: true) }
}

/// Zeigt die `AVSampleBufferDisplayLayer` der Bildquelle; die Quelle stellt die Bilder selbst ein.
struct Livebild: UIViewRepresentable {
    let ziel: Livebildziel

    func makeUIView(context: Context) -> LivebildAnsicht { LivebildAnsicht() }

    func updateUIView(_ ansicht: LivebildAnsicht, context: Context) {
        ansicht.zeige(ziel.ebene, gespiegelt: ziel.gespiegelt)
    }

    static func dismantleUIView(_ ansicht: LivebildAnsicht, coordinator: ()) {
        ansicht.zeige(nil, gespiegelt: false)
    }
}

final class LivebildAnsicht: UIView {
    private var ebene: AVSampleBufferDisplayLayer?
    private var gespiegelt = false

    func zeige(_ neu: AVSampleBufferDisplayLayer?, gespiegelt: Bool) {
        if ebene !== neu {
            // Nur entfernen, was noch in dieser Ansicht haengt: eine neue Ansicht kann die Ebene schon uebernommen haben.
            if let alt = ebene, alt.superlayer === layer { alt.removeFromSuperlayer() }
            ebene = neu
            if let neu {
                neu.videoGravity = .resizeAspectFill
                layer.addSublayer(neu)
            }
        }
        self.gespiegelt = gespiegelt
        anordnen()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        anordnen()
    }

    private func anordnen() {
        guard let ebene else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ebene.bounds = CGRect(origin: .zero, size: bounds.size)
        ebene.position = CGPoint(x: bounds.midX, y: bounds.midY)
        ebene.transform = gespiegelt ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }
}
