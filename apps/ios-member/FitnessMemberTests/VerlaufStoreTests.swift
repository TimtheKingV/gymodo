import Foundation
import Testing
@testable import FitnessMember

/// Dateiweit, nicht als statische Eigenschaft der Suite: die
/// Attrappe unten ist ein verschachtelter Typ und kaeme an eine
/// Eigenschaft der aeusseren Struktur nicht heran.
private let leereKopfzeile = SessionsSummary(
    totalCount: 0, thisWeekCount: nil, lastSessionAt: nil)

@MainActor
struct VerlaufStoreTests {
    /// Eine Attrappe, deren naechste Antwort der Test setzt -- dasselbe
    /// Muster wie in KurseStoreTests.
    final class FakeLoader: VerlaufLoading, @unchecked Sendable {
        var antwort: SessionsResponse?
        var fortschritt: [ExerciseProgress] = []
        var fehler: APIError?
        var abrufe = 0

        func sessions(studio: String?) async throws(APIError) -> SessionsResponse {
            abrufe += 1
            if let fehler { throw fehler }
            return antwort ?? SessionsResponse(sessions: [], summary: leereKopfzeile)
        }

        func progress() async throws(APIError) -> [ExerciseProgress] {
            if let fehler { throw fehler }
            return fortschritt
        }
    }

    private func store(
        _ loader: FakeLoader, verzeichnis: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    ) -> VerlaufStore {
        VerlaufStore(loader: loader, fileStore: VerlaufFileStore(directory: verzeichnis))
    }

    private func einheit(id: String = "s1") -> SessionSummary {
        SessionSummary(
            id: id, startedAt: "2026-09-08T16:04:00Z", completedAt: "2026-09-08T16:51:00Z",
            completedReason: "manual", machineCount: 3, setCount: 8, blocks: [])
    }

    @Test func einGelungenerAbrufFuelltDenStore() async {
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()],
            summary: SessionsSummary(totalCount: 34, thisWeekCount: 2, lastSessionAt: nil))
        let verlauf = store(loader)

        await verlauf.laden(studioId: "st1")

        #expect(verlauf.sessions.count == 1)
        #expect(verlauf.summary?.totalCount == 34)
        #expect(verlauf.herkunft == .frisch)
        #expect(verlauf.stand != nil)
    }

    /// Der Kern der Aufgabe: der Keller. Was einmal geladen war, bleibt
    /// stehen -- und traegt darueber ein ehrliches Datum.
    @Test func einFehlgeschlagenerAbrufLaesstDenStandStehen() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()], summary: leereKopfzeile)
        let erster = store(loader, verzeichnis: verzeichnis)
        await erster.laden(studioId: "st1")

        let zweiterLoader = FakeLoader()
        zweiterLoader.fehler = .offline
        let zweiter = store(zweiterLoader, verzeichnis: verzeichnis)
        await zweiter.laden(studioId: "st1")

        #expect(zweiter.sessions.count == 1)
        #expect(zweiter.herkunft == .ohneEmpfang)
        #expect(zweiter.satzUeberDemInhalt?.hasPrefix("Ohne Empfang.") == true)
    }

    @Test func derCacheStehtSchonVorDemErstenAbruf() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()], summary: leereKopfzeile)
        await store(loader, verzeichnis: verzeichnis).laden(studioId: nil)

        let neuerStart = store(FakeLoader(), verzeichnis: verzeichnis)

        #expect(neuerStart.sessions.count == 1)
        #expect(neuerStart.ladeZustand == .bereit)
    }

    /// Nach dem Abmelden darf vom vorigen Konto nichts stehen bleiben --
    /// dieselbe Regel wie in CatalogStore.reset().
    @Test func resetRaeumtSpeicherUndPlatte() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()], summary: leereKopfzeile)
        let verlauf = store(loader, verzeichnis: verzeichnis)
        await verlauf.laden(studioId: nil)

        verlauf.reset()

        #expect(verlauf.sessions.isEmpty)
        #expect(store(FakeLoader(), verzeichnis: verzeichnis).sessions.isEmpty)
    }
}
