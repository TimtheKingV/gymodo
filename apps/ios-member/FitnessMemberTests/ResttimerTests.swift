import Foundation
import Testing
@testable import FitnessMember

struct ResttimerTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func neunzigSekundenAbStart() {
        let timer = Resttimer(start: start)
        #expect(timer.restsekunden(jetzt: start) == 90)
    }

    @Test func rechnetAusDerUhrzeitUndNichtAusEinemZaehler() {
        // "Laeuft weiter, auch wenn du wegsiehst" -- ueber Hintergrund und
        // Sperrbildschirm haelt nur ein gespeicherter Endzeitpunkt.
        let timer = Resttimer(start: start)
        #expect(timer.restsekunden(jetzt: start.addingTimeInterval(18)) == 72)
    }

    @Test func laeuftNichtInsNegative() {
        let timer = Resttimer(start: start)
        #expect(timer.restsekunden(jetzt: start.addingTimeInterval(120)) == 0)
        #expect(timer.laeuft(jetzt: start.addingTimeInterval(120)) == false)
        #expect(timer.laeuft(jetzt: start.addingTimeInterval(10)))
    }

    @Test func anteilLaeuftVonEinsNachNull() {
        let timer = Resttimer(start: start)
        #expect(timer.anteil(jetzt: start) == 1.0)
        #expect(abs(timer.anteil(jetzt: start.addingTimeInterval(45)) - 0.5) < 0.001)
        #expect(timer.anteil(jetzt: start.addingTimeInterval(200)) == 0.0)
    }

    @Test func verlaengernSchiebtDenEndzeitpunkt() {
        let timer = Resttimer(start: start).verlaengert()
        #expect(timer.restsekunden(jetzt: start) == 120)
    }

    @Test func anteilFriertNachVerlaengernNichtBei100ProzentEin() {
        // Vorher: anteil() teilte durch die feste Self.dauer (90) --
        // gleich zu Beginn verlaengert (120 Restsekunden bei 90 Sekunden
        // Gesamtdauer) blieb der Balken 30 Sekunden lang bei 1.0 stehen,
        // waehrend die Ziffern schon runterzaehlten.
        let timer = Resttimer(start: start).verlaengert()
        #expect(timer.gesamtdauer == 120)
        #expect(timer.anteil(jetzt: start) == 1.0)

        // Nach 15 von 120 Sekunden: 105/120, nicht min(1, 105/90).
        let danach = start.addingTimeInterval(15)
        #expect(abs(timer.anteil(jetzt: danach) - 105.0 / 120.0) < 0.001)
    }

    @Test func gesamtdauerOhneVerlaengerungIstDieFesteDauer() {
        let timer = Resttimer(start: start)
        #expect(timer.gesamtdauer == Resttimer.dauer)
    }

    @Test func dieAnsageNenntMinutenUndSekunden() {
        // designsystem.md SS12: "Pause, noch 1 Minute 12 Sekunden"
        let timer = Resttimer(start: start)
        #expect(timer.gesprochen(start.addingTimeInterval(18)) == "Pause, noch 1 Minute 12 Sekunden")
        #expect(timer.gesprochen(start.addingTimeInterval(45)) == "Pause, noch 45 Sekunden")
        #expect(timer.gesprochen(start.addingTimeInterval(30)) == "Pause, noch 1 Minute")
        #expect(timer.gesprochen(start.addingTimeInterval(90)) == "Pause beendet")
    }
}
