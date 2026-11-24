import Testing
import Foundation
@testable import Sensorik

@Suite struct SollwelleTests {
    @Test func standardIstAnderthalbUndZweieinhalb() {
        #expect(Tempovorgabe.standard.periode == 4.0)
    }

    @Test(arguments: [(0.2, 1.0), (1.7, 1.5), (1.8, 2.0), (9.0, 4.0)])
    func vorgabeRundetUndBegrenzt(roh: Double, erwartet: Double) {
        #expect(Tempovorgabe(kraftweg: roh, ablassen: roh).kraftweg == erwartet)
    }

    @Test func welleLaeuftUntenLosUndIstNachDemKraftwegOben() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.lage(bei: -2) == 0)
        #expect(w.lage(bei: 0) == 0)
        #expect(abs(w.lage(bei: 0.75) - 0.5) < 1e-9)
        #expect(abs(w.lage(bei: 1.5) - 1) < 1e-9)
        #expect(abs(w.lage(bei: 2.75) - 0.5) < 1e-9)
        #expect(abs(w.lage(bei: 4.0)) < 1e-9)
        #expect(w.periode(bei: -0.1) == nil)
        #expect(w.periode(bei: 3.9) == 0)
        #expect(w.periode(bei: 4.0) == 1)
        #expect(w.weg(bei: 1.4) == .kraftweg)
        #expect(w.weg(bei: 1.6) == .ablassen)
    }

    @Test func zielUndTaktmarken() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.zielzeit(wiederholungen: 12) == 48)
        #expect(w.taktmarken(von: 0, bis: 4).map(\.t) == [0, 0.75, 1.5, 2.75])
        #expect(w.taktmarken(von: 0, bis: 4).map(\.lage).map { ($0 * 100).rounded() / 100 } == [0, 0.5, 1, 0.5])
    }

    @Test func bahnIstZweiZehntelBreit() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.inDerBahn(0.7, bei: 0.75))
        #expect(!w.inDerBahn(0.71, bei: 0.75))
    }

    // MARK: Fix-Runde 1

    @Test func vorgabeRundetAuchDasAblassen() {
        #expect(Tempovorgabe(kraftweg: 1, ablassen: 1.7).ablassen == 1.5)
        #expect(Tempovorgabe(kraftweg: 1, ablassen: 1.3).ablassen == 1.5)
        #expect(Tempovorgabe(kraftweg: 1, ablassen: 0.2).ablassen == 1)
        #expect(Tempovorgabe(kraftweg: 1, ablassen: 9).ablassen == 4)
    }

    @Test func nichtEndlicheVorgabeFaelltAufDenStandardDesWegs() {
        let v = Tempovorgabe(kraftweg: .nan, ablassen: .infinity)
        #expect(v.kraftweg == 1.5)
        #expect(v.ablassen == 2.5)
        #expect(Tempovorgabe(kraftweg: -.infinity, ablassen: .nan) == .standard)
    }

    @Test func dekodierenRundetUndBegrenzt() throws {
        func dekodiere(_ json: String) throws -> Tempovorgabe {
            try JSONDecoder().decode(Tempovorgabe.self, from: Data(json.utf8))
        }
        #expect(try dekodiere(#"{"kraftweg":0,"ablassen":0}"#) == Tempovorgabe(kraftweg: 1, ablassen: 1))
        #expect(try dekodiere(#"{"kraftweg":-3,"ablassen":1e9}"#) == Tempovorgabe(kraftweg: 1, ablassen: 4))
        let abgerundet = try dekodiere(#"{"kraftweg":1.3,"ablassen":2.74}"#)
        #expect(abgerundet.kraftweg == 1.5)
        #expect(abgerundet.ablassen == 2.5)
        #expect(Sollwelle(vorgabe: try dekodiere(#"{"kraftweg":0,"ablassen":0}"#)).periode(bei: 3) == 1)
    }

    @Test func kodierenBleibtBeiZweiSchluesseln() throws {
        let daten = try JSONEncoder().encode(Tempovorgabe(kraftweg: 2, ablassen: 3))
        let woerterbuch = try JSONDecoder().decode([String: Double].self, from: daten)
        #expect(woerterbuch == ["kraftweg": 2, "ablassen": 3])
        #expect(try JSONDecoder().decode(Tempovorgabe.self, from: daten) == Tempovorgabe(kraftweg: 2, ablassen: 3))
    }

    @Test func ablassFlankeFolgtDemCosinus() {
        let w = Sollwelle(vorgabe: .standard)
        // t = 2.125: Viertel des Ablassens, 1 - (1 - cos(pi/4))/2 = 0.8535533906
        #expect(abs(w.lage(bei: 2.125) - 0.8535533906) < 1e-9)
        // t = 3.375: Dreiviertel, 1 - (1 - cos(3pi/4))/2 = 0.1464466094
        #expect(abs(w.lage(bei: 3.375) - 0.1464466094) < 1e-9)
        // zweite Periode wiederholt die erste
        #expect(abs(w.lage(bei: 4.75) - 0.5) < 1e-9)
    }

    @Test func wegVorLosAnDerGrenzeUndImPeriodenwechsel() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.weg(bei: -0.1) == nil)
        #expect(w.weg(bei: 0) == .kraftweg)
        #expect(w.weg(bei: 1.5) == .ablassen)
        #expect(w.weg(bei: 3.999) == .ablassen)
        #expect(w.weg(bei: 4.0) == .kraftweg)
        #expect(w.weg(bei: 5.4) == .kraftweg)
        #expect(w.weg(bei: 5.6) == .ablassen)
    }

    @Test func taktmarkenInSpaeteremFenster() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.taktmarken(von: 4, bis: 8).map(\.t) == [4, 4.75, 5.5, 6.75])
        #expect(w.taktmarken(von: 1, bis: 3).map(\.t) == [1.5, 2.75])
        #expect(w.taktmarken(von: 0.75, bis: 1.5).map(\.t) == [0.75])
    }

    @Test func taktmarkenUeberMehrerePerioden() {
        let w = Sollwelle(vorgabe: .standard)
        let marken = w.taktmarken(von: 0, bis: 8)
        #expect(marken.map(\.t) == [0, 0.75, 1.5, 2.75, 4, 4.75, 5.5, 6.75])
        #expect(marken.map(\.lage) == [0, 0.5, 1, 0.5, 0, 0.5, 1, 0.5])
    }

    @Test func taktmarkenAbVorDemStartBeginnenBeiNull() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.taktmarken(von: -2, bis: 4).map(\.t) == [0, 0.75, 1.5, 2.75])
        #expect(w.taktmarken(von: -5, bis: -1).isEmpty)
        #expect(w.taktmarken(von: 3, bis: 3).isEmpty)
    }

    @Test func taktmarkenFensterBegrenzt() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.taktmarken(von: 0, bis: 600).count == 600)
        #expect(w.taktmarken(von: 0, bis: 601).isEmpty)
        #expect(w.taktmarken(von: 1e300, bis: 1e300 + 1).isEmpty)
    }

    @Test func bahnAufDemAblassenUndAmRand() {
        let w = Sollwelle(vorgabe: .standard)
        // t = 2.75: Soll 0.5
        #expect(w.inDerBahn(0.3, bei: 2.75))
        #expect(w.inDerBahn(0.7, bei: 2.75))
        #expect(!w.inDerBahn(0.29, bei: 2.75))
        #expect(!w.inDerBahn(0.71, bei: 2.75))
        // t = 2.125: Soll 0.8535533906, obere Kante 1.0535533906
        #expect(w.inDerBahn(1.05, bei: 2.125))
        #expect(!w.inDerBahn(1.06, bei: 2.125))
        // vor Los: Soll 0
        #expect(w.inDerBahn(0.2, bei: -1))
        #expect(!w.inDerBahn(0.25, bei: -1))
    }

    @Test func nichtEndlicheZeitenStuerzenNichtAb() {
        let w = Sollwelle(vorgabe: .standard)
        for t in [Double.nan, .infinity, -.infinity] {
            #expect(w.lage(bei: t) == 0)
            #expect(w.periode(bei: t) == nil)
            #expect(w.weg(bei: t) == nil)
        }
        #expect(w.periode(bei: 1e300) == nil)
        #expect(w.taktmarken(von: .nan, bis: 4).isEmpty)
        #expect(w.taktmarken(von: 0, bis: .infinity).isEmpty)
        #expect(w.taktmarken(von: -.infinity, bis: 4).isEmpty)
    }

    @Test func zielzeitOhneWiederholungenIstNull() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.zielzeit(wiederholungen: 0) == 0)
        #expect(w.zielzeit(wiederholungen: -3) == 0)
    }

    // MARK: Bahnbreite je Welle (Fix-Welle B.8)

    @Test func bahnbreiteIstJeWelleEinstellbar() {
        let breit = Sollwelle(vorgabe: .standard, halbeBahnbreite: 0.3), normal = Sollwelle(vorgabe: .standard)
        #expect(breit.halbeBahnbreite == 0.3)
        #expect(normal.halbeBahnbreite == Sollwelle.standardHalbeBahnbreite && Sollwelle.standardHalbeBahnbreite == 0.2)
        #expect(breit.inDerBahn(0.8, bei: 0.75) && !breit.inDerBahn(0.81, bei: 0.75))
        #expect(!normal.inDerBahn(0.8, bei: 0.75))
        for ungueltig in [0, -0.1, Double.nan, .infinity] {
            #expect(Sollwelle(vorgabe: .standard, halbeBahnbreite: ungueltig).halbeBahnbreite == 0.2)
        }
    }

    @Test func dieAuswertungNimmtDieBahnbreiteDerWelle() {
        // Die Person laeuft 0,25 ueber der Welle: in der Bahn von 0,3, ausserhalb der von 0,2.
        func quote(_ welle: Sollwelle) -> Double? {
            var a = Tempoauswertung(welle: welle)
            for k in 0..<(24 * 50) {
                let t = Double(k) / 50
                a.erfasse(Lage(t: t, lage: welle.lage(bei: t) + 0.25, richtung: .unbekannt, sicher: true), bei: t)
            }
            return a.ergebnis()?.quote
        }
        #expect(quote(Sollwelle(vorgabe: .standard, halbeBahnbreite: 0.3)) == 1)
        #expect(quote(Sollwelle(vorgabe: .standard)) == 0)
    }

    // MARK: Haltephase

    private var mitHalten: Tempovorgabe { Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1) }

    @Test func haltephaseIstFlachOben() {
        let w = Sollwelle(vorgabe: mitHalten)
        #expect(abs(w.lage(bei: 2.0) - 1) < 1e-9)
        #expect(abs(w.lage(bei: 2.5) - 1) < 1e-9)
        #expect(abs(w.lage(bei: 3.0) - 1) < 1e-9)
        #expect(abs(w.lage(bei: 4.5) - 0.5) < 1e-9)   // Mitte des Ablassens
        #expect(abs(w.lage(bei: 6.0)) < 1e-9)
    }

    @Test func wegKenntHalten() {
        let w = Sollwelle(vorgabe: mitHalten)
        #expect(w.weg(bei: 1.0) == .kraftweg)
        #expect(w.weg(bei: 2.5) == .halten)
        #expect(w.weg(bei: 3.5) == .ablassen)
        #expect(w.weg(bei: 8.5) == .halten)           // zweite Periode
    }

    @Test func ohneHaltenKeinHaltenWeg() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.weg(bei: 1.5) == .ablassen)
    }

    @Test func taktmarkenMitHalten() {
        let marken = Sollwelle(vorgabe: mitHalten).taktmarken(von: 0, bis: 6)
        #expect(marken.map(\.t) == [0, 1, 2, 3, 4.5])
        #expect(marken.map(\.lage) == [0, 0.5, 1, 1, 0.5])
    }

    @Test func zielzeitNutztPeriodeMitHalten() {
        #expect(Sollwelle(vorgabe: mitHalten).zielzeit(wiederholungen: 8) == 48)
    }
}
