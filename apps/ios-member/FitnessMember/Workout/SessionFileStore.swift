import Foundation

/// Die laufende Einheit auf Platte -- wie PendingWriteStore, aus demselben
/// Grund: nach einem App-Kill muss "Satz 3" noch Satz 3 heissen und der
/// Training-Tab seine Bloecke zeigen.
///
/// App-Support statt Keychain: das sind Trainingsdaten, keine Zugangsdaten.
final class SessionFileStore {
    private let fileURL: URL
    private let beginnURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("laufende-session.json")
        beginnURL = directory.appendingPathComponent("trainingsbeginn.json")
    }

    func load() -> LokaleSession? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LokaleSession.self, from: data)
    }

    func save(_ session: LokaleSession?) {
        guard let session else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Der erste Geraetekontakt einer Einheit -- eigene Datei, weil er
    /// VOR der ersten LokaleSession existiert: die entsteht erst mit dem
    /// ersten gesicherten Satz, die Trainingsuhr laeuft aber schon, seit
    /// das Mitglied am ersten Geraet steht.
    func loadBeginn() -> Date? {
        guard let data = try? Data(contentsOf: beginnURL) else { return nil }
        return try? JSONDecoder().decode(Date.self, from: data)
    }

    func saveBeginn(_ datum: Date?) {
        guard let datum else {
            try? FileManager.default.removeItem(at: beginnURL)
            return
        }
        guard let data = try? JSONEncoder().encode(datum) else { return }
        try? data.write(to: beginnURL, options: .atomic)
    }
}
