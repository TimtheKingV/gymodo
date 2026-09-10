import Foundation
import Observation

/// Haelt einen ueber Universal Link erfassten Tag-Eingang, bis er verbraucht
/// wird -- ersetzt die alte Weitergabe direkt an ContentView aus Task 7 (M0).
///
/// Seit dem Geraetetest haelt der Store nicht mehr nur den gueltigen Token,
/// sondern auch den Fall "URL kam an, war aber keiner". Vorher verwarf
/// FitnessMemberApp so eine URL still -- die App startete dann wortlos auf
/// dem Home-Tab, und von aussen war nicht zu unterscheiden, ob der Link nie
/// ankam oder ob er abgelehnt wurde. Ein Aufkleber, der nichts tut, ist der
/// schlechteste aller Zustaende.
@Observable
final class PendingTagStore {
    enum Eingang: Equatable {
        case token(String)
        /// Eine URL erreichte die App, aber TagLink hat sie abgelehnt. Das
        /// Entitlement laesst nur /t/* herein, es kann also nur ein
        /// kaputter oder fremder Aufkleber sein -- und der bekommt dieselbe
        /// neutrale Antwort wie ein unbekannter Tag (M1-Spec SS10.4).
        case ungueltig
    }

    private(set) var eingang: Eingang?

    /// Fuer alle, die nur wissen muessen, DASS etwas anliegt -- der
    /// Tab-Wechsel in MainTabView. Auch ein ungueltiger Eingang gehoert auf
    /// den Training-Tab: dort steht die Meldung dazu.
    var istOffen: Bool { eingang != nil }

    /// Nur der gueltige Fall. Das Banner auf LoginMailView verspricht, dass
    /// es nach dem Anmelden direkt zum Geraet geht -- das darf ueber einem
    /// abgelehnten Link nicht stehen.
    var token: String? {
        if case .token(let wert) = eingang { return wert }
        return nil
    }

    func capture(_ token: String) {
        eingang = .token(token)
    }

    func captureUngueltig() {
        eingang = .ungueltig
    }

    func consume() -> Eingang? {
        defer { eingang = nil }
        return eingang
    }
}
