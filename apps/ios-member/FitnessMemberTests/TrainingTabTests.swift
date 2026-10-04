import Foundation
import Testing
@testable import FitnessMember

/// Was in der Mitte des Training-Tabs steht -- und wann dort nichts steht.
struct TrainingTabTests {

    private let start = Date(timeIntervalSince1970: 1_757_930_400)

    private func satz(_ index: Int, minuten: Double) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, load: 50, volume: 10, rir: nil,
                    problemFlag: false, problemReason: nil,
                    performedAt: start.addingTimeInterval(minuten * 60))
    }

    @Test func dieBlockzeileNenntSaetzeUndDieWerteDesLetztenSatzes() {
        let presse = LokalerBlock(machineId: "m1", exerciseId: "e1",
                                  saetze: [satz(1, minuten: 0), satz(2, minuten: 3), satz(3, minuten: 6)])
        #expect(TrainingTab.blockzeile(presse) == "3 Sätze · 50,0 kg")

        let lauf = LokalerSatz(id: UUID(), setIndex: 1, load: 8.5, secondaryLoad: 6, volume: 1200,
                               problemFlag: false, problemReason: nil, performedAt: start)
        let laufband = LokalerBlock(machineId: "m9", exerciseId: "e9",
                                    einheiten: Blockeinheiten(loadUnit: .kmh, secondaryUnit: .pct, volumeKind: .seconds),
                                    saetze: [lauf])
        #expect(TrainingTab.blockzeile(laufband) == "1 Satz · 8,5 km/h · 6,0 %")

        let ergometer = LokalerBlock(machineId: "m8", exerciseId: "e8",
                                     einheiten: Blockeinheiten(loadUnit: .watt, secondaryUnit: nil, volumeKind: .seconds),
                                     saetze: [LokalerSatz(id: UUID(), setIndex: 1, load: 120, volume: 1500,
                                                          problemFlag: false, problemReason: nil, performedAt: start)])
        #expect(TrainingTab.blockzeile(ergometer) == "1 Satz · 120 W")
    }

    @Test func ohneSessionBleibtDieMitteLeer() {
        // Keine Uhr auf 00:00, keine "0 Geraete": ohne Training steht nichts da.
        #expect(TrainingTab.mitte(nil) == nil)
    }

    @Test func laufendeSessionTraegtStartUndZahlen() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, minuten: 0), satz(2, minuten: 3)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, minuten: 9)]),
        ])
        let mitte = try #require(TrainingTab.mitte(session))
        #expect(mitte.startedAt == start)
        #expect(mitte.zahlen == TrainingTab.Zahlen(geraete: 2, saetze: 3))
    }

    @Test func zweiUebungenAmSelbenGeraetSindEinGeraet() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, minuten: 0)]),
            LokalerBlock(machineId: "m1", exerciseId: "e2", saetze: [satz(1, minuten: 4)]),
        ])
        #expect(try #require(TrainingTab.mitte(session)).zahlen?.geraete == 1)
    }

    @Test func sessionOhneSatzZeigtUhrAberKeineZahlen() throws {
        // Seit Schnitt 4 entsteht die Einheit mit "Training starten" -- vor
        // dem ersten Satz steht die Uhr ohne Zahlen, nie "0 Saetze".
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        let mitte = try #require(TrainingTab.mitte(session))
        #expect(mitte.zahlen == nil)
    }

    @Test func zuletztBespieltesGeraetStehtOben() {
        // Zirkel: zurueck an m1 nach m2 -- dann ist m1 das juengste, obwohl
        // es zuerst angelegt wurde.
        let m1 = LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, minuten: 0), satz(2, minuten: 20)])
        let m2 = LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, minuten: 10)])
        #expect(TrainingTab.zuletztZuerst([m1, m2]).map(\.machineId) == ["m1", "m2"])
        #expect(TrainingTab.zuletztZuerst([m2, m1]).map(\.machineId) == ["m1", "m2"])
    }
}
