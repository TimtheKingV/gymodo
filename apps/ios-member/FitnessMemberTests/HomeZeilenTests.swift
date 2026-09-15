import Foundation
import Testing
@testable import FitnessMember

struct HomeZeilenTests {
    private func einheit(
        id: String = "s1",
        startedAt: String = "2026-09-08T16:04:00Z",
        completedAt: String? = "2026-09-08T16:51:00Z",
        completedReason: String? = "manual",
        machineCount: Int = 3,
        setCount: Int = 8
    ) -> SessionSummary {
        SessionSummary(
            id: id, startedAt: startedAt, completedAt: completedAt,
            completedReason: completedReason, machineCount: machineCount, setCount: setCount, blocks: [])
    }

    /// Was heute noch laeuft, ist kein Verlauf -- die laufende Einheit
    /// steht im Training-Tab.
    @Test func dieLaufendeEinheitStehtNichtImVerlauf() {
        let zeilen = HomeZeilen.abgeschlossene([
            einheit(id: "laeuft", completedAt: nil, completedReason: nil),
            einheit(id: "fertig"),
        ])

        #expect(zeilen.map(\.id) == ["fertig"])
    }

    @Test func eineBeendeteEinheitZeigtIhreDauer() {
        #expect(HomeZeilen.dauerText(einheit()) == "47 min")
    }

    /// getSessions setzt das Ende einer vergessenen Einheit auf den
    /// letzten Satz -- die daraus gerechnete Dauer ist eine Untergrenze,
    /// keine Dauer. Das Artboard laesst sie deshalb weg.
    @Test func eineSelbsttaetigBeendeteEinheitZeigtKeineDauer() {
        #expect(HomeZeilen.dauerText(einheit(completedReason: "auto")) == nil)
    }

    @Test func tageHerZaehltKalendertage() {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = Date(timeIntervalSince1970: 1_757_500_000)
        let vorbei = jetzt.addingTimeInterval(-3 * 24 * 60 * 60)

        let iso = ISO8601DateFormatter().string(from: vorbei)
        #expect(HomeZeilen.tageHer(iso, jetzt: jetzt, kalender: kalender) == 3)
    }

    @Test func ohneEinheitGibtEsKeineTageHer() {
        #expect(HomeZeilen.tageHer(nil, jetzt: Date(), kalender: .current) == nil)
    }

    // MARK: - tageHerVonTag rechnet gegen den ORTSTAG, nicht gegen UTC (R26)

    /// Ein reines Ortsdatum ("yyyy-MM-dd", `Messwert.measuredOn`) hat
    /// keine Uhrzeit -- `tageHerVonTag` darf den Vergleichstag "heute"
    /// deshalb nicht ueber `Calendar.startOfDay` auf einen UTC-verankerten
    /// Zeitpunkt bilden (das verschiebt ihn je nach Geraetezeitzone um bis
    /// zu einen Tag), sondern muss ihn zuerst als Tagesstring IN der
    /// Geraetezeitzone bauen. Baut den Zeitpunkt ueber Kalender-Komponenten
    /// in der jeweiligen Zeitzone, statt einen Unix-Zeitstempel zu raten.
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

    /// 21:00 Ortszeit am 14. September ist bereits 01:00 UTC am 15.
    /// September -- ein Vergleich gegen UTC.startOfDay wuerde "heute" auf
    /// den 15. legen und den Messtag vom 14. faelschlich einen Tag zu weit
    /// zurueckdatieren.
    @Test func tageHerVonTagRechnetInAmerikaGegenDenOrtstagNichtGegenUTC() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let jetzt = wanduhrzeit(2026, 9, 14, 21, 0, zeitzone: newYork)

