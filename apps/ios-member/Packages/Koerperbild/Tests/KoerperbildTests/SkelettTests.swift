import XCTest
@testable import Koerperbild

/// Testhelfer: Sicherheit 1, Seitenverhaeltnis Standard 1.
func skelett(_ lagen: [Gelenk: (Double, Double)], sv: Double = 1) -> Skelett {
    var punkte: [Gelenk: Punkt] = [:]
    for (g, l) in lagen { punkte[g] = Punkt(x: l.0, y: l.1, sicherheit: 1) }
    return Skelett(punkte: punkte, seitenverhaeltnis: sv)
}

final class SkelettTests: XCTestCase {
    func testWinkelGestreckterArmIst180() {
        let s = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.5, 0.6)])
        XCTAssertEqual(abs(s.winkel(.ellbogen, seite: .links)!), 180, accuracy: 0.01)
    }
    func testWinkelRechterWinkelMitSeitenverhaeltnis() {
        // Bild 9:16; ohne Seitenverhaeltnis waere der Winkel verzerrt.
        let s = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.5 + 0.2 * 16 / 9, 0.4)], sv: 9.0 / 16.0)
        XCTAssertEqual(abs(s.winkel(.ellbogen, seite: .links)!), 90, accuracy: 0.01)
    }
    func testUnsicheresGelenkGibtKeinenWinkel() {
        var s = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.5, 0.6)])
        s.punkte[.handL]!.sicherheit = 0.29
        XCTAssertNil(s.winkel(.ellbogen, seite: .links))
    }
    func testVorzeichenWechseltMitDerSeiteDerHand() {
        let a = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.6, 0.5)])
        let b = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.4, 0.5)])
        XCTAssertEqual(a.winkel(.ellbogen, seite: .links)!, -b.winkel(.ellbogen, seite: .links)!, accuracy: 0.01)
    }
}
