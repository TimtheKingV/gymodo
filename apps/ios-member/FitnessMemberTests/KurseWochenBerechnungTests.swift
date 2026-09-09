import Foundation
import Testing
@testable import FitnessMember

/// Rein deterministisch: kein `Date()`, kein `TimeZone.current` -- jeder
/// Zeitpunkt kommt aus `datum(...)`, jede Zeitzone ist fest "Europe/Berlin".
struct KurseWochenBerechnungTests {
    private let zeitzone = "Europe/Berlin"

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int, stunde: Int = 12) -> Date {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: zeitzone)!
        var komponenten = DateComponents()
        komponenten.year = jahr
        komponenten.month = monat
        komponenten.day = tag
        komponenten.hour = stunde
        return kalender.date(from: komponenten)!
    }

    // 2026-09-07 ist ein Montag, 2026-09-10 ein Donnerstag, 2026-09-13 ein
    // Sonntag (siehe KurseWochenBerechnungTests-Kommentare unten).

    @Test func montagIstDerMontagDerselbenWoche() {
        let donnerstag = datum(2026, 9, 10)
        let montag = KurseWochenBerechnung.montag(enthaelt: donnerstag, zeitzone: zeitzone)
        #expect(montag == datum(2026, 9, 7, stunde: 0))
    }

    /// Der Sonderfall: component(.weekday) liefert fuer Sonntag 1, nicht 8 --
    /// ohne den eigenen Zweig in KurseWochenBerechnung.montag rutschte der
    /// errechnete Montag eine Woche zu weit nach vorn.
    @Test func montagFunktioniertAuchAmSonntagSelbst() {
        let sonntag = datum(2026, 9, 13)
        let montag = KurseWochenBerechnung.montag(enthaelt: sonntag, zeitzone: zeitzone)
        #expect(montag == datum(2026, 9, 7, stunde: 0))
    }

    @Test func naechsterMontagIstGenauSiebenTageSpaeter() {
        let donnerstag = datum(2026, 9, 10)
        let montag = KurseWochenBerechnung.montag(enthaelt: donnerstag, zeitzone: zeitzone)
        let naechster = KurseWochenBerechnung.naechsterMontag(enthaelt: donnerstag, zeitzone: zeitzone)
        #expect(naechster == datum(2026, 9, 14, stunde: 0))
        #expect(naechster.timeIntervalSince(montag) == 7 * 86400)
    }

    @Test func wochentageSindSiebenTageMitGenauEinemHeute() {
        let donnerstag = datum(2026, 9, 10)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: donnerstag, zeitzone: zeitzone)

        #expect(tage.count == 7)
        #expect(tage.filter(\.istHeute).count == 1)
        #expect(tage.first(where: \.istHeute)?.id == "2026-09-10")
        #expect(tage.map(\.id) == [
            "2026-09-07", "2026-09-08", "2026-09-09", "2026-09-10",
            "2026-09-11", "2026-09-12", "2026-09-13",
        ])
        #expect(tage.map(\.kuerzel) == ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
    }

    @Test func wochentageStimmenAuchAmSonntagStartpunkt() {
        // jetzt liegt selbst am Sonntagende der Woche -- die zurueckgegebene
        // Woche muss trotzdem am Montag DERSELBEN Woche beginnen, nicht der
        // naechsten.
        let sonntag = datum(2026, 9, 13, stunde: 23)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: sonntag, zeitzone: zeitzone)

        #expect(tage.first?.id == "2026-09-07")
        #expect(tage.last?.id == "2026-09-13")
        #expect(tage.last?.istHeute == true)
    }

    @Test func wochentagVollUndTagesnummerStimmen() {
        let donnerstag = datum(2026, 9, 10)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: donnerstag, zeitzone: zeitzone)

        #expect(tage[3].wochentagVoll == "Donnerstag")
        #expect(tage[3].tagesnummer == 10)
    }
}
