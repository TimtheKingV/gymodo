#if DEBUG
import UIKit

/// Liegt ueber allem, auch ueber Alerts -- die will man festhalten koennen.
final class TestnotizFenster: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = .alert + 1
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("nicht aus einem Storyboard") }

    /// In Ruhe faengt nur der Knopf (mit 8 pt Rand fuer den Finger). Nicht
    /// ueber super.hitTest entscheidbar: SwiftUIs Hosting-View gibt sich fuer
    /// die leere Flaeche UND fuer den Knopf selbst zurueck (Spike 2026-09-14).
    static func faengt(punkt: CGPoint, modus: Testnotiz.Modus, knopfRahmen: CGRect) -> Bool {
        modus != .ruhe || knopfRahmen.insetBy(dx: -8, dy: -8).contains(punkt)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let testnotiz = Testnotiz.shared
        guard Self.faengt(punkt: point, modus: testnotiz.modus, knopfRahmen: testnotiz.knopfRahmen) else { return nil }
        return super.hitTest(point, with: event)
    }
}
#endif
