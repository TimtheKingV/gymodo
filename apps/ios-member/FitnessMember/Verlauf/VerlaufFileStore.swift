import Foundation

/// Der Verlauf auf Platte -- vollstaendig, anders als bei den Kursen.
///
/// `KurseFileStore` laesst Belegungszahlen bewusst weg: sie veralten
/// binnen Minuten, und ohne Netz waeren sie eine Unwahrheit. Hier gibt es
/// nichts dergleichen -- Einheiten, Saetze und Gewichte aendern sich
/// ausschliesslich durch das eigene Tun.
///
/// Ohne `studioId`, ebenfalls anders als bei den Kursen: der Verlauf ist
/// studioübergreifend. Wer in zwei Studios trainiert, hat einen Verlauf,
/// nicht zwei -- ein Studiowechsel macht ihn also nicht falsch, nur die
/// Wochenzahl darin gehoert zur Zeitzone des vorigen Studios, und die
/// rechnet der naechste Abruf neu.
struct GespeicherterVerlauf: Codable {
    let stand: Date
    let sessions: [SessionSummary]
    let summary: SessionsSummary
    let fortschritt: [ExerciseProgress]
}

/// Wie `KurseFileStore` und `SessionFileStore`: App-Support-Verzeichnis,
/// JSON, atomar, Fehler still -- ein fehlendes oder verderbtes File ist
/// kein Absturzgrund, nur ein leerer Cache.
final class VerlaufFileStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("verlauf.json")
    }

    func load() -> GespeicherterVerlauf? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GespeicherterVerlauf.self, from: data)
    }

    /// `nil` raeumt die Datei weg -- fuer reset() beim Abmelden.
    func save(_ verlauf: GespeicherterVerlauf?) {
        guard let verlauf else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(verlauf) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
