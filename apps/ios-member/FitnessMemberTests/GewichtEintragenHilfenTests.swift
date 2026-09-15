import Foundation
import Testing
@testable import FitnessMember

struct GewichtEintragenHilfenTests {
    private func wanduhrzeit(
        _ jahr: Int, _ monat: Int, _ tag: Int, _ stunde: Int, _ minute: Int, zeitzone: TimeZone
    ) -> Date {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        var teile = DateComponents()
        teile.year = jahr; teile.month = monat; teile.day = tag
        teile.hour = stunde; teile.minute = minute
        return kalender.date(from: teile)!
    }

    // MARK: - ortsdatum rechnet gegen die uebergebene Zeitzone, nicht UTC (R9)

    /// 21:00 Ortszeit am 14. September ist bereits 01:00 UTC am 15. -- ein
    /// UTC-Formatierer wuerde den 15. eintragen, obwohl das Mitglied noch
    /// am 14. steht.
    @Test func ortsdatumRechnetInAmerikaGegenDenOrtstagNichtGegenUTC() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let zeitpunkt = wanduhrzeit(2026, 9, 14, 21, 0, zeitzone: newYork)

        #expect(GewichtEintragenHilfen.ortsdatum(zeitpunkt, zeitzone: newYork) == "2026-09-14")
    }

    @Test func heuteIstDasOrtsdatumVonJetzt() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = wanduhrzeit(2026, 9, 15, 8, 0, zeitzone: berlin)

        #expect(GewichtEintragenHilfen.heute(jetzt: jetzt, zeitzone: berlin) == "2026-09-15")
    }

    // MARK: - datum(von:) ist die Umkehrung von ortsdatum

    @Test func datumUndOrtsdatumSindZueinanderInvers() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!

        let zurueck = GewichtEintragenHilfen.datum(von: "2026-08-01", zeitzone: berlin)

        #expect(zurueck.map { GewichtEintragenHilfen.ortsdatum($0, zeitzone: berlin) } == "2026-08-01")
    }

    @Test func einUngueltigerTagliefertKeinDatum() {
        #expect(GewichtEintragenHilfen.datum(von: "keine-angabe") == nil)
    }

    // MARK: - datumsZeile

    @Test func datumsZeileZeigtHeuteFuerDenHeutigenTag() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = wanduhrzeit(2026, 9, 13, 12, 0, zeitzone: berlin)

        #expect(GewichtEintragenHilfen.datumsZeile(jetzt, jetzt: jetzt, zeitzone: berlin) == "Heute, 13. September")
    }

    @Test func datumsZeileZeigtWochentagFuerEinenAndernTag() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = wanduhrzeit(2026, 9, 13, 12, 0, zeitzone: berlin)
        let alterTag = wanduhrzeit(2026, 8, 27, 12, 0, zeitzone: berlin)

        #expect(GewichtEintragenHilfen.datumsZeile(alterTag, jetzt: jetzt, zeitzone: berlin) == "Donnerstag, 27. August")
    }

    // MARK: - kontextZeile

    @Test func kontextZeileOhneLetztenMesswertZeigtNurDenSchritt() {
        #expect(GewichtEintragenHilfen.kontextZeile(letzterMesswert: nil) == "Schritt 0,5 kg")
    }

    @Test func kontextZeileMitLetztemMesswertNenntWertUndDatum() {
        let letzter = Messwert(measuredOn: "2026-09-10", weightKg: 83.0)

        // "10. Sept." -- so, wie Zahlformat.tagMonatKurz den September
        // tatsaechlich abkuerzt (de_DE liefert hier vier Buchstaben plus
        // Punkt, nicht drei); das Artboard-Beispiel "10. Sep" ist insofern
        // ungenau.
        #expect(
            GewichtEintragenHilfen.kontextZeile(letzterMesswert: letzter)
                == "Schritt 0,5 kg · zuletzt 83,0 am 10. Sept.")
    }
}
