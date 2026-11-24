import XCTest
@testable import Koerperbild
import Sensorik

private let standardSoll = Tempovorgabe(kraftweg: 3, ablassen: 2, halten: 0)
private let schritt = 0.05

/// Lagen, die exakt der Soll-Welle folgen: Zeit und Sollzeit laufen gleich, ab `versatz` auf der Bildzeit.
private func folgendeLagen(von: Double, bis: Double, versatz: Double, welle: Sollwelle, sicher: Bool = true) -> [(Lage, Double)] {
    stride(from: von, through: bis + 1e-9, by: schritt).map { s in
        (Lage(t: s + versatz, lage: welle.lage(bei: s), richtung: .unbekannt, sicher: sicher), s)
    }
}

private func wiederholungen(anzahl: Int, soll: Tempovorgabe, versatz: Double = 0) -> [Koerperbild.Wiederholung] {
    (0..<anzahl).map { k in
        let beginn = Double(k) * soll.periode + versatz
        return Koerperbild.Wiederholung(beginn: beginn, umkehr: beginn + soll.kraftweg, ende: beginn + soll.periode)
    }
}

private func ergebnis(lagen: [(Lage, Double)], welle: Sollwelle, hubWarGemerkt: Bool, reps: [Koerperbild.Wiederholung]) -> Rueckblick? {
    var satz = Satzrueckblick(welle: welle, hubWarGemerkt: hubWarGemerkt)
    for (lage, s) in lagen { satz.erfasse(lage, sollzeit: s) }
    return satz.ergebnis(wiederholungen: reps)
}

func rueckblick(folgtDerWelle n: Int, hubWarGemerkt: Bool, unsicherIn: Int? = nil) -> Rueckblick? {
    let welle = Sollwelle(vorgabe: standardSoll)
    let reps = wiederholungen(anzahl: n, soll: standardSoll)
    var lagen: [(Lage, Double)] = []
    for (i, r) in reps.enumerated() {
        let sicher = (i + 1) != unsicherIn
        lagen += folgendeLagen(von: r.beginn, bis: r.ende - schritt, versatz: 0, welle: welle, sicher: sicher)
    }
    return ergebnis(lagen: lagen, welle: welle, hubWarGemerkt: hubWarGemerkt, reps: reps)
}

/// Wiederholung `ausreisser` hebt in `dauerHin` statt der Soll-Zeit und braucht fuer den Rueckweg die Soll-Zeit;
/// den Rest ihres Zeitfensters liegt die Last unten, die naechste Wiederholung beginnt wieder im Takt der Welle.
func rueckblick(mitAusreisser ausreisser: Int, dauerHin: Double, soll: Tempovorgabe, anzahl: Int = 8) -> Rueckblick? {
    let welle = Sollwelle(vorgabe: soll)
    let hinWelle = Sollwelle(vorgabe: Tempovorgabe(kraftweg: soll.kraftweg, ablassen: soll.ablassen, halten: 0))
    var reps = wiederholungen(anzahl: anzahl, soll: soll)
    var lagen: [(Lage, Double)] = []
    for (i, r) in reps.enumerated() {
        if i + 1 == ausreisser {
            let umkehr = r.beginn + dauerHin
            let ende = umkehr + soll.ablassen
            for s in stride(from: r.beginn, through: ende + 1e-9, by: schritt) {
                let l: Double
                if s < umkehr {
                    l = (1 - cos(Double.pi * (s - r.beginn) / dauerHin)) / 2
                } else {
                    l = hinWelle.lage(bei: soll.kraftweg + (s - umkehr))
                }
                lagen.append((Lage(t: s, lage: l, richtung: .unbekannt, sicher: true), s))
            }
            reps[i] = Koerperbild.Wiederholung(beginn: r.beginn, umkehr: umkehr, ende: ende)
        } else {
            lagen += folgendeLagen(von: r.beginn, bis: r.ende - schritt, versatz: 0, welle: welle)
        }
    }
    return ergebnis(lagen: lagen, welle: welle, hubWarGemerkt: true, reps: reps)
}