        #expect(HomeZeilen.tageHerVonTag("2026-09-14", jetzt: jetzt, zeitzone: newYork) == 0)
        #expect(HomeZeilen.tageHerVonTag("2026-09-13", jetzt: jetzt, zeitzone: newYork) == 1)
    }

    /// Spiegelbildlich vor UTC: 07:00 Ortszeit am 15. September ist noch
    /// 19:00 UTC am 14. -- ein Vergleich gegen UTC.startOfDay wuerde
    /// "heute" auf den 14. legen.
    @Test func tageHerVonTagRechnetInNeuseelandGegenDenOrtstagNichtGegenUTC() {
        let auckland = TimeZone(identifier: "Pacific/Auckland")!
        let jetzt = wanduhrzeit(2026, 9, 15, 7, 0, zeitzone: auckland)

        #expect(HomeZeilen.tageHerVonTag("2026-09-15", jetzt: jetzt, zeitzone: auckland) == 0)
        #expect(HomeZeilen.tageHerVonTag("2026-09-14", jetzt: jetzt, zeitzone: auckland) == 1)
    }

    /// Auch nahe an UTC (Berlin) kurz nach Mitternacht: der Ortstag ist
    /// bereits der 15., "gestern" bleibt der 14.
    @Test func tageHerVonTagRechnetKurzNachMitternachtInBerlinRichtig() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = wanduhrzeit(2026, 9, 15, 0, 30, zeitzone: berlin)

        #expect(HomeZeilen.tageHerVonTag("2026-09-14", jetzt: jetzt, zeitzone: berlin) == 1)
    }

    @Test func derGrussNimmtDenErstenNamensteil() {
        #expect(HomeZeilen.vorname("Lena Wagner") == "Lena")
        #expect(HomeZeilen.vorname("Lena") == "Lena")
    }

    /// Ohne gesetzten Namen wird nichts erfunden -- weder Gruss noch
    /// Initialen. Aus einer Mailadresse abgeleitet saehe beides so lange
    /// richtig aus, bis es jemanden trifft.
    @Test func ohneNamenGibtEsWederGrussNochInitialen() {
        #expect(HomeZeilen.vorname(nil) == nil)
        #expect(HomeZeilen.vorname("   ") == nil)
        #expect(HomeZeilen.initialen(nil) == nil)
    }

    @Test func initialenNehmenHoechstensZweiTeile() {
        #expect(HomeZeilen.initialen("Lena Wagner") == "LW")
        #expect(HomeZeilen.initialen("Lena") == "L")
        #expect(HomeZeilen.initialen("Lena Marie Wagner") == "LM")
    }

    @Test func zeilenTextUnterscheidetEinzahlUndMehrzahlBeiGeraetenUndSaetzen() {
        #expect(HomeZeilen.zeilenText(einheit(machineCount: 1, setCount: 1)) == "47 min · 1 Gerät · 1 Satz")
        #expect(HomeZeilen.zeilenText(einheit(machineCount: 2, setCount: 2)) == "47 min · 2 Geräte · 2 Sätze")
    }

    /// Die selbsttaetig beendete Einheit hat keine Dauer (dauerText liefert
    /// nil) -- die Zeile faellt dann auf Geraete und Saetze zurueck, statt
    /// eine leere erste Angabe vor dem ersten Trennpunkt zu zeigen.
    @Test func zeilenTextLaesstDieDauerOhneGueltigeWeg() {
        #expect(HomeZeilen.zeilenText(einheit()) == "47 min · 3 Geräte · 8 Sätze")
        #expect(HomeZeilen.zeilenText(einheit(completedReason: "auto")) == "3 Geräte · 8 Sätze")
    }

    @Test func veraenderungZeigtVorzeichenUndPlusMinusNullBeiKeinerAenderung() {
        #expect(HomeZeilen.veraenderung(15) == "+15,0")
        #expect(HomeZeilen.veraenderung(-2.5) == "-2,5")
        #expect(HomeZeilen.veraenderung(0) == "±0")
    }

    @Test func tageHerLabelIstNurBeiGenauEinemTagEinzahl() {
        #expect(HomeZeilen.tageHerLabel(1) == "Tag her")
        #expect(HomeZeilen.tageHerLabel(0) == "Tage her")
        #expect(HomeZeilen.tageHerLabel(2) == "Tage her")
    }

    @Test func detailUntertitelZeigtZeitraumUndDauerFuerEineManuellBeendeteEinheit() {
        let session = einheit()
        #expect(HomeZeilen.detailUntertitel(session) == "\(zeitraum(session)) · 47 min · 3 Geräte · 8 Sätze")
    }

    @Test func detailUntertitelLaesstZeitraumUndDauerFuerEineSelbsttaetigBeendeteEinheitWeg() {
        #expect(HomeZeilen.detailUntertitel(einheit(completedReason: "auto")) == "3 Geräte · 8 Sätze")
    }

    @Test func detailUntertitelUnterscheidetEinzahlUndMehrzahlBeiGeraetenUndSaetzen() {
        let eins = einheit(machineCount: 1, setCount: 1)
        #expect(HomeZeilen.detailUntertitel(eins) == "\(zeitraum(eins)) · 47 min · 1 Gerät · 1 Satz")

        let mehrere = einheit(machineCount: 2, setCount: 2)
        #expect(HomeZeilen.detailUntertitel(mehrere) == "\(zeitraum(mehrere)) · 47 min · 2 Geräte · 2 Sätze")
    }

    /// Baut dieselbe "18:04 – 18:51"-Angabe wie HomeZeilen.detailUntertitel
    /// aus denselben Zeitpunkten, statt sie als Text vorherzusagen:
    /// Zahlformat.uhrzeit folgt TimeZone.current (richtig -- die Zeit
    /// gehoert dem Geraet, siehe Zahlformat-Kommentar), ein woertlich
    /// erwarteter String waere deshalb nur in der Zeitzone des
    /// Testrechners gruen (vgl. Kommentar in KurseWochenBerechnungTests).
    private func zeitraum(_ session: SessionSummary) -> String {
        let start = Zeitpunkt.parse(session.startedAt)!
        let ende = Zeitpunkt.parse(session.completedAt!)!
        return "\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende))"
    }

    // MARK: - Die Karte im Tages-Ausklapper

    /// Die Uhrzeit steht dort, wo in "Letzte Trainings" das Datum stand:
    /// welcher Tag es ist, sagt der Kalender darueber.
    @Test func dieKarteTraegtDenZeitraum() {
        let einheit = einheit()

        #expect(HomeZeilen.kartenTitel(einheit) == HomeZeilen.zeitraum(einheit))
        #expect(HomeZeilen.zeitraum(einheit)?.contains(" – ") == true)
    }

    /// Ein erfundenes Ende waere schlimmer als ein offener Zeitraum -- das
    /// Ende einer selbsttaetig beendeten Einheit liegt beim letzten Satz.
    @Test func eineSelbsttaetigBeendeteEinheitZeigtNurIhrenBeginn() {
        let auto = einheit(completedReason: "auto")

        #expect(HomeZeilen.zeitraum(auto) == nil)
        #expect(HomeZeilen.kartenTitel(auto).hasPrefix("ab "))
        #expect(HomeZeilen.kartenTitel(auto).contains(" – ") == false)
    }

    @Test func eineEinheitOhneEndeHatKeinenZeitraum() {
        #expect(HomeZeilen.zeitraum(einheit(completedAt: nil)) == nil)
    }
}
