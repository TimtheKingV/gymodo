import Foundation
import Testing
@testable import Sensorik

struct WinkelBerichtTests {
    @Test func zeileEinesKuenstlichenSatzes() {
        let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 12,
                                   eintraege: Synthetik.drehsatz(wiederholungen: 12).werte.map { .messwert($0) }, rateHz: 50)
        #expect(z.wdhFehler == 0)
        #expect(abs(z.hubGrad - 140) <= 3)
        #expect(z.sicherAnteil == 1)
        #expect(z.hubStreuung <= 0.02)
        #expect(z.groessterSprung <= 0.07) // erste Wiederholung: der vorlaeufige Massstab folgt dem Gipfel, dort steigt die Lage bis 0,064 je Messwert
        #expect(WinkelBericht.geeignet(z))
    }

    @Test func unterVierzigGradIstNichtGeeignet() {
        let z = WinkelBericht.zeile(ordner: "x", art: .stapel, pruefung: false, repsWahr: 10,
                                   eintraege: Synthetik.drehsatz(wiederholungen: 10, hubGrad: 25).werte.map { .messwert($0) }, rateHz: 50)
        #expect(!WinkelBericht.geeignet(z))
    }

    @Test func tragfaehigHaeltDieDreiSchwellen() {
        #expect(WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1, sicherAnteil: 0.9, spruenge: 0)))
        #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1.5, sicherAnteil: 0.9, spruenge: 0)))
        #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1, sicherAnteil: 0.89, spruenge: 0)))
        #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1, sicherAnteil: 0.9, spruenge: 1)))
        #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 0, wdhFehler: 0, sicherAnteil: 1, spruenge: 0)))
    }

    @Test func eulerSprungIstKeinSprungDerLage() {
        // Drehung um y von Pitch 30° aus: Pitch laeuft je Wiederholung durch 90°, Roll springt dort um 180°.
        // Ab der 5. Wiederholung springt Roll zusaetzlich kuenstlich um 180°, wo Pitch ueber 88° liegt.
        var werte = Synthetik.drehsatz(wiederholungen: 8, drehachse: Vektor3(x: 0, y: 1, z: 0), startPitch: 30).werte
        for i in werte.indices where werte[i].t > 3 + 4 * 4 && werte[i].winkel.y > 88 {
            let m = werte[i]; var r = m.winkel.x + 180; if r > 180 { r -= 360 }
            werte[i] = SensorMesswert(t: m.t, beschleunigung: m.beschleunigung, drehrate: m.drehrate, winkel: Vektor3(x: r, y: m.winkel.y, z: m.winkel.z))
        }
        let rollSprung = zip(werte, werte.dropFirst()).map { abs($1.winkel.x - $0.winkel.x) }.max()!
        #expect(rollSprung >= 170)
        let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: werte.map { .messwert($0) }, rateHz: 50)
        #expect(z.groessterSprung <= 0.07, "groesster Sprung \(z.groessterSprung)")
        #expect(WinkelBericht.tor([z]).spruenge == 0)
        #expect(z.wdhFehler == 0)
    }

    @Test func losBeiDerZeileStartetErstDort() {
        let satz = Synthetik.drehsatz(wiederholungen: 8, vorbewegung: Synthetik.Vorbewegung())
        let eintraege = satz.werte.map { SensorAufnahmeLeser.Eintrag.messwert($0) }
        let mit = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: eintraege,
                                      rateHz: 50, losBei: satz.losT)
        #expect(mit.wdhFehler == 0 && abs(mit.hubGrad - 140) <= 3)
        #expect(mit.losT.map { $0 >= satz.losT && $0 < satz.losT + 0.05 } == true)
        let ohne = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: eintraege, rateHz: 50)
        #expect(ohne.losT == nil && ohne.wdhFehler == 1)
    }

    @Test func startNachtraeglichNachDemAufnehmen() {
        // Aufnehmen um 100° hin, neue Ruhelage 70° neben der alten (wie an den Aufnahmen 60–110°):
        // los() faellt an das Ende der neuen Ruhelage (der letzte stille Messwert liegt kurz nach dem Beginn
        // der ersten Wiederholung bei 7 s, der Ausschlag dort ist unter 4°).
        let satz = Synthetik.drehsatz(wiederholungen: 8, vorbewegung: Synthetik.Vorbewegung(hinGrad: 100, ruheGrad: 70))
        let eintraege = satz.werte.map { SensorAufnahmeLeser.Eintrag.messwert($0) }
        let nach = WinkelBericht.startNachtraeglich(eintraege, rateHz: 50)
        #expect(nach.map { $0 > 4.5 && $0 < satz.losT + 0.8 } == true, "\(String(describing: nach))")
        let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: eintraege,
                                    rateHz: 50, losBei: nach)
        #expect(z.wdhFehler == 0 && abs(z.hubGrad - 140) <= 3)
    }

    @Test func losMarkeAusDerCSV() {
        #expect(WinkelBericht.losMarke(csv: "t,ax\n0.0,1\n# los 5.000000\n# takt oben 6.5\n") == 5.0)
        #expect(WinkelBericht.losMarke(csv: "t,ax\n0.0,1\n# marke satzbeginn 3.2\n") == nil)
    }

    @Test func macAufnahmeMitLosMarkeLaeuftUeberLos() throws {
        let mac = try WinkelBericht.paare().filter { $0.ohneStart.ordner.hasPrefix("2026-11-23-21") }
        #expect(mac.count == 11)
        #expect(mac.allSatisfy { $0.mitLosMarke && $0.ohneStart.losT == nil })
        // Alle Mac-Aufnahmen tragen `# los 5.000000`; los() kommt vor dem ersten Messwert ab 5 s.
        #expect(mac.allSatisfy { p in p.mitStart.losT.map { $0 >= 5 && $0 < 5.1 } == true })
        // Der Lauf mit Los-Marke endet an `# ende`; ohne Start laeuft die ganze Aufnahme.
        #expect(mac.allSatisfy { $0.mitStart.endeT != nil && $0.ohneStart.endeT == nil })
        // 2137-01: die zusaetzliche Wiederholung nach `# ende` (Ablegen) faellt weg.
        let a2137 = try #require(mac.first { $0.ohneStart.ordner == "2026-11-23-2137-01" })
        #expect(a2137.mitStart.erkannt < a2137.ohneStart.erkannt)
        #expect(mac.allSatisfy { $0.taktGipfel > 0 })
    }

    // MARK: Nachbesserung 1

    @Test func endeMarkeAusDerCSV() {
        #expect(WinkelBericht.endeMarke(csv: "t,ax\n# los 5.0\n0.0,1\n# ende 96.702000\n") == 96.702)
        #expect(WinkelBericht.endeMarke(csv: "t,ax\n0.0,1\n") == nil)
        #expect(WinkelBericht.taktGipfel(csv: "# takt oben 6.5\n# takt unten 9.0\n# takt oben 10.5\n") == 2)
    }

    @Test func endeBeiDerZeileHoertDortAuf() {
        // Nach 5 vollen Wiederholungen (3 s Ruhe + 5 · 4 s) und 0,5 s in die sechste hinein.
        let eintraege = Synthetik.drehsatz(wiederholungen: 8).werte.map { SensorAufnahmeLeser.Eintrag.messwert($0) }
        let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: eintraege,
                                    rateHz: 50, losBei: 2.5, endeBei: 23.5)
        #expect(z.erkannt == 5 && z.wdhFehler == 3)
        #expect(z.endeT.map { $0 >= 23.5 && $0 < 23.55 } == true)
    }

    /// Zeile mit vorgegebenen Kennzahlen.
    func zeile(_ o: String, hub: Double, fehler: Double, sprung: Double = 0.05, sicher: Double = 1) -> WinkelZeile {
        WinkelZeile(ordner: o, art: .kurzhantel, pruefung: false, repsWahr: 10, hubGrad: hub, wdhFehler: fehler,
                    sicherAnteil: sicher, hubStreuung: 0, groessterSprung: sprung)
    }

    @Test func vergleichNurUeberGemeinsamGeeigneteSaetze() {
        let paare = [
            WinkelPaar(ohneStart: zeile("a", hub: 100, fehler: 2), mitStart: zeile("a", hub: 100, fehler: 0), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("b", hub: 100, fehler: 4), mitStart: zeile("b", hub: 100, fehler: 0), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("c", hub: 190, fehler: 8, sprung: 5), mitStart: zeile("c", hub: 20, fehler: 8), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("d", hub: 30, fehler: 9), mitStart: zeile("d", hub: 60, fehler: 9, sprung: 0.5), mitLosMarke: false),
        ]
        let v = WinkelBericht.vergleich(paare)
        #expect(v.nurOhne == 1 && v.nurMit == 1 && v.gemeinsam == 2)
        #expect(v.ohne == WinkelTor(saetze: 2, wdhFehler: 3, sicherAnteil: 1, spruenge: 0))
        #expect(v.mit == WinkelTor(saetze: 2, wdhFehler: 0, sicherAnteil: 1, spruenge: 0))
    }

    @Test func geschaetzterStartSchlechterListetFehlerUndSprung() {
        let paare = [
            WinkelPaar(ohneStart: zeile("besser", hub: 100, fehler: 2), mitStart: zeile("besser", hub: 100, fehler: 0), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("fehler", hub: 100, fehler: 0), mitStart: zeile("fehler", hub: 100, fehler: 1), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("sprung", hub: 100, fehler: 0, sprung: 0.13), mitStart: zeile("sprung", hub: 100, fehler: 0, sprung: 0.72), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("klein", hub: 100, fehler: 0, sprung: 0.09), mitStart: zeile("klein", hub: 100, fehler: 0, sprung: 0.12), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("raus", hub: 197, fehler: 1.5), mitStart: zeile("raus", hub: 20, fehler: 3), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("nie", hub: 20, fehler: 1), mitStart: zeile("nie", hub: 20, fehler: 5), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("mac", hub: 100, fehler: 0), mitStart: zeile("mac", hub: 100, fehler: 1), mitLosMarke: true),
        ]
        #expect(WinkelBericht.schlechter(paare).map(\.ohneStart.ordner) == ["fehler", "sprung", "raus"])
    }

    @Test func woDerWinkelTraegtOhneNachtraeglichesWissen() {
        let paare = [
            WinkelPaar(ohneStart: zeile("a", hub: 30, fehler: 0), mitStart: zeile("a", hub: 60, fehler: 0), mitLosMarke: false),
            WinkelPaar(ohneStart: zeile("m", hub: 30, fehler: 0), mitStart: zeile("m", hub: 60, fehler: 0), mitLosMarke: true),
        ]
        #expect(WinkelBericht.traegtZeilen(paare).map(\.hubGrad) == [30, 60])
    }

    @Test func unbestimmbarerStartWirdMarkiert() {
        let p = WinkelBericht.paar(ordner: "leer", art: .kurzhantel, pruefung: false, repsWahr: 10, eintraege: [],
                                   rateHz: 50, uebung: "", csv: "t,ax\n")
        #expect(p.startUnbestimmt && p.mitStart.losT == nil)
        let text = WinkelBericht.markdown([p], ausgelassen: ["2026-01-01-0000-01"])
        #expect(text.contains("Sätze gelesen: 1, ausgelassen: 1 (2026-01-01-0000-01)"))
        #expect(text.contains("Kein Start bestimmbar: leer"))
        #expect(!text.contains("obere Schranke"))
    }

    @Test func macAufnahmenVom23NovemberSindDabei() throws {
        let zeilen = try WinkelBericht.zeilen()
        let mac = zeilen.filter { $0.ordner.hasPrefix("2026-11-23-21") }
        #expect(mac.count == 11)
        #expect(mac.allSatisfy { $0.pruefung })
        #expect(mac.filter(WinkelBericht.geeignet).count >= 7)
        #expect(zeilen.count >= 150)
    }

    /// Schreibt `data/sensoraufnahmen/tempobericht.md`: nur der Winkellage-Teil, genau eine H1.
    @Test func berichtSchreiben() throws {
        let text = try WinkelBericht.markdown(WinkelBericht.paare())
        #expect(text.split(separator: "\n").filter { $0.hasPrefix("# ") } == ["# Winkellage"])
        #expect(text.contains("## Winkel in Ruhe"))
        try text.write(to: Pfade.aufnahmen.appendingPathComponent("tempobericht.md"), atomically: true, encoding: .utf8)
    }

    @Test func woDerWinkelTraegtZaehltJeArtUndUebungUndSortiert() {
        func z(_ o: String, _ art: Befestigungsart?, _ uebung: String, _ hub: Double) -> WinkelZeile {
            WinkelZeile(ordner: o, art: art, pruefung: true, repsWahr: 10, hubGrad: hub, wdhFehler: 0,
                        sicherAnteil: 1, hubStreuung: 0, groessterSprung: 0, uebung: uebung)
        }
        let text = WinkelBericht.woDerWinkelTraegt([
            z("a", nil, "Zug", 90), z("b", .stapel, "Presse", 10), z("c", .stapel, "Curl", 50),
            z("d", .stapel, "Curl", 41), z("e", .kurzhantel, "Curl", 39), z("f", .stapel, "Row", 40)])
        let zeilen = text.split(separator: "\n").map(String.init).filter { $0.hasPrefix("| ") }
        #expect(zeilen == ["| Art | Übung | Aufnahmen | davon ab 40° |", "| stapel | Curl | 2 | 2 |",
                           "| stapel | Presse | 1 | 0 |", "| stapel | Row | 1 | 1 |",
                           "| kurzhantel | Curl | 1 | 0 |", "| ohne Art | Zug | 1 | 1 |"].map { $0 })
    }
}
