import Foundation
import Testing
@testable import FitnessMember

struct FortschrittsfensterTests {
    private let jetzt = ISO8601DateFormatter().date(from: "2026-09-09T12:00:00Z")!

    private func punkt(_ tag: String, _ kg: Double) -> ExerciseProgress.Point {
        ExerciseProgress.Point(performedOn: tag, topWeightKg: kg, reps: 10)
    }

    private var alle: [ExerciseProgress.Point] {
        [punkt("2026-01-15", 60), punkt("2026-05-02", 70), punkt("2026-08-27", 80)]
    }

    @Test func dreiMonateSchneidetAelteresAb() {
        let gefiltert = Fortschrittsfenster.dreiMonate.punkte(alle, jetzt: jetzt)

        #expect(gefiltert.map(\.performedOn) == ["2026-08-27"])
    }

    @Test func sechsMonateNimmtMehrMit() {
        let gefiltert = Fortschrittsfenster.sechsMonate.punkte(alle, jetzt: jetzt)

        #expect(gefiltert.count == 2)
    }

    @Test func allesLaesstNichtsWeg() {
        #expect(Fortschrittsfenster.alles.punkte(alle, jetzt: jetzt).count == 3)
    }

    /// Dieselbe Filterung, generisch ueber `Datiert` (Brief Step 1): ein
    /// `Messwert` traegt seinen Tag als `measuredOn` statt `performedOn`,
    /// und `punkte(_:jetzt:)` muss dafuer keine zweite Fassung brauchen.
    @Test func punkteFiltertAuchMesswerte() {
        let messwerte = [
            Messwert(measuredOn: "2026-01-15", weightKg: 84),
            Messwert(measuredOn: "2026-08-27", weightKg: 82.5),
        ]

        let gefiltert = Fortschrittsfenster.dreiMonate.punkte(messwerte, jetzt: jetzt)

        #expect(gefiltert.map(\.measuredOn) == ["2026-08-27"])
    }

    /// designsystem.md SS13: die Achse beginnt NICHT bei null --
    /// Trainingsgewichte bewegen sich in einem schmalen Band, und eine
    /// Nullachse macht jeden Fortschritt unsichtbar.
    @Test func dieAchseBeginntNichtBeiNull() {
        let bereich = Fortschrittsfenster.achsenbereich(alle.map(\.topWeightKg))

        #expect(bereich.lowerBound > 0)
        #expect(bereich.lowerBound < 60)
        #expect(bereich.upperBound > 80)
    }

    /// Ein einziger Punkt darf keinen Bereich der Breite null ergeben --
    /// die Kurve verschwaende sonst in einer Linie ohne Achse.
    @Test func einEinzelnerPunktBekommtTrotzdemEinenBereich() {
        let bereich = Fortschrittsfenster.achsenbereich([80])

        #expect(bereich.lowerBound < 80)
        #expect(bereich.upperBound > 80)
    }

    @Test func ohnePunkteGibtEsEinenUnauffaelligenBereich() {
        let bereich = Fortschrittsfenster.achsenbereich([])

        #expect(bereich.lowerBound < bereich.upperBound)
    }

    /// Leichte Gewichte (Isolationsuebungen, Kabelzug) sind Alltagsdaten,
    /// kein Sonderfall -- der feste 2,5-kg-Mindestrand darf die Achse
    /// hier nicht auf oder unter null druecken (SS13, ohne Ausnahme).
    @Test func leichteGewichteBleibenUeberNull() {
        let bereich = Fortschrittsfenster.achsenbereich([2.5, 5.0])

        #expect(bereich.lowerBound > 0)
        #expect(bereich.upperBound > 5.0)
    }

    @Test func einEinzelnerLeichterPunktBleibtUeberNull() {
        let bereich = Fortschrittsfenster.achsenbereich([2.5])

        #expect(bereich.lowerBound > 0)
        #expect(bereich.upperBound > 2.5)
    }

    /// Der Gewichtsverlauf (Aufgabe 9) rechnet das Zielgewicht MIT in den
    /// Bereich ein -- sonst faellt die gestrichelte Ziellinie aus der
    /// sichtbaren Achse. `achsenbereich` nimmt dafuer rohe Werte statt
    /// Punkte: der Aufrufer haengt das Ziel einfach an die Liste an.
    @Test func derBereichKannEinZielgewichtAusserhalbDerWerteEinschliessen() {
        let bereich = Fortschrittsfenster.achsenbereich([82.5, 83.0, 84.5, 78.0])

        #expect(bereich.lowerBound < 78.0)
        #expect(bereich.upperBound > 84.5)
    }
}
