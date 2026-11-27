import XCTest
@testable import Koerperbild
import Sensorik

final class FlowZaehlerTests: XCTestCase {
    let kniebeuge = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .links)!
    /// 2 s senken, 1 s heben: Periode 3 s, Hub 90 Grad (170 -> 80).
    let tempo = Uebungstempo(senken: 2, halten: 0, heben: 1, beginntMit: .senken)
    let rate = 30.0
    let oben = 170.0
    let hub = 90.0

    func neu() -> FlowZaehler { FlowZaehler(vorgabe: kniebeuge, tempo: tempo) }

    /// Kniewinkel nach der Soll-Welle, die bei `los` beginnt (vorher steht die Person).
    func nachWelle(_ t: Double, los: Double, hub: Double? = nil) -> Double {
        let welle = Sollwelle(vorgabe: tempo.vorgabe)
        return oben - (hub ?? self.hub) * welle.lage(bei: max(0, t - los))
    }

    /// Speist Bilder von `von` bis `bis` (exklusiv); `winkel` nil heisst: kein Skelett.
    func speise(_ z: inout FlowZaehler, von: Double, bis: Double, winkel: (Double) -> Double?) {
        var i = Int((von * rate).rounded())
        while Double(i) / rate < bis - 1e-9 {
            let t = Double(i) / rate
            z.bild(t: t, skelett: winkel(t).map { kniebeugeSkelett(knie: $0) })
            i += 1
        }
    }

    func steht(_ z: inout FlowZaehler, von: Double, bis: Double) {
        speise(&z, von: von, bis: bis) { _ in oben }
    }

    // MARK: Zaehlen

    func testZehnSauberKniebeugenAbStartOhneRuheDavor() {
        var z = neu()
        steht(&z, von: 0, bis: 2)
        z.start(t: 2)
        speise(&z, von: 2, bis: 32) { nachWelle($0, los: 2) }
        XCTAssertTrue((9...10).contains(z.wiederholungen), "gezaehlt: \(z.wiederholungen)")
        XCTAssertTrue(z.erkannt)
    }

    func testBilderVorStartZaehlenNicht() {
        var z = neu()
        speise(&z, von: 0, bis: 15) { nachWelle($0, los: 0) }
        XCTAssertEqual(z.wiederholungen, 0)
        z.start(t: 15)
        steht(&z, von: 15, bis: 20)
        XCTAssertEqual(z.wiederholungen, 0)
    }

    func testStartOhneVorherigeBilderSetztNachBestandenerErkennungAn() {
        var z = neu()
        z.start(t: 0)
        steht(&z, von: 0, bis: 1.5)
        speise(&z, von: 1.5, bis: 16.5) { nachWelle($0, los: 1.5) }
        XCTAssertTrue((3...5).contains(z.wiederholungen), "gezaehlt: \(z.wiederholungen)")
    }

    func testKleinerHubZaehltNichts() {
        var z = neu()
        steht(&z, von: 0, bis: 2)
        z.start(t: 2)
        speise(&z, von: 2, bis: 20) { nachWelle($0, los: 2, hub: 10) }
        XCTAssertEqual(z.wiederholungen, 0)
        XCTAssertTrue(z.erkannt)
    }

    // MARK: Erkennung

    func testKeinSkelettNachDreiSekundenIstNichtErkanntUndKommtZurueck() {
        var z = neu()
        z.start(t: 0)
        XCTAssertTrue(z.erkannt)
        speise(&z, von: 0, bis: 2.9) { _ in nil }
        XCTAssertTrue(z.erkannt)
        speise(&z, von: 2.9, bis: 3.1 + 1 / 30) { _ in nil }
        XCTAssertFalse(z.erkannt)
        steht(&z, von: 3.1 + 1 / 30, bis: 5)
        XCTAssertTrue(z.erkannt)
        speise(&z, von: 5, bis: 20) { nachWelle($0, los: 5) }
        XCTAssertGreaterThan(z.wiederholungen, 0)
    }

    func testLueckeMitten() {
        var z = neu()
        steht(&z, von: 0, bis: 2)
        z.start(t: 2)
        var vorher = 0
        func pruefeSteigt() {
            XCTAssertGreaterThanOrEqual(z.wiederholungen, vorher)
            vorher = z.wiederholungen
        }
        // 4 Wiederholungen
        var t = 2.0
        while t < 14 - 1e-9 {
            z.bild(t: t, skelett: kniebeugeSkelett(knie: nachWelle(t, los: 2)))
            pruefeSteigt(); t += 1 / rate
        }
        XCTAssertEqual(z.wiederholungen, 4)
        // 2 s ohne Skelett
        while t < 16 - 1e-9 {
            z.bild(t: t, skelett: nil)
            if t > 14 + 1.0 + 1 / rate { XCTAssertFalse(z.erkannt, "t=\(t)") }
            pruefeSteigt(); t += 1 / rate
        }
        // 4 weitere Wiederholungen, die Person beginnt wieder oben
        while t < 28 - 1e-9 {
            z.bild(t: t, skelett: kniebeugeSkelett(knie: nachWelle(t, los: 16)))
            pruefeSteigt(); t += 1 / rate
        }
        XCTAssertGreaterThanOrEqual(z.wiederholungen, 7, "gezaehlt: \(z.wiederholungen)")
        XCTAssertLessThanOrEqual(z.wiederholungen, 8)
        XCTAssertTrue(z.erkannt)
    }

    // MARK: Anhalten

    func testAnhaltenFriertZaehlungUndWelleEin() {
        var z = neu()
        steht(&z, von: 0, bis: 2)
        z.start(t: 2)
        speise(&z, von: 2, bis: 11) { nachWelle($0, los: 2) }
        let gezaehlt = z.wiederholungen
        XCTAssertGreaterThanOrEqual(gezaehlt, 2)
        let sollVorher = z.sollzeit
        XCTAssertEqual(sollVorher, 9, accuracy: 0.1)
        z.anhalten(t: 11)
        speise(&z, von: 11, bis: 71) { nachWelle($0, los: 11) }
        XCTAssertEqual(z.wiederholungen, gezaehlt)
        XCTAssertEqual(z.sollzeit, sollVorher, accuracy: 1e-9)
        z.fortsetzen(t: 71)
        steht(&z, von: 71, bis: 73)
        XCTAssertEqual(z.wiederholungen, gezaehlt)
        XCTAssertEqual(z.sollzeit, sollVorher + 2, accuracy: 0.1)
        speise(&z, von: 73, bis: 85) { nachWelle($0, los: 73) }
        XCTAssertGreaterThan(z.wiederholungen, gezaehlt)
        XCTAssertTrue(z.erkannt)
    }

    // MARK: Zeitbezug

    func testSollzeitWaechstUndSpurHaeltSechsSekunden() {
        var z = neu()
        XCTAssertEqual(z.sollzeit, 0)
        steht(&z, von: 0, bis: 2)
        z.start(t: 2)
        speise(&z, von: 2, bis: 8) { nachWelle($0, los: 2) }
        let a = z.sollzeit
        speise(&z, von: 8, bis: 22) { nachWelle($0, los: 2) }
        XCTAssertGreaterThan(z.sollzeit, a)
        XCTAssertEqual(z.sollzeit, 20, accuracy: 0.1)
        XCTAssertFalse(z.spur.isEmpty)
        XCTAssertGreaterThanOrEqual(z.spur.first!.sollzeit, z.sollzeit - 6 - 1e-9)
        XCTAssertLessThanOrEqual(z.spur.last!.sollzeit, z.sollzeit)
        XCTAssertGreaterThan(z.spur.count, 100)
    }

    func testWelleHaeltBeiVerlustNichtAn() {
        var z = neu()
        steht(&z, von: 0, bis: 2)
        z.start(t: 2)
        speise(&z, von: 2, bis: 6) { nachWelle($0, los: 2) }
        speise(&z, von: 6, bis: 10) { _ in nil }
        XCTAssertEqual(z.sollzeit, 8, accuracy: 0.1)
        XCTAssertFalse(z.erkannt)
    }
}
