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
        kniebeugeSkelett(knie: winkel, ohneFuesse: ohneFuesse)
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

    func testNachDreiSekundenLaeuftDerSatz() throws {
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
        let beginn = try XCTUnwrap(countdownBeginn)
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

    func testZuSchnellNachEinerHalbenSekundeNebenDerBahn() throws {
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
        let neben = try XCTUnwrap(ersteNeben)
        let schnell = try XCTUnwrap(ersteSchnell)
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

    func testSatzBeendenLiefertErgebnisMitRueckblickAbDrei() throws {
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

    // MARK: Takt zurueck

    func testTaktKehrtNachZuSchnellInDieBahnZurueck() {
        var a = neu()
        let los = losen(&a)
        var t = los + 1 / rate
        // Senken in 1 s statt 2 s, bis `.zuSchnell` steht.
        while t < los + 1.4 {
            let ist = min(1, (t - los) / 1)
            a.bild(t: t, skelett: skelett(knie: oben - hub * (1 - cos(.pi * ist)) / 2))
            t += 1 / rate
        }
        XCTAssertEqual(a.takt, .zuSchnell)
        // Zurueck auf die Soll-Welle: erstes Bild in der Bahn setzt `.imTakt`.
        while t < los + 2.0 {
            a.bild(t: t, skelett: skelett(knie: nachWelle(t, los: los)))
            t += 1 / rate
        }
        XCTAssertEqual(a.takt, .imTakt)
    }

    // MARK: Task 3 Helfer

    /// Stand-Bilder bis die Los-Marke gesetzt ist; `t` laeuft weiter. Gibt die Los-Marke zurueck.
    func losen(_ a: inout KameraSatzAblauf, t: inout Double) -> Double {
        while t < 20, a.schritt != .satz {
            a.bild(t: t, skelett: skelett(knie: oben))
            t += 1 / rate
        }
        return t - 1 / rate
    }
    func losen(_ a: inout KameraSatzAblauf) -> Double {
        var t = 0.0
        return losen(&a, t: &t)
    }

    /// Bewegung nach der Welle (Hub `h`) von `t` bis `bis`; `ohneFuesse` blendet die Fuesse zeitweise aus.
    func lauf(_ a: inout KameraSatzAblauf, t: inout Double, los: Double, bis: Double, h: Double = 90,
              rate r: Double = 30, ohneFuesse: (Double) -> Bool = { _ in false }) {
        let welle = Sollwelle(vorgabe: tempo.vorgabe)
        while t < bis - 1e-9 {
            let w = oben - h * welle.lage(bei: max(0, t - los))
            a.bild(t: t, skelett: skelett(knie: w, ohneFuesse: ohneFuesse(t)))
            t += 1 / r
        }
    }

    func stillBis(_ a: inout KameraSatzAblauf, t: inout Double, bis: Double, rate r: Double = 30, ohneFuesse: Bool = false) {
        while t < bis - 1e-9 {
            a.bild(t: t, skelett: skelett(knie: oben, ohneFuesse: ohneFuesse))
            t += 1 / r
        }
    }

    // MARK: Tracking verloren

    func testAussetzerUnterEinerSekundeHaeltDenSatz() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        var immerSatz = true
        let ende = los + 5 * 3 + 0.5
        while t < ende {
            let fehlt = t >= los + 4.2 && t < los + 5.0
            a.bild(t: t, skelett: skelett(knie: nachWelle(t, los: los), ohneFuesse: fehlt))
            if a.schritt != .satz { immerSatz = false }
            t += 1 / rate
        }
        XCTAssertTrue(immerSatz)
        XCTAssertEqual(a.wiederholungen, 5)
    }

    func testPflichtgelenkLaengerAlsEineSekundeVerlorenPausiert() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        lauf(&a, t: &t, los: los, bis: los + 4)
        stillBis(&a, t: &t, bis: los + 4 + 1.3, ohneFuesse: true)
        XCTAssertEqual(a.schritt, .verloren)
        let eingefroren = a.sollzeit
        XCTAssertNotNil(eingefroren)
        XCTAssertEqual(a.takt, .imTakt)
        stillBis(&a, t: &t, bis: t + 1, ohneFuesse: true)
        XCTAssertEqual(a.sollzeit, eingefroren)
        XCTAssertEqual(a.schritt, .verloren)
    }

    func testWiedereinstiegMitZweiSekundenVorlaufUndNeuerLosMarke() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        // Zwei volle Wiederholungen, dann mitten in der dritten verloren.
        lauf(&a, t: &t, los: los, bis: los + 7)
        XCTAssertEqual(a.wiederholungen, 2)
        stillBis(&a, t: &t, bis: t + 1.3, ohneFuesse: true)
        XCTAssertEqual(a.schritt, .verloren)
        // Wieder im Bild, ruhig: nach 1 s Pruefung beginnt der Vorlauf.
        var raeste: [Int] = []
        let ende = t + 5
        while t < ende, a.schritt != .satz {
            a.bild(t: t, skelett: skelett(knie: oben))
            if case .vorlauf(let r) = a.schritt, raeste.last != r { raeste.append(r) }
            t += 1 / rate
        }
        XCTAssertEqual(raeste, [2, 1])
        XCTAssertEqual(a.schritt, .satz)
        XCTAssertEqual(a.sollzeit, 0)
        XCTAssertEqual(a.wiederholungen, 2)
        // Eine volle Wiederholung ab der neuen Los-Marke: genau eine mehr.
        let los2 = t - 1 / rate
        lauf(&a, t: &t, los: los2, bis: los2 + 3.5)
        XCTAssertEqual(a.wiederholungen, 3)
    }

    func testSatzBeendenAusVerlorenLiefertGezaehlte() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        lauf(&a, t: &t, los: los, bis: los + 7)
        stillBis(&a, t: &t, bis: t + 1.3, ohneFuesse: true)
        XCTAssertEqual(a.schritt, .verloren)
        a.satzBeenden()
        guard case .fertig(.beendet(let e)) = a.schritt else { return XCTFail("\(a.schritt)") }
        XCTAssertEqual(e.wiederholungen, 2)

        var b = neu()
        t = 0
        let los2 = losen(&b, t: &t)
        _ = los2
        stillBis(&b, t: &t, bis: t + 1.3, ohneFuesse: true)
        XCTAssertEqual(b.schritt, .verloren)
        b.satzBeenden()
        XCTAssertEqual(b.schritt, .fertig(.ohneKamera(gezaehlt: nil)))
    }

    // MARK: Satzende, keine Bewegung, Hub

    func testAchtSekundenRuheBeendenDenSatz() throws {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        lauf(&a, t: &t, los: los, bis: los + 9)
        XCTAssertEqual(a.wiederholungen, 3)
        let ende = t
        var fertigNach: Double?
        while t < ende + 10, fertigNach == nil {
            a.bild(t: t, skelett: skelett(knie: oben))
            if case .fertig(.beendet(let e)) = a.schritt { fertigNach = t - ende; XCTAssertEqual(e.wiederholungen, 3) }
            else { XCTAssertEqual(a.schritt, .satz) }
            t += 1 / rate
        }
        let nach = try XCTUnwrap(fertigNach)
        // Die Ruhe beginnt kurz nach dem Ende der letzten Bewegung (Ruhefenster 0,5 s).
        XCTAssertGreaterThan(nach, 8.0 - 0.1)
        XCTAssertLessThan(nach, 8.0 + 1.0)
    }

    func testRuheOhneWiederholungBeendetNichtSondernMeldetKeineBewegung() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        stillBis(&a, t: &t, bis: los + 5.9)
        XCTAssertEqual(a.schritt, .satz)
        stillBis(&a, t: &t, bis: los + 6.5)
        XCTAssertEqual(a.schritt, .keineBewegung)
        a.neuStarten()
        XCTAssertEqual(a.schritt, .countdown(rest: nil))
        // Danach laeuft es wie ein neuer Countdown bis zum Satz.
        let los2 = losen(&a, t: &t)
        XCTAssertEqual(a.schritt, .satz)
        XCTAssertEqual(a.sollzeit, 0)
        XCTAssertGreaterThan(los2, los)
        XCTAssertTrue(a.spur.count <= 1)
    }

    func testZuKleinerHubFuehrtZumHinweis() {
        var a = KameraSatzAblauf(vorgabe: kniebeuge, tempo: tempo, gemerkterHub: nil, mitVideo: false)
        var t = 0.0
        let los = losen(&a, t: &t)
        // 18 Grad: gross genug fuer die Zaehl-Schwelle, aber unter 20 Grad Hub.
        lauf(&a, t: &t, los: los, bis: los + 9, h: 18)
        XCTAssertEqual(a.schritt, .bewegungZuKlein)
        a.satzBeenden()
        XCTAssertEqual(a.schritt, .bewegungZuKlein)
        let n = a.wiederholungen
        a.ohneKamera()
        XCTAssertEqual(a.schritt, .fertig(.ohneKamera(gezaehlt: n > 0 ? n : nil)))
    }

    // MARK: Bildrate

    func testLangsameBildrateMeldetSich() {
        var a = neu()
        var t = 0.0
        _ = losen(&a, t: &t)
        XCTAssertFalse(a.bildrateZuNiedrig)
        stillBis(&a, t: &t, bis: t + 3.1, rate: 10)
        XCTAssertTrue(a.bildrateZuNiedrig)
        stillBis(&a, t: &t, bis: t + 3.1, rate: 30)
        XCTAssertFalse(a.bildrateZuNiedrig)
    }

    // MARK: Hintergrund

    func testHintergrundImSatzPausiertUndVerlangtAufstellen() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        lauf(&a, t: &t, los: los, bis: los + 4)
        let soll = a.sollzeit
        a.unterbrechen()
        XCTAssertEqual(a.schritt, .verloren)
        XCTAssertEqual(a.sollzeit, soll)
        XCTAssertEqual(a.wiederholungen, 1)
        // Die Pruefung beginnt von vorn: erst nach 1 s im Rahmen geht es mit dem Vorlauf weiter.
        stillBis(&a, t: &t, bis: t + 0.8)
        XCTAssertEqual(a.schritt, .verloren)
        stillBis(&a, t: &t, bis: t + 0.5)
        XCTAssertEqual(a.schritt, .vorlauf(rest: 2))

        var b = neu()
        t = 0
        stillBis(&b, t: &t, bis: 2)
        guard case .countdown = b.schritt else { return XCTFail("\(b.schritt)") }
        b.unterbrechen()
        XCTAssertEqual(b.schritt, .aufstellen)
    }

    // MARK: Beide Seiten

    /// Linker Arm curlt (Welle), rechter ruht, aber sicherer erkannt; `rechtsWeg` blendet den rechten Arm aus.
    func arme(links: Double, rechtsWeg: Bool = false) -> Skelett {
        var s = armSkelett(ellbogenL: links, ellbogenR: 170, sicherheitL: 0.6, sicherheitR: 1)
        if rechtsWeg { for g in [Gelenk.schulterR, .ellbogenR, .handR] { s.punkte[g] = nil } }
        return s
    }

    func testEinarmigFolgtDemArbeitendenArm() {
        let curl = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .beide)!
        var a = KameraSatzAblauf(vorgabe: curl, tempo: tempo, gemerkterHub: hub, mitVideo: false)
        var t = 0.0
        while t < 20, a.schritt != .satz {
            a.bild(t: t, skelett: arme(links: oben))
            t += 1 / rate
        }
        XCTAssertEqual(a.schritt, .satz)
        let los = t - 1 / rate
        let welle = Sollwelle(vorgabe: tempo.vorgabe)
        while t < los + 3 * 3 + 0.5 {
            a.bild(t: t, skelett: arme(links: oben - hub * welle.lage(bei: t - los)))
            t += 1 / rate
        }
        XCTAssertEqual(a.wiederholungen, 3)
        // Der ruhende rechte Arm faellt 2 s lang aus: keine Folgen, die Zaehlung folgt dem linken Arm.
        let ende = t + 2
        while t < ende {
            a.bild(t: t, skelett: arme(links: oben, rechtsWeg: true))
            XCTAssertEqual(a.schritt, .satz)
            t += 1 / rate
        }
    }

    // MARK: Review Task 3

    func testBewegungImVorlaufZaehltNicht() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        lauf(&a, t: &t, los: los, bis: los + 7)
        XCTAssertEqual(a.wiederholungen, 2)
        stillBis(&a, t: &t, bis: t + 1.3, ohneFuesse: true)
        XCTAssertEqual(a.schritt, .verloren)
        // Wieder im Bild; sobald der Vorlauf laeuft, eine ganze Wiederholung (1,8 s) hinein.
        while a.schritt == .verloren {
            a.bild(t: t, skelett: skelett(knie: oben))
            t += 1 / rate
        }
        XCTAssertEqual(a.schritt, .vorlauf(rest: 2))
        let beginn = t
        while a.schritt != .satz, t < beginn + 5 {
            let s = (t - beginn) / 1.8
            let w = oben - hub * (1 - cos(2 * .pi * min(1, s))) / 2
            a.bild(t: t, skelett: skelett(knie: w))
            XCTAssertEqual(a.wiederholungen, 2)
            t += 1 / rate
        }
        XCTAssertEqual(a.schritt, .satz)
        XCTAssertEqual(a.wiederholungen, 2)
    }

    func testBildrateWirdAusserhalbDesSatzesZurueckgesetzt() {
        var a = neu()
        var t = 0.0
        _ = losen(&a, t: &t)
        stillBis(&a, t: &t, bis: t + 3.1, rate: 10)
        XCTAssertTrue(a.bildrateZuNiedrig)
        a.unterbrechen()
        XCTAssertEqual(a.schritt, .verloren)
        XCTAssertFalse(a.bildrateZuNiedrig)

        var b = neu()
        t = 0
        _ = losen(&b, t: &t)
        stillBis(&b, t: &t, bis: t + 7, rate: 10)
        XCTAssertEqual(b.schritt, .keineBewegung)
        XCTAssertFalse(b.bildrateZuNiedrig)
    }

    func testKameraNeustartNachUnterbrechenMeldetKeineNiedrigeBildrate() {
        var a = neu()
        var t = 0.0
        let los = losen(&a, t: &t)
        lauf(&a, t: &t, los: los, bis: los + 4)
        a.unterbrechen()
        // Die Kamera war 5 s aus; danach kommen 30 Bilder/s durch Verloren und den 2-s-Vorlauf.
        t += 5
        let ende = t + 3.5
        while t < ende {
            a.bild(t: t, skelett: skelett(knie: oben))
            XCTAssertFalse(a.bildrateZuNiedrig, "bei t=\(t) \(a.schritt)")
            t += 1 / rate
        }
        XCTAssertEqual(a.schritt, .satz)
    }
}