func urteil(dauer: Double, soll: Double) -> Tempourteil {
    Satzrueckblick.wegurteil(dauer: dauer, soll: soll)
}

/// `vor` Wiederholungen, `pause` Sekunden Stillstand, dann `nach` Wiederholungen mit Sollzeit wieder ab 0.
func rueckblickMitPause(vor: Int, pause: Double, nach: Int) -> Rueckblick? {
    let welle = Sollwelle(vorgabe: standardSoll)
    let versatz = Double(vor) * standardSoll.periode + pause
    var reps = wiederholungen(anzahl: vor, soll: standardSoll)
    reps += wiederholungen(anzahl: nach, soll: standardSoll, versatz: versatz)
    var lagen = folgendeLagen(von: 0, bis: Double(vor) * standardSoll.periode - schritt, versatz: 0, welle: welle)
    lagen += folgendeLagen(von: 0, bis: Double(nach) * standardSoll.periode - schritt, versatz: versatz, welle: welle)
    return ergebnis(lagen: lagen, welle: welle, hubWarGemerkt: true, reps: reps)
}

final class SatzrueckblickTests: XCTestCase {
    func testSaubererSatzIstGanzImTakt() {
        let r = rueckblick(folgtDerWelle: 8, hubWarGemerkt: true)!
        XCTAssertEqual(r.bewertet, 8); XCTAssertEqual(r.imTakt, 8)
        XCTAssertTrue(r.zuSchnellHin.isEmpty && r.zuLangsamRueck.isEmpty)
    }

    func testOhneGemerktenHubZaehlenDieErstenZweiNicht() {
        let r = rueckblick(folgtDerWelle: 8, hubWarGemerkt: false)!
        XCTAssertEqual(r.bewertet, 6); XCTAssertNil(r.urteile[0].imTakt); XCTAssertNil(r.urteile[1].imTakt)
    }

    func testZuSchnelleWiederholungWirdBenannt() {
        // Wiederholung 4: Hinweg 1,5 s statt 3 s, danach wieder im Takt der Welle.
        let r = rueckblick(mitAusreisser: 4, dauerHin: 1.5, soll: Tempovorgabe(kraftweg: 3, ablassen: 2, halten: 0))!
        XCTAssertEqual(r.zuSchnellHin, [4]); XCTAssertEqual(r.urteile[3].imTakt, false); XCTAssertEqual(r.imTakt, 7)
    }

    func testGenauAnDerToleranzIstImTempo() {
        XCTAssertEqual(urteil(dauer: 2.25, soll: 3), .imTempo)    // 75 %
        XCTAssertEqual(urteil(dauer: 2.2, soll: 3), .zuSchnell)
        XCTAssertEqual(urteil(dauer: 3.75, soll: 3), .imTempo)    // 125 %
        XCTAssertEqual(urteil(dauer: 3.8, soll: 3), .zuLangsam)
    }

    func testUeberwiegendUnsichereWiederholungBleibtLeer() {
        let r = rueckblick(folgtDerWelle: 6, hubWarGemerkt: true, unsicherIn: 3)!
        XCTAssertNil(r.urteile[2].imTakt); XCTAssertEqual(r.bewertet, 5)
    }

    func testZuKurzGibtKeinenRueckblick() {
        XCTAssertNil(rueckblick(folgtDerWelle: 2, hubWarGemerkt: true))
    }

    func testNachPauseGiltDieNeueSollzeit() {
        // Vier Wiederholungen, 10 s Pause, vier weitere mit Sollzeit wieder ab 0: alle im Takt.
        XCTAssertEqual(rueckblickMitPause(vor: 4, pause: 10, nach: 4)!.imTakt, 8)
    }
}
