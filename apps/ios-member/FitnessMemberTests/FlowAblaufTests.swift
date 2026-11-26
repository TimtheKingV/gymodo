import Testing
@testable import FitnessMember

/// Die Zeitmaschine des Follow-along-Flows: Zustand nur aus vergangenen Sekunden.
struct FlowAblaufTests {

    /// Drei Schritte 40/20, 40/20, 40/0 -- 160 s plus 3 s Countdown.
    private func ablauf() -> FlowAblauf {
        func schritt(_ n: Int, rest: Int) -> FlowSchritt {
            FlowSchritt(position: n, name: "S\(n)", beschreibung: nil, workS: 40, restS: rest, istWarmup: false)
        }
        return FlowAblauf(schritte: [schritt(1, rest: 20), schritt(2, rest: 20), schritt(3, rest: 0)])
    }

    @Test func gesamtdauerOhneCountdown() {
        #expect(ablauf().gesamtS == 160)
        #expect(FlowAblauf.countdownS == 3)
    }

    @Test func countdownZaehltAufgerundetRunter() {
        #expect(ablauf().zustand(nachS: 0) == .countdown(restS: 3))
        #expect(ablauf().zustand(nachS: 2.1) == .countdown(restS: 1))
    }

    @Test func ersterSchrittBeginntNachDemCountdown() {
        #expect(ablauf().zustand(nachS: 3.0) == .arbeit(schritt: 0, restS: 40))
        #expect(ablauf().zustand(nachS: 42.9) == .arbeit(schritt: 0, restS: 1))
    }

    @Test func pauseFolgtAufArbeit() {
        #expect(ablauf().zustand(nachS: 43.0) == .pause(naechster: 1, restS: 20))
    }

    @Test func naechsteSchritteNachPause() {
        #expect(ablauf().zustand(nachS: 63.0) == .arbeit(schritt: 1, restS: 40))
        #expect(ablauf().zustand(nachS: 123.0) == .arbeit(schritt: 2, restS: 40))
    }

    @Test func letzterSchrittOhnePauseEndetFertig() {
        #expect(ablauf().zustand(nachS: 162.9) == .arbeit(schritt: 2, restS: 1))
        #expect(ablauf().zustand(nachS: 163.0) == .fertig)
        #expect(ablauf().zustand(nachS: 500) == .fertig)
    }

    @Test func negativeEingabeWieNull() {
        #expect(ablauf().zustand(nachS: -5) == ablauf().zustand(nachS: 0))
    }
}
