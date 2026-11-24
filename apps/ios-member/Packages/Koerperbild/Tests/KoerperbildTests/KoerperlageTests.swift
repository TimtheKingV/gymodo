import XCTest
@testable import Koerperbild
import Sensorik

final class KoerperlageTests: XCTestCase {
    func testZaehltAchtSaubereWiederholungen() {
        let k = lauf(satz(wdh: 8, hin: 1.5, rueck: 2.5, von: 170, bis: 50))
        XCTAssertEqual(k.wiederholungen.count, 8)
        XCTAssertEqual(k.hubGrad!, 120, accuracy: 6)
    }
    func testLageLaeuftVonNullBisEins() {
        let lagen = lagenImLauf(satz(wdh: 6, hin: 2, rueck: 2, von: 170, bis: 50), gemerkterHub: 120)
        XCTAssertEqual(lagen.first!.lage, 0, accuracy: 0.05)
        XCTAssertEqual(lagen.map(\.lage).max()!, 1, accuracy: 0.08)
        XCTAssertTrue(lagen.allSatisfy { $0.lage > -0.15 && $0.lage < 1.15 })
    }
    func testOhneGemerktenHubErstNachZweiWiederholungenSicher() {
        let (k, lagen) = lagenUndStand(satz(wdh: 4, hin: 2, rueck: 2, von: 170, bis: 50), gemerkterHub: nil)
        let zweiteEnde = k.wiederholungen[1].ende
        // Gezaehlt (und damit sicher) wird schon bei Lage <= 0,15, rund 0,4 s vor dem Tal.
        XCTAssertTrue(lagen.filter { $0.t < zweiteEnde - 0.6 }.allSatisfy { !$0.sicher })
        XCTAssertTrue(lagen.filter { $0.t > zweiteEnde + 0.2 }.allSatisfy(\.sicher))
    }
    func testMitGemerktemHubSofortSicher() {
        XCTAssertTrue(lagenImLauf(satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50), gemerkterHub: 120).dropFirst(5).allSatisfy(\.sicher))
    }
    func testKurzerAussetzerZaehltNichtDoppelt() {
        // 0,3 s ohne Skelett mitten im Hinweg der dritten Wiederholung.
        XCTAssertEqual(laufMitLuecke(satz(wdh: 6, hin: 2, rueck: 2, von: 170, bis: 50), von: 9.5, bis: 9.8).wiederholungen.count, 6)
    }
    func testEinarmigFolgtDemArbeitendenArm() {
        // Links ruht bei 170 mit Sicherheit 1, rechts arbeitet mit Sicherheit 0,6.
        let k = laufEinarmig(arbeitet: .rechts, sicherheitRuhend: 1.0, sicherheitArbeitend: 0.6, wdh: 5)
        XCTAssertEqual(k.fuehrendeSeite, .rechts); XCTAssertEqual(k.wiederholungen.count, 5)
    }
    func testWinkelsprungUeber180ZaehltNicht() {
        // Vorzeichen-Winkel laeuft 150 -> 200 (= -160) -> 150; eine Wiederholung, keine zwei.
        XCTAssertEqual(laufRoh(vorzeichenWinkel: uebersprung(wdh: 4)).wiederholungen.count, 4)
    }
    func testWinkelsprungLaeuftWirklichUeberDieGrenze() {
        // Absicherung des Helfers: das Skelett liefert hier tatsaechlich negative Winkel.
        let s = armSkelett(ellbogenL: 200, ellbogenR: 200)
        XCTAssertEqual(s.winkel(.ellbogen, seite: .links)!, -160, accuracy: 0.01)
    }
    func testZitternInRuheZaehltNicht() {
        XCTAssertEqual(lauf(rauschen(dauer: 10, um: 170, ausschlag: 6)).wiederholungen.count, 0)
    }
    func testHubZuKlein() {
        XCTAssertTrue(lauf(satz(wdh: 3, hin: 1.5, rueck: 1.5, von: 170, bis: 153)).hubZuKlein)
        XCTAssertFalse(lauf(satz(wdh: 3, hin: 1.5, rueck: 1.5, von: 170, bis: 120)).hubZuKlein)
    }
    func testUnterbrechenVerwirftNurDieOffene() {
        var k = Koerperlage(vorgabe: curl, gemerkterHub: 120)
        speise(&k, satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50), bis: 11.0)   // zwei fertig, dritte am Gipfel
        k.unterbrechen()
        XCTAssertEqual(k.wiederholungen.count, 2)
        speise(&k, satz(wdh: 2, hin: 2, rueck: 2, von: 170, bis: 50), versatz: 20)
        XCTAssertEqual(k.wiederholungen.count, 4)
    }
    func testWegdauernStimmen() {
        let w = lauf(satz(wdh: 5, hin: 1.5, rueck: 2.5, von: 170, bis: 50)).wiederholungen[3]
        XCTAssertEqual(w.dauerHin, 1.5, accuracy: 0.25); XCTAssertEqual(w.dauerRueck, 2.5, accuracy: 0.25)
    }
    func testRuhigVorDemLos() {
        var k = Koerperlage(vorgabe: curl, gemerkterHub: nil)
        for i in 0..<30 { _ = k.verarbeite(t: Double(i) / 30, skelett: armSkelett(ellbogenL: 170, ellbogenR: 170)) }
        XCTAssertTrue(k.istRuhig)
    }
    func testZaehltSofortBeiRueckkehr() {
        // Mit gemerktem Hub 120: spaetestens 0,1 s nach Lage <= 0,15 ist die Wiederholung gezaehlt.
        var k = Koerperlage(vorgabe: curl, gemerkterHub: 120)
        var gelost = false, hochGewesen = false
        var vorher = 0, letzteLage = 0.0
        var pruefen: (t: Double, zaehlerVorher: Int)?
        var geprueft = 0
        for m in satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50) {
            if !gelost && m.t >= 1.0 { k.los(t: m.t); gelost = true }
            let l = k.verarbeite(t: m.t, skelett: armSkelett(ellbogenL: m.winkel, ellbogenR: m.winkel))
            guard gelost else { continue }
            if let p = pruefen, l.t >= p.t + 0.1 {
                XCTAssertEqual(k.wiederholungen.count, p.zaehlerVorher + 1, "t=\(p.t)")
                pruefen = nil; geprueft += 1
            }
            if l.lage > 0.6 { hochGewesen = true }
            if hochGewesen && letzteLage > 0.15 && l.lage <= 0.15 {
                pruefen = (l.t, vorher); hochGewesen = false
            }
            letzteLage = l.lage
            if pruefen == nil { vorher = k.wiederholungen.count }
        }
        XCTAssertEqual(geprueft, 3)
        XCTAssertEqual(k.wiederholungen.count, 3)
    }
    func testUnvollstaendigeRueckkehrZaehltUeberAnstieg() {
        // Kehrt nur bis Lage ~0,3 zurueck (170 -> 50 -> 134 -> 50 ...): jede Wiederholung zaehlt trotzdem.
        var werte: [Messwert] = (0..<30).map { (Double($0) / 30, 170) }
        var i = 30
        func weg(_ a: Double, _ b: Double) {
            for k in 0..<60 { werte.append((Double(i) / 30, a + (b - a) * (1 - cos(.pi * Double(k) / 60)) / 2)); i += 1 }
        }
        weg(170, 50)
        for _ in 0..<4 { weg(50, 134); weg(134, 50) }
        weg(50, 134)
        let k = lauf(werte, gemerkterHub: 120)
        XCTAssertEqual(k.wiederholungen.count, 4)   // vier vollstaendige Gipfel-Tal-Gipfel-Zyklen
    }

    // MARK: Richtung bis zum Tal

    func testRichtungBleibtRueckBisZumTal() {
        var k = Koerperlage(vorgabe: curl, gemerkterHub: 120)
        var gelost = false
        var lagen: [Lage] = []
        var zaehlzeiten: [Double] = []
        var vorher = 0
        for m in satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50) {
            if !gelost && m.t >= 1.0 { k.los(t: m.t); gelost = true }
            let l = k.verarbeite(t: m.t, skelett: armSkelett(ellbogenL: m.winkel, ellbogenR: m.winkel))
            guard gelost else { continue }
            lagen.append(l)
            if k.wiederholungen.count > vorher { zaehlzeiten.append(m.t); vorher = k.wiederholungen.count }
        }
        XCTAssertEqual(zaehlzeiten.count, 3)
        for (i, w) in k.wiederholungen.enumerated() {
            let dazwischen = lagen.filter { $0.t >= zaehlzeiten[i] && $0.t <= w.ende }
            XCTAssertFalse(dazwischen.isEmpty)
            XCTAssertTrue(dazwischen.allSatisfy { $0.richtung != .hin }, "Wdh \(i)")
            if i + 1 < k.wiederholungen.count {
                let spaeter = lagen.first { $0.t >= k.wiederholungen[i + 1].beginn + 0.6 }!
                XCTAssertEqual(spaeter.richtung, .hin, "Wdh \(i + 1)")
            }
        }
    }

    // MARK: Luecken an der Zaehlstelle

    private func ueberlappungsfrei(_ ws: [Koerperwiederholung], file: StaticString = #filePath, line: UInt = #line) {
        for (i, w) in ws.enumerated() {
            XCTAssertTrue(w.beginn < w.umkehr && w.umkehr < w.ende, "Wdh \(i)", file: file, line: line)
            if i > 0 { XCTAssertLessThanOrEqual(ws[i - 1].ende, w.beginn + 1e-9, "Wdh \(i)", file: file, line: line) }
        }
    }
    func testLueckeUeberDenZaehlzeitpunktZaehltGenauEinmal() {
        // Tal der dritten Wiederholung bei t = 13; gezaehlt wird etwa bei 12,6; 0,3 s ohne Skelett darueber.
        let k = laufMitLuecke(satz(wdh: 6, hin: 2, rueck: 2, von: 170, bis: 50), von: 12.4, bis: 12.7)
        XCTAssertEqual(k.wiederholungen.count, 6)
        ueberlappungsfrei(k.wiederholungen)
    }
    func testLaengereLueckeImRueckwegZaehltNichtDoppelt() {
        // 0,7 s ohne Skelett (ueber der 0,5-s-Grenze der Glaettung) im Rueckweg der dritten Wiederholung.
        let k = laufMitLuecke(satz(wdh: 6, hin: 2, rueck: 2, von: 170, bis: 50), von: 12.0, bis: 12.7)
        XCTAssertTrue((5...6).contains(k.wiederholungen.count), "\(k.wiederholungen.count)")
        ueberlappungsfrei(k.wiederholungen)
    }
    func testUnterbrechenNachDemZaehlzeitpunktVorDemTal() {
        var k = Koerperlage(vorgabe: curl, gemerkterHub: 120)
        speise(&k, satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50), bis: 4.8)   // erste gezaehlt bei ~4,6, Tal bei 5,0
        XCTAssertEqual(k.wiederholungen.count, 1)
        k.unterbrechen()
        XCTAssertEqual(k.wiederholungen.count, 1)
        speise(&k, satz(wdh: 2, hin: 2, rueck: 2, von: 170, bis: 50), versatz: 20)
        XCTAssertEqual(k.wiederholungen.count, 3)
        ueberlappungsfrei(k.wiederholungen)
    }
}
