import Foundation
import Observation

/// Schmale Fassade wie KurseLoading: was der FlowStore vom Netz braucht.
protocol FlowLoading: Sendable {
    func flows() async throws(APIError) -> [Flow]
    /// Idempotent (PUT je Run-Id): erneutes Senden desselben Runs ist sicher.
    func putFlowRun(_ run: FlowRunEingabe) async throws(APIError)
}

extension APIClient: FlowLoading {}

/// Haelt die Flows (mit Plattencache) und die noch nicht gesendeten Runs.
@MainActor
@Observable
final class FlowStore {
    private(set) var flows: [Flow]
    private(set) var offeneRuns: [FlowRunEingabe]

    private let loader: any FlowLoading
    private let dateiStore: FlowFileStore
    /// Re-Entrancy-Schutz fuer offeneRunsSenden().
    private var sendetGerade = false

    init(loader: any FlowLoading, dateiStore: FlowFileStore) {
        self.loader = loader
        self.dateiStore = dateiStore
        flows = dateiStore.ladeFlows()
        offeneRuns = dateiStore.ladeOffene()
    }

    /// Der Cache steht ab init; bei Erfolg wird er ersetzt, bei Fehler bleibt er.
    func laden() async {
        do throws(APIError) {
            let neu = try await loader.flows()
            flows = neu
            dateiStore.speichereFlows(neu)
        } catch {
            // Offline o. ae.: der gecachte Stand traegt weiter.
        }
    }

    /// Merkt den Run zuerst auf Platte (er darf nie verloren gehen) und
    /// versucht dann sofort, ihn zu senden. Dieselbe Run-Id ersetzt den Eintrag.
    func runAbschliessen(_ run: FlowRunEingabe) async {
        if let index = offeneRuns.firstIndex(where: { $0.id == run.id }) {
            offeneRuns[index] = run
        } else {
            offeneRuns.append(run)
        }
        dateiStore.speichereOffene(offeneRuns)
        await offeneRunsSenden()
    }

    /// Sendet alle offenen Runs. Ein Netz- oder Serverfehler laesst den Run
    /// stehen (naechster Start versucht es erneut); ein endgueltiger
    /// Clientfehler (404 unbekannter Flow, 422 ungueltig) wuerde nie gelingen
    /// und wird verworfen. Ein 401 bleibt stehen (offline gibt es keinen
    /// gueltigen Token). Ein zweiter Aufruf waehrend eines laufenden wird
    /// ignoriert; Runs, die waehrenddessen dazukommen, nimmt die Schleife mit.
    func offeneRunsSenden() async {
        guard !sendetGerade else { return }
        sendetGerade = true
        defer { sendetGerade = false }
        var versucht: Set<String> = []
        while let run = offeneRuns.first(where: { !versucht.contains($0.id) }) {
            versucht.insert(run.id)
            do throws(APIError) {
                try await loader.putFlowRun(run)
                entfernen(run.id)
            } catch {
                if error.istDauerhaft && !error.istAnmeldefehler {
                    entfernen(run.id)
                } else if case .offline = error {
                    return
                }
            }
        }
    }

    private func entfernen(_ id: String) {
        offeneRuns.removeAll { $0.id == id }
        dateiStore.speichereOffene(offeneRuns)
    }
}
