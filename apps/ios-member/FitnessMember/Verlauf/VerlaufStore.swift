import Foundation
import Observation

/// Was der Home-Tab vom Netz braucht -- eigene schmale Fassade, wie
/// `KurseLoading` und `BootstrapLoading`.
protocol VerlaufLoading: Sendable {
    func sessions(studio: String?) async throws(APIError) -> SessionsResponse
    func progress() async throws(APIError) -> [ExerciseProgress]
}

extension APIClient: VerlaufLoading {}

/// Haelt Verlauf, Kopfzeile und Fortschritt -- und den Zeitpunkt, an dem
/// sie zuletzt wirklich vom Server kamen.
///
/// @MainActor wie CatalogStore und KurseStore: der Store wird ueber
/// @Environment direkt in Views gelesen.
@MainActor
@Observable
final class VerlaufStore {
    private(set) var sessions: [SessionSummary] = []
    private(set) var summary: SessionsSummary?
    private(set) var fortschritt: [ExerciseProgress] = []
    private(set) var stand: Date?
    private(set) var ladeZustand: VerlaufLadeZustand = .bereit

    var herkunft: VerlaufHerkunft { VerlaufHerkunft.bilden(ladeZustand: ladeZustand) }

    /// Der Satz ueber dem ganzen Screen, nicht ueber einer einzelnen
    /// Zahl: ohne Netz driften "diese Woche" und "Tage her" mit der Uhr,
    /// waehrend die Liste darunter richtig bleibt. Ein datierter Screen
    /// ist ehrlicher als eine still wandernde Zahl.
    var satzUeberDemInhalt: String? { herkunft.satz(stand: stand) }

    #if DEBUG
    let loader: any VerlaufLoading
    #else
    private let loader: any VerlaufLoading
    #endif
    private let fileStore: VerlaufFileStore

    /// Steigt bei jedem laden(...) und bei reset(). Eine Antwort, die
    /// zurueckkommt, nachdem die Generation weitergezogen ist, ist
    /// ueberholt und wird verworfen -- sonst ueberschriebe sie einen
    /// frischeren oder kontofremden Zustand.
    private var generation = 0

    init(loader: any VerlaufLoading, fileStore: VerlaufFileStore) {
        self.loader = loader
        self.fileStore = fileStore

        if let gespeichert = fileStore.load() {
            sessions = gespeichert.sessions
            summary = gespeichert.summary
            fortschritt = gespeichert.fortschritt
            stand = gespeichert.stand
        }
    }

    /// Laedt Verlauf und Fortschritt. Scheitert einer der beiden Abrufe,
    /// bleibt der bisherige Stand vollstaendig stehen -- er ist nicht
    /// falsch geworden, nur aelter.
    func laden(studioId: String?) async {
        generation += 1
        let eigene = generation
        ladeZustand = .laedt

        do {
            // Nacheinander statt nebenlaeufig: zwei kleine Abrufe, und
            // `async let` gaebe den getippten APIError als `any Error`
            // zurueck -- der Unterschied offline/Serverfehler ginge dabei
            // verloren, und genau der traegt den Satz oben.
            let antwort = try await loader.sessions(studio: studioId)
            let punkte = try await loader.progress()
            guard eigene == generation else { return }

            let jetzt = Date()
            sessions = antwort.sessions
            summary = antwort.summary
            fortschritt = punkte
            stand = jetzt
            ladeZustand = .geladen
            fileStore.save(
                GespeicherterVerlauf(
                    stand: jetzt, sessions: antwort.sessions, summary: antwort.summary,
                    fortschritt: punkte))
        } catch {
            guard eigene == generation else { return }
            ladeZustand = .fehlgeschlagen(error)
        }
    }

    /// Nach dem Abmelden: sonst saehe das naechste Konto auf demselben
    /// Geraet den Verlauf des vorigen.
    func reset() {
        generation += 1
        sessions = []
        summary = nil
        fortschritt = []
        stand = nil
        ladeZustand = .bereit
        fileStore.save(nil)
    }
}
