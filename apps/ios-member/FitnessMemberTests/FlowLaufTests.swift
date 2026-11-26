import Foundation
import Testing
@testable import FitnessMember

/// Der Lauf-Zustand: Uhr-basiert (jetzt - start - pausiert), nicht tick-basiert.
@MainActor
struct FlowLaufTests {

    /// Steuerbare Uhr.
    private final class Uhr: @unchecked Sendable {
        var jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        func weiter(_ s: Double) { jetzt = jetzt.addingTimeInterval(s) }
    }

    /// Drei Schritte 40/20, 40/20, 40/0 -- 160 s plus 3 s Countdown.
    private func flow() -> Flow {
        func schritt(_ n: Int, rest: Int) -> FlowSchritt {
            FlowSchritt(position: n, name: "S\(n)", beschreibung: nil, workS: 40, restS: rest, istWarmup: false)
        }
        return Flow(id: "flow-1", studioId: "st", key: "k", titel: "T", beschreibung: nil, level: nil,
                    schritte: [schritt(1, rest: 20), schritt(2, rest: 20), schritt(3, rest: 0)], dauerS: 160)
    }

    private func lauf(_ uhr: Uhr) -> FlowLauf {
        FlowLauf(flow: flow(), jetzt: { uhr.jetzt })
    }

    @Test func startBeginntMitCountdown() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        #expect(l.zustand == .countdown(restS: 3))
    }

    @Test func nachFuenfSekundenArbeitIstSchrittEins() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        uhr.weiter(5)
        #expect(l.zustand == .arbeit(schritt: 0, restS: 38))
    }

    @Test func pauseUndFortsetzenLaesstRestzeitUnveraendert() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        uhr.weiter(5)
        l.pausieren()
        uhr.weiter(10)
        #expect(l.zustand == .arbeit(schritt: 0, restS: 38))
        l.fortsetzen()
        #expect(l.zustand == .arbeit(schritt: 0, restS: 38))
        uhr.weiter(8)
        #expect(l.zustand == .arbeit(schritt: 0, restS: 30))
    }

    @Test func abbrechenImCountdownLiefertNil() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        uhr.weiter(1)
        #expect(l.abbrechen() == nil)
    }

    @Test func abbrechenInSchrittDreiLiefertAbgebrochenMitLetztemSchritt() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        uhr.weiter(3 + 40 + 20 + 40 + 20 + 5) // Schritt 3 beginnt bei 123 s
        let run = l.abbrechen()
        #expect(run?.outcome == "aborted")
        #expect(run?.lastStep == 3)
        #expect(run?.flowId == "flow-1")
    }

    @Test func abbrechenInDerPauseZaehltDenBeendetenSchritt() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        uhr.weiter(3 + 40 + 5) // Pause nach Schritt 1
        #expect(l.abbrechen()?.lastStep == 1)
    }

    @Test func alleSchritteVorbeiLiefertFinished() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        #expect(l.abgeschlossenerRun() == nil)
        uhr.weiter(163)
        #expect(l.zustand == .fertig)
        let run = l.abgeschlossenerRun()
        #expect(run?.outcome == "finished")
        #expect(run?.lastStep == 3)
    }

    @Test func uhrSpringtFuenfMinutenVorLiefertFertigOhneAbsturz() {
        let uhr = Uhr()
        let l = lauf(uhr)
        l.starten()
        uhr.weiter(5)
        uhr.weiter(300)
        #expect(l.zustand == .fertig)
        #expect(l.abgeschlossenerRun()?.lastStep == 3)
    }
}
