import Foundation

/// Die laufende Einheit auf Platte -- wie PendingWriteStore, aus demselben
/// Grund: nach einem App-Kill muss "Satz 3" noch Satz 3 heissen und der
/// Training-Tab seine Bloecke zeigen.
///
/// App-Support statt Keychain: das sind Trainingsdaten, keine Zugangsdaten.
final class SessionFileStore {
    private let schreiber = HintergrundSchreiber()
    private let fileURL: URL
    private let beendetURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("laufende-session.json")
        beendetURL = directory.appendingPathComponent("zuletzt-beendet.json")

        TrainingsDateischutz.vorbereiten(directory)
        TrainingsDateischutz.vorbereiten(fileURL)
        TrainingsDateischutz.vorbereiten(beendetURL)

        // Altlast aus der Zeit vor Schnitt 4: der gemerkte Geraetekontakt lag in
        // einer eigenen Datei, weil die Einheit erst mit dem ersten Satz entstand.
        // Seit die Einheit mit "Training starten" beginnt, liest sie niemand mehr.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("trainingsbeginn.json"))
    }

    /// Wartet, bis alle angenommenen Schreibvorgaenge auf der Platte sind.
    func abwarten() { schreiber.abwarten() }

    func load() -> LokaleSession? {
        schreiber.abwarten()
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LokaleSession.self, from: data)
    }

    /// Kodiert und schreibt im Hintergrund in Reihenfolge der Aufrufe: der
    /// Satz-Knopf wartet nicht auf die Platte (die Session waechst mit jedem
    /// Satz). Lesen wartet dagegen, damit load() immer den letzten Stand sieht.
    func save(_ session: LokaleSession?) {
        let fileURL = fileURL
        guard let session else {
            schreiber.async { try? FileManager.default.removeItem(at: fileURL) }
            return
        }
        schreiber.async {
            guard let data = try? JSONEncoder().encode(session) else { return }
            TrainingsDateischutz.schreiben(data, nach: fileURL)
        }
    }

    func loadBeendet() -> BeendeteSession? {
        schreiber.abwarten()
        guard let data = try? Data(contentsOf: beendetURL) else { return nil }
        return try? JSONDecoder().decode(BeendeteSession.self, from: data)
    }

    func saveBeendet(_ beendet: BeendeteSession?) {
        let beendetURL = beendetURL
        guard let beendet else {
            schreiber.async { try? FileManager.default.removeItem(at: beendetURL) }
            return
        }
        schreiber.async {
            guard let data = try? JSONEncoder().encode(beendet) else { return }
            TrainingsDateischutz.schreiben(data, nach: beendetURL)
        }
    }
}

/// Eine serielle Warteschlange fuer Dateischreibvorgaenge: gleiche Reihenfolge
/// wie die Aufrufe, aber nie auf dem Main Actor. `abwarten()` ist die
/// Schranke fuer Leser und Tests. Die Warteschlange gehoert allen Stores
/// gemeinsam, damit auch eine zweite Instanz auf derselben Datei (Neustart,
/// Test) erst liest, wenn die erste fertig geschrieben hat.
final class HintergrundSchreiber: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "gymtavo.datei-schreiber", qos: .userInitiated)
    private var queue: DispatchQueue { Self.queue }

    func async(_ arbeit: @escaping @Sendable () -> Void) { queue.async(execute: arbeit) }
    func abwarten() { queue.sync {} }
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

/// Nach dem ersten Entsperren bleiben lokale Trainingsschreibvorgaenge
/// auch bei erneut gesperrtem Bildschirm moeglich. Atomare Ersatzdateien
/// bekommen denselben Schutz; bestehende Dateien werden beim Laden migriert.
enum TrainingsDateischutz {
    static func vorbereiten(_ url: URL) {
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }

    static func schreiben(_ daten: Data, nach url: URL) {
        #if os(iOS)
        try? daten.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try? daten.write(to: url, options: .atomic)
        #endif
    }
}
