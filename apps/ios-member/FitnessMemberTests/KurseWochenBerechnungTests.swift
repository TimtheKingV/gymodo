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

    // MARK: - Monats-, Jahres- und Sommerzeitwechsel
    //
    // Die drei Faelle, in denen eine Woche nicht "sieben mal 86400 Sekunden
    // ab Montag" ist. Der Screen gruppiert seine Termine ueber die
    // Tages-Id gegen `CourseWeekSession.localDay`; kippt eine Id an einer
    // dieser Grenzen, verschwinden die Kurse eines Tages wortlos.

    @Test func eineWocheUeberDenMonatswechsel() {
        // Mittwoch, 30.09.2026 -- die Woche laeuft von Mo 28.09. bis
        // So 04.10.
        let mittwoch = datum(2026, 9, 30)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: mittwoch, zeitzone: zeitzone)

        #expect(tage.map(\.id) == [
            "2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01",
            "2026-10-02", "2026-10-03", "2026-10-04",
        ])
        #expect(tage.first(where: \.istHeute)?.id == "2026-09-30")
        #expect(tage[3].tagesnummer == 1)
        #expect(KurseWochenBerechnung.naechsterMontag(enthaelt: mittwoch, zeitzone: zeitzone)
                == datum(2026, 10, 5, stunde: 0))
    }

    @Test func eineWocheUeberDenJahreswechsel() {
        // Donnerstag, 31.12.2026 -- die Woche laeuft von Mo 28.12.2026 bis
        // So 03.01.2027.
        let silvester = datum(2026, 12, 31)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: silvester, zeitzone: zeitzone)

        #expect(tage.map(\.id) == [
            "2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31",
            "2027-01-01", "2027-01-02", "2027-01-03",
        ])
        #expect(tage.first(where: \.istHeute)?.id == "2026-12-31")
        #expect(KurseWochenBerechnung.montag(enthaelt: silvester, zeitzone: zeitzone)
                == datum(2026, 12, 28, stunde: 0))
        #expect(KurseWochenBerechnung.naechsterMontag(enthaelt: silvester, zeitzone: zeitzone)
                == datum(2027, 1, 4, stunde: 0))
    }

    @Test func derSonntagDerZeitumstellungImFruehjahrBleibtDerSiebteTag() {
        // In der Nacht auf Sonntag, 29.03.2026, springt Europe/Berlin von
        // 02:00 auf 03:00 -- dieser Tag hat 23 Stunden.
        let sonntag = datum(2026, 3, 29, stunde: 12)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: sonntag, zeitzone: zeitzone)

        #expect(tage.map(\.id) == [
            "2026-03-23", "2026-03-24", "2026-03-25", "2026-03-26",
            "2026-03-27", "2026-03-28", "2026-03-29",
        ])
        #expect(tage.last?.istHeute == true)

        // Das Anfragefenster ist eine KALENDERwoche, keine 604800 Sekunden:
        // durch die verlorene Stunde sind es hier eine Stunde weniger. Mit
        // fester Sekundenrechnung faenge das Fenster am Sonntag um 01:00 an
        // zu enden, und die Kurse des Sonntagabends fielen heraus.
        let montag = KurseWochenBerechnung.montag(enthaelt: sonntag, zeitzone: zeitzone)
        let naechster = KurseWochenBerechnung.naechsterMontag(enthaelt: sonntag, zeitzone: zeitzone)
        #expect(montag == datum(2026, 3, 23, stunde: 0))
        #expect(naechster == datum(2026, 3, 30, stunde: 0))
        #expect(naechster.timeIntervalSince(montag) == 7 * 86400 - 3600)
    }

    @Test func derSonntagDerZeitumstellungImHerbstBleibtDerSiebteTag() {
        // In der Nacht auf Sonntag, 25.10.2026, springt Europe/Berlin von
        // 03:00 auf 02:00 zurueck -- dieser Tag hat 25 Stunden.
        let sonntag = datum(2026, 10, 25, stunde: 12)
        let tage = KurseWochenBerechnung.wochentage(enthaelt: sonntag, zeitzone: zeitzone)

        #expect(tage.map(\.id) == [
            "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22",
            "2026-10-23", "2026-10-24", "2026-10-25",
        ])
        #expect(tage.last?.istHeute == true)

        let montag = KurseWochenBerechnung.montag(enthaelt: sonntag, zeitzone: zeitzone)
        let naechster = KurseWochenBerechnung.naechsterMontag(enthaelt: sonntag, zeitzone: zeitzone)
        #expect(naechster.timeIntervalSince(montag) == 7 * 86400 + 3600)
    }

    @Test func derTagWechseltUmMitternacht() {
        // Der Weg aus der Schlussdurchsicht: die App liegt ueber
        // Mitternacht auf dem Kurse-Tab. Um 23:59 ist Donnerstag heute, um
        // 00:01 Freitag -- und in der Woche eines Monatsletzten wechselt
        // dabei auch die Woche.
        let kurzVorMitternacht = datum(2026, 9, 10, stunde: 23)
        let kurzNach = datum(2026, 9, 11, stunde: 0)

        #expect(KurseWochenBerechnung.wochentage(enthaelt: kurzVorMitternacht, zeitzone: zeitzone)
                .first(where: \.istHeute)?.id == "2026-09-10")
        #expect(KurseWochenBerechnung.wochentage(enthaelt: kurzNach, zeitzone: zeitzone)
                .first(where: \.istHeute)?.id == "2026-09-11")

        // Und ueber den Wochenwechsel hinweg: Sonntag 23:00 -> Montag 00:00
        // ist eine ANDERE Woche, nicht bloss ein anderer Tag.
        let sonntagSpaet = datum(2026, 9, 13, stunde: 23)
        let montagFrueh = datum(2026, 9, 14, stunde: 0)
        #expect(KurseWochenBerechnung.montag(enthaelt: sonntagSpaet, zeitzone: zeitzone)
                == datum(2026, 9, 7, stunde: 0))
        #expect(KurseWochenBerechnung.montag(enthaelt: montagFrueh, zeitzone: zeitzone)
                == datum(2026, 9, 14, stunde: 0))
    }
}
