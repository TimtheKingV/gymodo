import Foundation

/// Platte fuer Follow-along-Flows: der Katalog-Cache (`flows.json`) und die
/// noch nicht gesendeten Runs (`flow-runs-offen.json`). Nach dem Muster von
/// KurseFileStore: ein verderbtes oder fehlendes File ist ein leerer Bestand,
/// nie ein Absturzgrund.
final class FlowFileStore: @unchecked Sendable {
    private let flowsURL: URL
    private let offeneURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        flowsURL = directory.appendingPathComponent("flows.json")
        offeneURL = directory.appendingPathComponent("flow-runs-offen.json")
    }

    func ladeFlows() -> [Flow] { lade(flowsURL) }
    func speichereFlows(_ flows: [Flow]) { speichere(flows, flowsURL) }

    func ladeOffene() -> [FlowRunEingabe] { lade(offeneURL) }
    func speichereOffene(_ runs: [FlowRunEingabe]) { speichere(runs, offeneURL) }

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
