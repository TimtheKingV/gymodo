import Foundation

/// Der Bootstrap auf Platte, als rohes Server-JSON -- damit die App im
/// Keller ohne Netz startet statt auf "NICHT GELADEN" (Offline-Spec 3a).
///
/// Roh statt neu kodiert: BootstrapResponse ist nur Decodable, und der
/// Cache wird so mit genau demselben Decoder gelesen wie die Netzantwort.
/// Die User-ID steht im Dateinamen: ein anderes Konto auf demselben Geraet
/// findet die Datei nie. Es liegt hoechstens eine Datei da.
final class BootstrapFileStore {
    private let directory: URL
    private static let praefix = "bootstrap-"

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    private func datei(_ userId: String) -> URL {
        directory.appendingPathComponent("\(Self.praefix)\(userId).json")
    }

    /// Eine Datei, die nicht mehr dekodiert (alte App-Fassung), wird
    /// verworfen -- wie ohne Cache, kein Fehlerscreen.
    func load(userId: String) -> BootstrapResponse? {
        guard let daten = try? Data(contentsOf: datei(userId)) else { return nil }
        guard let antwort = try? JSONDecoder().decode(BootstrapResponse.self, from: daten) else {
            try? FileManager.default.removeItem(at: datei(userId))
            return nil
        }
        return antwort
    }

    func save(_ rohdaten: Data, userId: String) {
        loeschen()
        try? rohdaten.write(to: datei(userId), options: .atomic)
    }

    func loeschen() {
        let dateien = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in dateien where name.hasPrefix(Self.praefix) && name.hasSuffix(".json") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
