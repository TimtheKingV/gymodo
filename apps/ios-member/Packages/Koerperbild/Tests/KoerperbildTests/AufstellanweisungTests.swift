import XCTest
@testable import Koerperbild

final class AufstellanweisungTests: XCTestCase {
    let kniebeuge = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .links)!
    let curl = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .links)!

    /// Alle Pflichtgelenke der linken Seite (Ganzkoerper) mit x-Mitte `x`.
    func ganzkoerper(x: Double = 0.5) -> Skelett {
        skelett([.schulterL: (x, 0.2), .hueftL: (x, 0.5), .knieL: (x, 0.7), .fussL: (x, 0.9)])
    }
    func pruefung(_ vorgabe: Kameravorgabe, _ s: Skelett?) -> Erkennungspruefung {
        var p = Erkennungspruefung(vorgabe: vorgabe)
        p.eingabe(t: 0, skelett: s)
        return p
    }
    func anweisung(_ vorgabe: Kameravorgabe, _ s: Skelett?) -> Aufstellanweisung {
        Aufstellanweisung.aus(skelett: s, pruefung: pruefung(vorgabe, s), vorgabe: vorgabe)
    }

    func testKeinSkelettHeisstInDenRahmen() {
        XCTAssertEqual(anweisung(kniebeuge, nil), .inDenRahmen)
        let unsicher = Skelett(punkte: [.schulterL: Punkt(x: 0.5, y: 0.5, sicherheit: 0.1)], seitenverhaeltnis: 1)
        XCTAssertEqual(anweisung(kniebeuge, unsicher), .inDenRahmen)
    }
    func testUnsichereFuesseHeissenMehrLicht() {
        var s = ganzkoerper()
        s.punkte[.fussL] = Punkt(x: 0.5, y: 0.9, sicherheit: 0.2)
        XCTAssertEqual(anweisung(kniebeuge, s), .mehrLicht)
    }
    func testFehlendeFuesseHeissenSchrittZurueck() {
        var s = ganzkoerper()
        s.punkte[.fussL] = nil
        XCTAssertEqual(anweisung(kniebeuge, s), .schrittZurueck)
    }
    func testKopfAmOberenRandHeisstSchrittZurueck() {
        var s = ganzkoerper()
        s.punkte[.schulterL] = Punkt(x: 0.5, y: 0.02, sicherheit: 1)
        XCTAssertEqual(anweisung(kniebeuge, s), .schrittZurueck)
    }
    func testKoerperRechtsImBildHeisstNachRechts() {
        XCTAssertEqual(anweisung(kniebeuge, ganzkoerper(x: 0.8)), .nachRechts)
    }
    func testKoerperLinksImBildHeisstNachLinks() {
        XCTAssertEqual(anweisung(kniebeuge, ganzkoerper(x: 0.2)), .nachLinks)
    }
    func testOberkoerperOhneBeinePasst() {
        let s = skelett([.schulterL: (0.5, 0.3), .ellbogenL: (0.5, 0.5), .handL: (0.5, 0.7)])
        XCTAssertEqual(anweisung(curl, s), .passt)
    }
    func testGelenkAmSeitenrandOhneMittenAbweichungHeisstSchrittZurueck() {
        var s = ganzkoerper()
        s.punkte[.knieL] = Punkt(x: 0.02, y: 0.7, sicherheit: 1)   // nicht im Rahmen, Mittel bleibt mittig
        XCTAssertEqual(anweisung(kniebeuge, s), .schrittZurueck)
    }
}
