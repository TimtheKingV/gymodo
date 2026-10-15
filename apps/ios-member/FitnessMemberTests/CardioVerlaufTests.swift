import Foundation
import Testing
@testable import FitnessMember

struct CardioVerlaufTests {
    private func satz(_ index: Int, cardio: CardioWerte?) -> SessionSummary.Block.Set {
        SessionSummary.Block.Set(
            setIndex: index, load: cardio == nil ? 50 : nil, secondaryLoad: nil,
            volume: cardio == nil ? 10 : nil, rir: nil, problemFlag: false, problemReason: nil,
            performedAt: "2026-09-01T10:00:00Z", cardio: cardio)
    }

    private func einheit(_ id: String, tag: Int, saetze: [SessionSummary.Block.Set],
                         uebung: String = "e1") -> SessionSummary {
        SessionSummary(
            id: id, startedAt: String(format: "2026-09-%02dT10:00:00Z", tag), completedAt: nil,
            completedReason: nil, machineCount: 1, setCount: saetze.count,
            blocks: [SessionSummary.Block(
                machineId: "m1", machineLabel: "Rudergerät", exerciseId: uebung, exerciseName: "Rudern",
                loadUnit: .level, secondaryUnit: nil, volumeKind: .seconds, sets: saetze)])
    }

    @Test func listetDenLetztenSatzJeEinheitNeuesteZuerst() throws {
        let v = try #require(CardioVerlauf.fuer(exerciseId: "e1", sessions: [
            einheit("a", tag: 1, saetze: [satz(1, cardio: CardioWerte(zeit: 300))]),
            einheit("b", tag: 3, saetze: [satz(1, cardio: CardioWerte(zeit: 400)),
                                          satz(2, cardio: CardioWerte(zeit: 510))]),
        ]))

        #expect(v.einheiten.map(\.werte) == [CardioWerte(zeit: 510), CardioWerte(zeit: 300)])
        #expect(v.machineLabel == "Rudergerät")
        #expect(v.exerciseName == "Rudern")
    }

    @Test func nimmtHoechstensZehnEinheiten() throws {
        let sessions = (1...12).map {
            einheit("s\($0)", tag: $0, saetze: [satz(1, cardio: CardioWerte(zeit: $0 * 60))])
        }
        let v = try #require(CardioVerlauf.fuer(exerciseId: "e1", sessions: sessions))
        #expect(v.einheiten.count == 10)
        #expect(v.einheiten.first?.werte == CardioWerte(zeit: 720))
    }

    @Test func eineUebungMitKraftUndCardioSaetzenBleibtBeimDiagramm() {
        let gemischt = [einheit("a", tag: 1, saetze: [satz(1, cardio: CardioWerte(zeit: 300)),
                                                      satz(2, cardio: nil)])]
        #expect(CardioVerlauf.fuer(exerciseId: "e1", sessions: gemischt) == nil)
    }

    @Test func eineKraftUebungOderEineUnbekannteHatKeinenCardioVerlauf() {
        let kraft = [einheit("a", tag: 1, saetze: [satz(1, cardio: nil)])]
        #expect(CardioVerlauf.fuer(exerciseId: "e1", sessions: kraft) == nil)
        #expect(CardioVerlauf.fuer(exerciseId: "x", sessions: kraft) == nil)
    }
}
