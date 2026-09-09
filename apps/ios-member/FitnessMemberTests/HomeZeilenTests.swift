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
}
