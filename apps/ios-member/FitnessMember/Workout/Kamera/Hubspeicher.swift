import Foundation

/// Merkt den gemessenen Hub je Uebung lokal (nur eine Zahl in Grad, kein Bild).
/// Schluessel `kamera.hub.<exerciseId>`.
struct Hubspeicher {
    // UserDefaults ist threadsicher; die Struktur haelt nur die Referenz.
    nonisolated(unsafe) private let defaults: UserDefaults

    nonisolated(unsafe) static let standard = Hubspeicher(defaults: .standard)

    init(defaults: UserDefaults) { self.defaults = defaults }

    private func schluessel(_ exerciseId: String) -> String { "kamera.hub.\(exerciseId)" }

    func hub(_ exerciseId: String) -> Double? {
        defaults.object(forKey: schluessel(exerciseId)) as? Double
    }

    func merken(_ hub: Double, fuer exerciseId: String) {
        defaults.set(hub, forKey: schluessel(exerciseId))
    }
}
