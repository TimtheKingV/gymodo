import Foundation
import Testing
@testable import FitnessMember

struct MuskelAuswertungTests {
    private let jetzt = Date(timeIntervalSince1970: 1_792_000_000)

    private let muskeln: [String: [GeraetMuskel]] = [
        "rudern": [GeraetMuskel(key: "lats", name: "Lats", role: .primary)],
    ]

    private func tag(_ zurueck: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: jetzt.addingTimeInterval(-Double(zurueck) * 86_400))
    }

    private func session(tageZurueck: Double) -> SessionSummary {
        let start = ISO8601DateFormatter().string(from: jetzt.addingTimeInterval(-tageZurueck * 86_400))
        let block = SessionSummary.Block(
            machineId: nil, machineLabel: "M", exerciseId: "rudern", exerciseName: "Rudern",
            loadUnit: .kg, secondaryUnit: nil, volumeKind: .reps,
            sets: [SessionSummary.Block.Set(setIndex: 0, load: 50, secondaryLoad: nil, volume: 10, rir: nil,
                                            problemFlag: false, problemReason: nil, performedAt: start)])
        return SessionSummary(id: UUID().uuidString, startedAt: start, completedAt: nil, completedReason: nil,
                              machineCount: 1, setCount: 1, blocks: [block])
    }

    @Test func berechneVerbindetHaeufigkeitUndFortschritt() {
        let uebung = ExerciseProgress(
            id: "rudern", exerciseName: "Rudern", machineLabel: "M", loadUnit: .kg, volumeKind: .reps,
            firstLoad: 0, currentLoad: 0, changeLoad: 0,
            points: [(90, 40.0), (80, 50), (20, 55), (2, 60)].map {
                .init(performedOn: tag($0.0), topLoad: $0.1, volume: 10)
            })
        let a = MuskelAuswertung.berechne(
            sessions: [session(tageZurueck: 1), session(tageZurueck: 5), session(tageZurueck: 9)],
            fortschritt: [uebung], muskeln: muskeln, jetzt: jetzt)
        #expect(a.haeufigkeit.istAuswertbar == true)
        #expect(a.fortschritt.jeGruppe[.ruecken] != nil)
    }

    @Test func leererVerlaufIstNichtAuswertbar() {
        let a = MuskelAuswertung.berechne(sessions: [], fortschritt: [], muskeln: muskeln, jetzt: jetzt)
        #expect(a.haeufigkeit.istAuswertbar == false)
        #expect(a.fortschritt.jeGruppe.isEmpty)
    }

    @Test func reineNebenmuskelnVersprechenKeinenLastfortschritt() {
        let muskeln = ["rudern": [
            GeraetMuskel(key: "lats", name: "Lats", role: .primary),
            GeraetMuskel(key: "serratus_anterior", name: "Serratus", role: .secondary)
        ]]
        let a = MuskelAuswertung.berechne(
            sessions: [session(tageZurueck: 1), session(tageZurueck: 5), session(tageZurueck: 9)],
            fortschritt: [], muskeln: muskeln, jetzt: jetzt)
        #expect(a.brauchtTrainings(muskel: "lats", wert: .keinWert))
        #expect(!a.brauchtTrainings(muskel: "serratus_anterior", wert: .keinWert))
        #expect(!a.brauchtTrainings(muskel: "lats", wert: .stabil))
    }
}
