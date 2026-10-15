import Foundation

/// Die laufende Einheit auf Platte -- wie PendingWriteStore, aus demselben
/// Grund: nach einem App-Kill muss "Satz 3" noch Satz 3 heissen und der
/// Training-Tab seine Bloecke zeigen.
///
/// App-Support statt Keychain: das sind Trainingsdaten, keine Zugangsdaten.
final class SessionFileStore {
    private let fileURL: URL
    private let beendetURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("laufende-session.json")
        beendetURL = directory.appendingPathComponent("zuletzt-beendet.json")

        // Altlast aus der Zeit vor Schnitt 4: der gemerkte Geraetekontakt lag in
        // einer eigenen Datei, weil die Einheit erst mit dem ersten Satz entstand.
        // Seit die Einheit mit "Training starten" beginnt, liest sie niemand mehr.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("trainingsbeginn.json"))
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

    func loadBeendet() -> BeendeteSession? {
        guard let data = try? Data(contentsOf: beendetURL) else { return nil }
        return try? JSONDecoder().decode(BeendeteSession.self, from: data)
    }

    func saveBeendet(_ beendet: BeendeteSession?) {
        guard let beendet else {
            try? FileManager.default.removeItem(at: beendetURL)
            return
        }
        guard let data = try? JSONEncoder().encode(beendet) else { return }
        try? data.write(to: beendetURL, options: .atomic)
    }
}

/// Die zuletzt beendete Einheit, 30 Minuten lang fortsetzbar (Testnotiz
/// 14.10., 18:45 #3/#4).
struct BeendeteSession: Codable, Equatable {
    let session: LokaleSession
    let beendetAm: Date
    /// Gesetzt, bevor reopen an den Server geht. Kommt die Antwort nie an,
    /// holt der naechste Verlauf-Abgleich das Training zurueck, sobald der
    /// Server die Einheit offen zeigt (`WorkoutSessionStore.abgleichen`).
    /// Ohne die Marke hiesse "offen" auch: Beenden ging offline nie raus.
    var fortsetzenAngefragt = false
}
