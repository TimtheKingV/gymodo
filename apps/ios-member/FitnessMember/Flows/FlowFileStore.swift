import Foundation

/// Platte fuer Follow-along-Flows: der Katalog-Cache (`flows-<userId>.json`)
/// und die noch nicht gesendeten Runs (`flow-runs-offen-<userId>.json`).
/// Wie BootstrapFileStore (Offline-Spec 3a/4c) steht die User-ID im
/// Dateinamen: ein anderes Konto auf demselben Geraet findet die Dateien nie,
/// und ein offener Run wird nie mit fremdem Token gesendet. Nach dem Muster
/// von KurseFileStore ist ein verderbtes oder fehlendes File ein leerer
/// Bestand, nie ein Absturzgrund.
final class FlowFileStore: @unchecked Sendable {
    private let directory: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    private func flowsURL(_ userId: String) -> URL {
        directory.appendingPathComponent("flows-\(userId).json")
    }

    private func offeneURL(_ userId: String) -> URL {
        directory.appendingPathComponent("flow-runs-offen-\(userId).json")
    }

    func ladeFlows(userId: String) -> [Flow] { lade(flowsURL(userId)) }
    func speichereFlows(_ flows: [Flow], userId: String) { speichere(flows, flowsURL(userId)) }

    func ladeOffene(userId: String) -> [FlowRunEingabe] { lade(offeneURL(userId)) }
    func speichereOffene(_ runs: [FlowRunEingabe], userId: String) { speichere(runs, offeneURL(userId)) }

    private func lade<T: Decodable>(_ url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    private func speichere<T: Encodable>(_ werte: [T], _ url: URL) {
        guard !werte.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let data = try? JSONEncoder().encode(werte) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
