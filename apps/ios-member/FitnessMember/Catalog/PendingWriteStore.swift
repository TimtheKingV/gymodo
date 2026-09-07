import Foundation

final class PendingWriteStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("pending-writes.json")
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
