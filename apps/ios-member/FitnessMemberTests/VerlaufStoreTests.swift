import Foundation
import Testing
@testable import FitnessMember

/// Dateiweit, nicht als statische Eigenschaft der Suite: die
/// Attrappe unten ist ein verschachtelter Typ und kaeme an eine
/// Eigenschaft der aeusseren Struktur nicht heran.
private let leereKopfzeile = SessionsSummary(
    totalCount: 0, thisWeekCount: nil, lastSessionAt: nil, streak: nil)

@MainActor
struct VerlaufStoreTests {
    /// Eine Attrappe, deren naechste Antwort der Test setzt -- dasselbe
    /// Muster wie in KurseStoreTests.
    final class FakeLoader: VerlaufLoading, @unchecked Sendable {
        var antwort: SessionsResponse?
        var fortschritt: [ExerciseProgress] = []
        var messwerte: MeasurementsResponse?
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

        func measurements() async throws(APIError) -> MeasurementsResponse {
            if let fehler { throw fehler }
            return messwerte
                ?? MeasurementsResponse(points: [], summary: .init(first: nil, latest: nil, changeKg: nil))
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
            summary: SessionsSummary(
                totalCount: 34, thisWeekCount: 2, lastSessionAt: nil, streak: nil))
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
        loader.messwerte = MeasurementsResponse(
            points: [Messwert(measuredOn: "2026-09-01", weightKg: 80.0)],
            summary: .init(
                first: Messwert(measuredOn: "2026-09-01", weightKg: 80.0),
                latest: Messwert(measuredOn: "2026-09-01", weightKg: 80.0), changeKg: 0))
        let verlauf = store(loader, verzeichnis: verzeichnis)
        await verlauf.laden(studioId: nil)

        verlauf.reset()

        #expect(verlauf.sessions.isEmpty)
        #expect(verlauf.messwerte.isEmpty)
        #expect(verlauf.messwertKopf == nil)
        #expect(store(FakeLoader(), verzeichnis: verzeichnis).sessions.isEmpty)
    }

    /// Der dritte Abruf im selben laden(...) -- die Gewichtskarte auf
    /// Home braucht keinen eigenen Ladepfad.
    @Test func ladenFuelltMesswerteUndKopfzeile() async {
        let loader = FakeLoader()
        loader.messwerte = MeasurementsResponse(
            points: [
                Messwert(measuredOn: "2026-08-01", weightKg: 80.0),
                Messwert(measuredOn: "2026-08-15", weightKg: 78.5),
                Messwert(measuredOn: "2026-09-01", weightKg: 77.0),
            ],
            summary: .init(
                first: Messwert(measuredOn: "2026-08-01", weightKg: 80.0),
                latest: Messwert(measuredOn: "2026-09-01", weightKg: 77.0), changeKg: -3.0))
        let verlauf = store(loader)

        await verlauf.laden(studioId: "st1")

        #expect(verlauf.messwerte.count == 3)
        #expect(verlauf.messwertKopf?.changeKg == -3.0)
    }

    /// Ein Cache von vor dieser Fassung kennt weder `messwerte` noch
    /// `messwertKopf` -- beide Felder sind optional, genau dafuer.
    @Test func alterCacheOhneMesswerteDekodiertWeiter() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: verzeichnis, withIntermediateDirectories: true)
        let alterCache = """
        {"stand":800000000,"sessions":[],"summary":{"totalCount":0,"thisWeekCount":null,"lastSessionAt":null,"streak":null},"fortschritt":[]}
        """
        try? Data(alterCache.utf8).write(to: verzeichnis.appendingPathComponent("verlauf.json"))

        let verlauf = store(FakeLoader(), verzeichnis: verzeichnis)

        #expect(verlauf.stand != nil)
        #expect(verlauf.messwerte.isEmpty)
        #expect(verlauf.messwertKopf == nil)
    }

    /// Ersetzt den Punkt desselben Tages statt einen zweiten anzuhaengen,
    /// und haelt die Liste aufsteigend sortiert.
    @Test func messwertEintragenErsetztDenselbenTagUndSortiert() async {
        let verlauf = store(FakeLoader())
        await verlauf.laden(studioId: nil)

        verlauf.messwertEintragen(MesswertAntwort(measuredOn: "2026-09-01", weightKg: 80.0, goalReached: false))
        verlauf.messwertEintragen(MesswertAntwort(measuredOn: "2026-08-15", weightKg: 78.0, goalReached: false))
        verlauf.messwertEintragen(MesswertAntwort(measuredOn: "2026-09-01", weightKg: 79.0, goalReached: false))

        #expect(verlauf.messwerte.count == 2)
        #expect(verlauf.messwerte.map(\.measuredOn) == ["2026-08-15", "2026-09-01"])
        #expect(verlauf.messwerte.last?.weightKg == 79.0)
        #expect(verlauf.messwertKopf?.changeKg == 1.0)
    }

    /// messwertEntfernen zieht dieselbe Kopfzeile nach wie messwertEintragen.
    @Test func messwertEntfernenZiehtDieKopfzeileNach() async {
        let verlauf = store(FakeLoader())
        await verlauf.laden(studioId: nil)
        verlauf.messwertEintragen(MesswertAntwort(measuredOn: "2026-09-01", weightKg: 80.0, goalReached: false))
        verlauf.messwertEintragen(MesswertAntwort(measuredOn: "2026-08-15", weightKg: 78.0, goalReached: false))

        verlauf.messwertEntfernen(measuredOn: "2026-09-01")

        #expect(verlauf.messwerte.map(\.measuredOn) == ["2026-08-15"])
        #expect(verlauf.messwertKopf?.changeKg == 0)
    }
}
