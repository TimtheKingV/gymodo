import Foundation

/// Persistiert eine Liste von `PendingSetWrite` atomar als JSON-Datei.
///
/// `filename` ist parametrisiert, weil `CatalogStore` zwei Listen mit
/// unterschiedlichem Lebenszyklus im selben Verzeichnis ablegt: offene
/// Schreibvorgaenge (`pending-writes.json`) und dauerhaft abgelehnte
/// (`verworfene-writes.json`). Beide brauchen exakt dasselbe
/// Persistenzverhalten -- ein zweiter, fast identischer Typ waere reine
/// Kopie.
final class PendingWriteStore {
    let directory: URL
    private let fileURL: URL

    init(
        directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
        filename: String = "pending-writes.json"
    ) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
        fileURL = directory.appendingPathComponent(filename)
    }

    func loadAll() -> [PendingSetWrite] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingSetWrite].self, from: data)) ?? []
    }

    func save(_ writes: [PendingSetWrite]) {
        guard let data = try? JSONEncoder().encode(writes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
