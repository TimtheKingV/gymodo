import XCTest
@testable import Koerperbild

final class ErkennungspruefungTests: XCTestCase {
    let curl = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .beide)!

    /// Alle 15 Gelenke sicher, mitten im Bild.
    var voll: Skelett {
        skelett(Dictionary(uniqueKeysWithValues: Gelenk.allCases.map { ($0, (0.5, 0.5)) }))
    }
    func ohne(_ weg: Set<Gelenk>) -> Skelett {
        var s = voll
        for g in weg { s.punkte[g] = nil }
        return s
    }
    var ohneHand: Skelett { ohne([.handL, .handR]) }
    var ohneFuesse: Skelett { ohne([.fussL, .fussR]) }
    var handAmRand: Skelett {
        var s = voll
        s.punkte[.handL]!.x = 0.99
        return s
    }

    func testBestandenErstNachEinerSekunde() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0.0, skelett: voll); XCTAssertFalse(p.bestanden)
        p.eingabe(t: 0.9, skelett: voll); XCTAssertFalse(p.bestanden)
        p.eingabe(t: 1.0, skelett: voll); XCTAssertTrue(p.bestanden)
    }
    func testAussetzerSetztBestandenZurueck() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: voll); p.eingabe(t: 0.6, skelett: nil); p.eingabe(t: 1.2, skelett: voll)
        XCTAssertFalse(p.bestanden)
    }
    func testVerlorenErstNachMehrAlsEinerSekunde() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: voll); p.eingabe(t: 1, skelett: voll)
        p.eingabe(t: 1.5, skelett: ohneHand); XCTAssertFalse(p.verloren)
        p.eingabe(t: 2.5, skelett: ohneHand); XCTAssertFalse(p.verloren)   // genau 1,0 s
        p.eingabe(t: 2.6, skelett: ohneHand); XCTAssertTrue(p.verloren)
        XCTAssertEqual(p.fehlendeGruppen, [.arme])
    }
    func testFehlendeFuesseStoerenDenCurlNicht() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: ohneFuesse); p.eingabe(t: 1, skelett: ohneFuesse)
        XCTAssertTrue(p.bestanden); XCTAssertTrue(p.fehlendeGruppen.isEmpty)
    }
    func testGelenkAmBildrandIstNichtImRahmenAberNichtVerloren() {
        var p = Erkennungspruefung(vorgabe: curl)
        for t in stride(from: 0.0, through: 3.0, by: 0.5) { p.eingabe(t: t, skelett: handAmRand) }
        XCTAssertFalse(p.bestanden); XCTAssertFalse(p.verloren)
    }
    func testOhneSkelettFehlenAlleGruppenMitPflichtgelenken() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: nil)
        XCTAssertEqual(p.fehlendeGruppen, [.schultern, .arme])
    }
    func testFuehrendeSeiteBeiBeideIstDieMitMehrSicherenGelenken() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: ohne([.handL, .schulterL]))
        XCTAssertEqual(p.fuehrendeSeite, .rechts)
        p.eingabe(t: 0.1, skelett: voll)
        XCTAssertEqual(p.fuehrendeSeite, .links)   // Gleichstand
    }
    func testVorgegebeneSeiteBleibtFuehrend() {
        let v = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .links)!
        var p = Erkennungspruefung(vorgabe: v)
        p.eingabe(t: 0, skelett: ohne([.handL]))
        XCTAssertEqual(p.fuehrendeSeite, .links)
        XCTAssertEqual(p.fehlendeGruppen, [.arme])
    }
    func testZuruecksetzen() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: voll); p.eingabe(t: 1, skelett: voll)
        p.zuruecksetzen()
        XCTAssertFalse(p.bestanden)
        p.eingabe(t: 5, skelett: voll); XCTAssertFalse(p.bestanden)
    }

    // MARK: Festgehaltene Seite

    func testFestgehalteneSeiteWirdGeprueft() {
        var p = Erkennungspruefung(vorgabe: curl)
        let s = ohne([.handR])   // links voll sicher, rechts fehlt die Hand
        p.eingabe(t: 0, skelett: s); p.eingabe(t: 2, skelett: s)
        XCTAssertFalse(p.verloren)
        p.seiteFesthalten(.rechts)
        p.eingabe(t: 3, skelett: s); p.eingabe(t: 4.1, skelett: s)
        XCTAssertEqual(p.fuehrendeSeite, .rechts)
        XCTAssertTrue(p.verloren)
        XCTAssertEqual(p.fehlendeGruppen, [.arme])
    }
    func testFesthaltenBeginntDieZeitNeu() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.eingabe(t: 0, skelett: voll); p.eingabe(t: 2, skelett: voll)
        XCTAssertTrue(p.bestanden)
        p.seiteFesthalten(.rechts)
        XCTAssertFalse(p.bestanden); XCTAssertFalse(p.verloren)
        let s = ohne([.handR])
        p.eingabe(t: 3, skelett: s); p.eingabe(t: 5, skelett: s)
        p.seiteFesthalten(nil)
        XCTAssertFalse(p.verloren); XCTAssertFalse(p.bestanden)
    }
    func testVorgegebeneSeiteGewinntGegenFesthalten() {
        let v = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .links)!
        var p = Erkennungspruefung(vorgabe: v)
        p.seiteFesthalten(.rechts)
        p.eingabe(t: 0, skelett: voll)
        XCTAssertEqual(p.fuehrendeSeite, .links)
    }
    func testZuruecksetzenBehaeltDieFestgehalteneSeite() {
        var p = Erkennungspruefung(vorgabe: curl)
        p.seiteFesthalten(.rechts)
        p.zuruecksetzen()
        XCTAssertEqual(p.fuehrendeSeite, .rechts)
        p.seiteFesthalten(nil)
        p.eingabe(t: 0, skelett: voll)
        XCTAssertEqual(p.fuehrendeSeite, .links)
    }
}
