import Foundation
import Network
import Observation

/// Verbindungszustand -- speist die Offline-Leiste und loest die
/// Schreib-Warteschlange aus.
///
/// Die SP1-Spec sagt diesen Monitor zu; gebaut wurde er nie, weshalb
/// flushPending() bisher ueberhaupt keinen Ausloeser hatte.
@MainActor
@Observable
final class NetzwerkMonitor {
    private(set) var istOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let warteschlange = DispatchQueue(label: "de.gymtaro.netzwerk")
    @ObservationIgnored private var laeuft = false

    /// `beiVerbindung` feuert nur beim Wechsel von offline nach online --
    /// nicht bei jedem Pfad-Update, sonst liefe die Warteschlange bei jedem
    /// WLAN-Kanalwechsel erneut an.
    func start(beiVerbindung: @escaping @MainActor () -> Void) {
        guard !laeuft else { return }
        laeuft = true
        monitor.pathUpdateHandler = { [weak self] pfad in
            let erreichbar = pfad.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let warOffline = !self.istOnline
                self.istOnline = erreichbar
                if erreichbar && warOffline { beiVerbindung() }
            }
        }
        monitor.start(queue: warteschlange)
    }

    func stop() {
        monitor.cancel()
        laeuft = false
    }
}
