import XCTest
@testable import Koerperbild
import Sensorik

final class KameraSatzAblaufTests: XCTestCase {
    let kniebeuge = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .links)!
    /// 2 s senken, 1 s heben, Hub 90 Grad (170 -> 80).
    let tempo = Uebungstempo(senken: 2, halten: 0, heben: 1, beginntMit: .senken)
    let rate = 30.0
    let oben = 170.0
    let hub = 90.0

    func neu(mitVideo: Bool = false) -> KameraSatzAblauf {
        KameraSatzAblauf(vorgabe: kniebeuge, tempo: tempo, gemerkterHub: hub, mitVideo: mitVideo)
    }

    /// Linke Seite im Bild, Kniewinkel `winkel` (Hueft-Knie-Fuss); die Fuesse fehlen bei `ohneFuesse`.
    func skelett(knie winkel: Double, ohneFuesse: Bool = false) -> Skelett {
        let a = winkel * .pi / 180
        var punkte: [Gelenk: Punkt] = [
            .schulterL: Punkt(x: 0.5, y: 0.2, sicherheit: 1),
            .hueftL: Punkt(x: 0.5, y: 0.5, sicherheit: 1),
            .knieL: Punkt(x: 0.5, y: 0.7, sicherheit: 1),
            .fussL: Punkt(x: 0.5 + 0.2 * sin(a), y: 0.7 - 0.2 * cos(a), sicherheit: 1),
        ]
        if ohneFuesse { punkte[.fussL] = nil }
        return Skelett(punkte: punkte, seitenverhaeltnis: 1)
    }

    /// Speist Bilder von `von` bis `bis` (exklusiv) mit dem Kniewinkel `winkel(t)`.
    func speise(_ a: inout KameraSatzAblauf, von: Double, bis: Double,
                ohneFuesse: Bool = false, winkel: (Double) -> Double) {
        var i = Int((von * rate).rounded())
        while Double(i) / rate < bis - 1e-9 {
            let t = Double(i) / rate
            a.bild(t: t, skelett: skelett(knie: winkel(t), ohneFuesse: ohneFuesse))
            i += 1
        }
    }

    func still(_ a: inout KameraSatzAblauf, von: Double, bis: Double) {
        speise(&a, von: von, bis: bis) { _ in oben }
    }

    /// Kniewinkel nach der Soll-Welle (Kraftweg senken 2 s, Ablassen heben 1 s), um `versatz` verschoben.
    func nachWelle(_ t: Double, los: Double, tempoFaktor: Double = 1) -> Double {
        let welle = Sollwelle(vorgabe: tempo.vorgabe)
        let s = max(0, (t - los) * tempoFaktor)
        return oben - hub * welle.lage(bei: s)
    }

    // MARK: Start

    func testBeginntMitVideoNurWennVerlangt() {
        XCTAssertEqual(neu(mitVideo: true).schritt, .video)
        XCTAssertEqual(neu(mitVideo: false).schritt, .aufstellen)
        var a = neu(mitVideo: true)
        a.handyAufstellen()
        XCTAssertEqual(a.schritt, .aufstellen)
        var b = neu()
        b.abbrechen()
        b.handyAufstellen()
        XCTAssertEqual(b.schritt, .aufstellen)
    }

    // MARK: Aufstellen

    func testAufstellenBestehtNachEinerSekunde() {
        var a = neu()
        still(&a, von: 0, bis: 0.9)
        XCTAssertEqual(a.schritt, .aufstellen)
        XCTAssertEqual(a.anweisung, .passt)
        a.bild(t: 1.05, skelett: skelett(knie: oben))
        XCTAssertEqual(a.schritt, .countdown(rest: nil))
    }

    func testAufstellenMeldetFehlendeGruppen() {
        var a = neu()
        speise(&a, von: 0, bis: 0.5, ohneFuesse: true) { _ in oben }
        XCTAssertEqual(a.fehlendeGruppen, [.fuesse])
        XCTAssertEqual(a.anweisung, .schrittZurueck)
    }

    // MARK: Countdown

    func testCountdownWartetAufRuhe() {
        var a = neu()
        // Knie wackelt +-10 Grad (Periode 1 s), das Aufstellen besteht trotzdem.
        speise(&a, von: 0, bis: 3) { t in oben + 10 * sin(2 * .pi * t) }
        XCTAssertEqual(a.schritt, .countdown(rest: nil))
        // Ab 3 s ruhig: nach 0,5 s Ruhe beginnt der Countdown mit 3.
        speise(&a, von: 3, bis: 3.2) { _ in oben }
        XCTAssertEqual(a.schritt, .countdown(rest: nil))
        speise(&a, von: 3.2, bis: 4.2) { _ in oben }
        XCTAssertEqual(a.schritt, .countdown(rest: 3))
    }

    func testCountdownZaehltDreiZweiEins() {
        var gesehen: [Int] = []
        var b = neu()
        var t = 0.0
        while t < 6, b.schritt != .satz {
            b.bild(t: t, skelett: skelett(knie: oben))
            if case .countdown(let r?) = b.schritt, gesehen.last != r { gesehen.append(r) }
            t += 1 / rate
        }
        XCTAssertEqual(gesehen, [3, 2, 1])
    }

    func testNachDreiSekundenLaeuftDerSatz() {
        var a = neu()
        var t = 0.0
        var countdownBeginn: Double?
        while t < 8, a.schritt != .satz {
            a.bild(t: t, skelett: skelett(knie: oben))
            if countdownBeginn == nil, case .countdown(let r?) = a.schritt, r == 3 { countdownBeginn = t }
            t += 1 / rate
        }
        XCTAssertEqual(a.schritt, .satz)
        XCTAssertEqual(a.sollzeit, 0)
        let beginn = try! XCTUnwrap(countdownBeginn)
        XCTAssertEqual(t - 1 / rate - beginn, 3, accuracy: 1 / rate + 1e-6)
    }

    func testPflichtgelenkImCountdownVerlorenZurueckZumAufstellen() {
        var a = neu()
        still(&a, von: 0, bis: 2)
        guard case .countdown = a.schritt else { return XCTFail("kein Countdown: \(a.schritt)") }
        speise(&a, von: 2, bis: 3.2, ohneFuesse: true) { _ in oben }
        XCTAssertEqual(a.schritt, .aufstellen)
    }

    func testAbbrechenImCountdownFuehrtZumAufstellen() {
        var a = neu()
        still(&a, von: 0, bis: 2)
        guard case .countdown = a.schritt else { return XCTFail("kein Countdown: \(a.schritt)") }
        a.abbrechen()
        XCTAssertEqual(a.schritt, .aufstellen)
        a.bild(t: 2.05, skelett: skelett(knie: oben))
        XCTAssertEqual(a.schritt, .aufstellen)
    }

    // MARK: Satz

    /// Stand bis zur Los-Marke, danach Bewegung nach der Welle (Tempofaktor 1 = genau im Takt).
    func satzLaufen(_ a: inout KameraSatzAblauf, sekunden: Double, tempoFaktor: Double = 1) -> Double {
        var t = 0.0
        while t < 10, a.schritt != .satz {
            a.bild(t: t, skelett: skelett(knie: oben))
            t += 1 / rate
        }
        let los = t - 1 / rate
        speise(&a, von: t, bis: los + sekunden) { nachWelle($0, los: los, tempoFaktor: tempoFaktor) }
        return los
    }

    func testSaubereSaetzeZaehlenUndBleibenImTakt() {
        var a = neu()
        var t = 0.0
        while t < 10, a.schritt != .satz {
            a.bild(t: t, skelett: skelett(knie: oben))
            t += 1 / rate
        }
        let los = t - 1 / rate
        var takte = Set<KameraSatzAblauf.Takt>()
        let ende = los + 5 * 3 + 0.5
        while t < ende {
            a.bild(t: t, skelett: skelett(knie: nachWelle(t, los: los)))
            takte.insert(a.takt)
            t += 1 / rate
        }
        XCTAssertEqual(a.wiederholungen, 5)
        XCTAssertEqual(takte, [.imTakt])
        XCTAssertFalse(a.spur.isEmpty)
        XCTAssertLessThanOrEqual((a.spur.last?.sollzeit ?? 0) - (a.spur.first?.sollzeit ?? 0), 6 + 1e-9)
    }

    func testZuSchnellNachEinerHalbenSekundeNebenDerBahn() {
        var a = neu()
        var t = 0.0
        while t < 10, a.schritt != .satz {
            a.bild(t: t, skelett: skelett(knie: oben))
            t += 1 / rate
        }
        let los = t - 1 / rate
        // Senken in 1 s statt 2 s: die Lage laeuft der Soll-Welle davon.
        var ersteSchnell: Double?
        var ersteNeben: Double?
        let welle = Sollwelle(vorgabe: tempo.vorgabe)
        while t < los + 2 {
            let ist = min(1, (t - los) / 1)
            let w = oben - hub * (1 - cos(.pi * ist)) / 2
            a.bild(t: t, skelett: skelett(knie: w))
            let lageIst = (oben - w) / hub
            if ersteNeben == nil, !welle.inDerBahn(lageIst, bei: t - los) { ersteNeben = t }
            if ersteSchnell == nil, a.takt == .zuSchnell { ersteSchnell = t }
            t += 1 / rate
        }
        let neben = try! XCTUnwrap(ersteNeben)
        let schnell = try! XCTUnwrap(ersteSchnell)
        XCTAssertGreaterThan(schnell - neben, 0.5 - 1e-9)
        XCTAssertLessThan(schnell - neben, 0.5 + 0.3)
    }

    func testZuLangsamWennDieLageHinterDerWelleZurueckbleibt() {
        var a = neu()
        _ = satzLaufen(&a, sekunden: 1.6, tempoFaktor: 0.5)
        XCTAssertEqual(a.takt, .zuLangsam)
    }

    func testSatzBeendenOhneWiederholungFuehrtOhneKamera() {
        var a = neu()
        _ = satzLaufen(&a, sekunden: 0.5)
        a.satzBeenden()
        XCTAssertEqual(a.schritt, .fertig(.ohneKamera(gezaehlt: nil)))
    }

    func testSatzBeendenLiefertErgebnisMitRueckblickAbDrei() {
        var zwei = neu()
        _ = satzLaufen(&zwei, sekunden: 2 * 3 + 0.5)
        XCTAssertEqual(zwei.wiederholungen, 2)
        zwei.satzBeenden()
        guard case .fertig(.beendet(let e2)) = zwei.schritt else { return XCTFail("\(zwei.schritt)") }
        XCTAssertEqual(e2.wiederholungen, 2)
        XCTAssertNil(e2.rueckblick)
        XCTAssertEqual(try XCTUnwrap(e2.hubGrad), hub, accuracy: 10)

        var drei = neu()
        _ = satzLaufen(&drei, sekunden: 3 * 3 + 0.5)
        drei.satzBeenden()
        guard case .fertig(.beendet(let e3)) = drei.schritt else { return XCTFail("\(drei.schritt)") }
        XCTAssertEqual(e3.wiederholungen, 3)
        XCTAssertNotNil(e3.rueckblick)
    }

    func testOhneKameraNimmtGezaehlteMit() {
        var a = neu()
        _ = satzLaufen(&a, sekunden: 2 * 3 + 0.5)
        a.ohneKamera()
        XCTAssertEqual(a.schritt, .fertig(.ohneKamera(gezaehlt: 2)))

        var b = neu()
        b.ohneKamera()
        XCTAssertEqual(b.schritt, .fertig(.ohneKamera(gezaehlt: nil)))
    }

    func testPhaseFolgtDerSollwelle() {
        var a = neu()
        XCTAssertNil(a.phase)
        _ = satzLaufen(&a, sekunden: 1)
        XCTAssertEqual(a.phase, .senken)
    }
}
