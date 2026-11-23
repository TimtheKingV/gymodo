import Foundation
import Testing
@testable import Sensorik

struct TempoBerichtTests {
    /// Sinus mit 2 s Periode bei 50 Hz, 20 s lang, zwischen 0 und 1.
    private func sinus(laenge: Int = 1000) -> [Double] {
        (0..<laenge).map { 0.5 - 0.5 * cos(2 * .pi * Double($0) / 100) }
    }

    /// Der Sinus um `um` Messwerte spaeter: der Anfang haelt den ersten Wert.
    private func verschoben(um: Int) -> [Double] {
        let s = sinus()
        return s.indices.map { s[max(0, $0 - um)] }
    }

    @Test func bezugTrifftDieWahrheitEinesKuenstlichenSatzes() throws {
        let satz = Synthetik.hub(wiederholungen: 12)
        let b = try #require(Lagebezug.berechne(satz.werte, rateHz: 50))
        #expect(abs(b.periode - 4.0) <= 0.2)
        let diff = b.aktiv.map { abs(b.lage[$0] - satz.lage[$0]) }
        #expect(diff.reduce(0, +) / Double(diff.count) <= 0.08)
    }

    /// Eine steigende Last ergibt eine steigende Lage, auch wenn der Sensor
    /// schraeg haengt: Oben ist gegen die Schwerkraft.
    @Test func bezugSteigtMitDerLastAuchSchraeg() throws {
        let satz = Synthetik.hub(wiederholungen: 8, achse: Vektor3(x: 0.6, y: 0, z: 0.8))
        let b = try #require(Lagebezug.berechne(satz.werte, rateHz: 50))
        let diff = b.aktiv.map { abs(b.lage[$0] - satz.lage[$0]) }
        #expect(diff.reduce(0, +) / Double(diff.count) <= 0.08)
    }

    @Test func dasTorHaeltDieDreiSchwellen() {
        #expect(TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.15, ausreisser: 0)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 151, abweichung: 0.15, ausreisser: 0)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.16, ausreisser: 0)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.15, ausreisser: 1)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 0, verzoegerungMs: 0, abweichung: 0, ausreisser: 0)))
    }

    @Test func verzoegerungEinesVerschobenenSignalsWirdGemessen() {
        // live = bezug um 6 Messwerte (120 ms bei 50 Hz) verzoegert
        #expect(abs(TempoBericht.verzoegerungMs(live: verschoben(um: 6), bezug: sinus(), rateHz: 50) - 120) <= 20)
    }

    @Test func torNimmtDieMedianeDerArt() {
        func z(_ art: Befestigungsart, _ ms: Double, _ ab: Double, _ aus: Bool) -> TempoZeile {
            TempoZeile(ordner: "x", art: art, verzoegerungMs: ms, abweichung: ab, ausreisser: aus, sicherAnteil: 1)
        }
        let t = TempoBericht.tor([z(.stapel, 100, 0.1, false), z(.stapel, 200, 0.3, true),
                                  z(.stapel, 120, 0.2, false), z(.kurzhantel, 999, 9, true)], art: .stapel)
        #expect(t == TempoTor(saetze: 3, verzoegerungMs: 120, abweichung: 0.2, ausreisser: 1))
    }

    /// Schreibt den Bericht und haelt jede freigegebene Art am Tor fest.
    @Test func berichtSchreibenUndFreigegebeneArtenPruefen() throws {
        let zeilen = try TempoBericht.zeilen()
        #expect(zeilen.count >= 120)
        try TempoBericht.markdown(zeilen).write(to: Pfade.aufnahmen.appendingPathComponent("tempobericht.md"),
                                               atomically: true, encoding: .utf8)
        for art in Tempofreigabe.arten {
            let t = TempoBericht.tor(zeilen, art: art)
            #expect(TempoBericht.torErreicht(t), "\(art.rawValue) ist freigegeben, haelt das Tor aber nicht: \(t)")
        }
    }
}
