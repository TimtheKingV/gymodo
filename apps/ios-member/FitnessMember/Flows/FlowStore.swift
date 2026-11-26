import Foundation
import Observation

/// Schmale Fassade wie KurseLoading: was der FlowStore vom Netz braucht.
protocol FlowLoading: Sendable {
    func flows() async throws(APIError) -> [Flow]
    /// Idempotent (PUT je Run-Id): erneutes Senden desselben Runs ist sicher.
    func putFlowRun(_ run: FlowRunEingabe) async throws(APIError)
}

extension APIClient: FlowLoading {}

/// Wie weit das Laden der Flows ist (fuer Ladeanzeige und Fehlertext).
enum FlowLadeZustand: Equatable, Sendable {
    case idle, laedt, geladen, fehler
}

/// Haelt die Flows (mit Plattencache) und die noch nicht gesendeten Runs --
/// beides gebunden an das angemeldete Konto (`anmelden(userId:)`). Ein Store
/// fuer die ganze App (wie KurseStore); ohne Anmeldung tut er nichts.
@MainActor
@Observable
final class FlowStore {
    private(set) var flows: [Flow] = []
    private(set) var offeneRuns: [FlowRunEingabe] = []
    private(set) var ladeZustand: FlowLadeZustand = .idle
    /// Das Konto, dem Cache und offene Runs gerade gehoeren; nil = abgemeldet.
    private(set) var userId: String?

    private let loader: any FlowLoading
    private let dateiStore: FlowFileStore
    /// Re-Entrancy-Schutz fuer offeneRunsSenden().
    private var sendetGerade = false

    init(loader: any FlowLoading, dateiStore: FlowFileStore) {
        self.loader = loader
        self.dateiStore = dateiStore
    }

    /// Bindet den Store an das Konto und liest dessen Cache und offene Runs
    /// von der Platte. Dasselbe Konto erneut: nichts (der Speicher ist neuer).
    func anmelden(userId neu: String) {
        guard userId != neu else { return }
        userId = neu
        flows = dateiStore.ladeFlows(userId: neu)
        offeneRuns = dateiStore.ladeOffene(userId: neu)
        ladeZustand = .idle
    }

    /// Beim Abmelden: der Speicher gehoert dem Konto nicht mehr. Die Dateien
    /// bleiben liegen -- ein offener Run wird gesendet, wenn dieses Konto
    /// wieder angemeldet ist.
    func reset() {
        userId = nil
        flows = []
        offeneRuns = []
        ladeZustand = .idle
    }

    /// Der Cache steht ab anmelden(); bei Erfolg wird er ersetzt, bei Fehler bleibt er.
    func laden() async {
        guard let konto = userId else { return }
        if flows.isEmpty { ladeZustand = .laedt }
        do throws(APIError) {
            let neu = try await loader.flows()
            guard userId == konto else { return }
            flows = neu
            ladeZustand = .geladen
            dateiStore.speichereFlows(neu, userId: konto)
        } catch {
            // Offline o. ae.: der gecachte Stand traegt weiter.
            guard userId == konto else { return }
            ladeZustand = .fehler
        }
    }

    /// Merkt den Run zuerst auf Platte (er darf nie verloren gehen) und
    /// versucht dann sofort, ihn zu senden. Dieselbe Run-Id ersetzt den Eintrag.
    func runAbschliessen(_ run: FlowRunEingabe) async {
        guard let konto = userId else { return }
        if let index = offeneRuns.firstIndex(where: { $0.id == run.id }) {
            offeneRuns[index] = run
        } else {
            offeneRuns.append(run)
        }
        dateiStore.speichereOffene(offeneRuns, userId: konto)
        await offeneRunsSenden()
    }

    /// Sendet alle offenen Runs des angemeldeten Kontos. Aufgerufen beim
    /// App-Start, beim Aktivwerden, bei wiederkehrendem Netz und nach jedem
    /// Run. Ein Netz- oder Serverfehler laesst den Run stehen; ein
    /// endgueltiger Clientfehler (404 unbekannter Flow, 422 ungueltig)
    /// wuerde nie gelingen und wird verworfen. Ein 401 bleibt stehen (offline
    /// gibt es keinen gueltigen Token). Ein zweiter Aufruf waehrend eines
    /// laufenden wird ignoriert; Runs, die waehrenddessen dazukommen, nimmt
    /// die Schleife mit. Wechselt das Konto mittendrin, bricht die Schleife ab.
    func offeneRunsSenden() async {
        guard let konto = userId, !sendetGerade else { return }
        sendetGerade = true
        defer { sendetGerade = false }
        var versucht: Set<String> = []
        while userId == konto, let run = offeneRuns.first(where: { !versucht.contains($0.id) }) {
            versucht.insert(run.id)
            do throws(APIError) {
                try await loader.putFlowRun(run)
                entfernen(run.id, konto: konto)
            } catch {
                if error.istDauerhaft && !error.istAnmeldefehler {
                    entfernen(run.id, konto: konto)
                } else if case .offline = error {
                    return
                }
            }
        }
    }

    private func entfernen(_ id: String, konto: String) {
        // Nach einem Kontowechsel gehoert der Speicher jemand anderem; der
        // gesendete Run bleibt dann in der Datei des alten Kontos und geht
        // beim naechsten Mal erneut raus (idempotent).
        guard userId == konto else { return }
        offeneRuns.removeAll { $0.id == id }
        dateiStore.speichereOffene(offeneRuns, userId: konto)
    }
}
