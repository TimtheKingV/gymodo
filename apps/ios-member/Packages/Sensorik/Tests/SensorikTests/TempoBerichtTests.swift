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
        // Vorlauf zaehlt wie Nachlauf: der Betrag der Verzoegerung haelt die Schwelle.
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: -151, abweichung: 0.15, ausreisser: 0)))
        #expect(TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: -150, abweichung: 0.15, ausreisser: 0)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.16, ausreisser: 0)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.15, ausreisser: 1)))
        #expect(!TempoBericht.torErreicht(TempoTor(saetze: 0, verzoegerungMs: 0, abweichung: 0, ausreisser: 0)))
    }

    @Test func aufnahmenTeilenSichNachDemDatumImOrdnernamen() {
        #expect(TempoBericht.teil("2026-10-04-0850-01") == .abstimmung)
        #expect(TempoBericht.teil("2026-10-31-2359-02") == .abstimmung)
        #expect(TempoBericht.teil("2026-11-01-0000-01") == .pruefung)
        #expect(TempoBericht.teil("2026-11-10-1815-01") == .pruefung)
    }

    @Test func tragfaehigVerlangtTorSicherheitUndWiederholungen() {
        let gut = TempoTor(saetze: 20, verzoegerungMs: -40, abweichung: 0.1, ausreisser: 0,
                           sicherAnteil: 0.8, wiederholungsfehler: 1)
        #expect(TempoBericht.tragfaehig(gut))
        var t = gut; t.sicherAnteil = 0.79
        #expect(!TempoBericht.tragfaehig(t))
        t = gut; t.wiederholungsfehler = 1.5
        #expect(!TempoBericht.tragfaehig(t))
        t = gut; t.abweichung = 0.16
        #expect(!TempoBericht.tragfaehig(t))
    }

    /// Ein sauberer kuenstlicher Satz mit 8 Wiederholungen hat 16 Umkehrpunkte:
    /// gegen die Wahrheit 8 kein Fehler, gegen 10 zwei Wiederholungen.
    @Test func wiederholungenGegenDieWahrheitAmKuenstlichenSatz() throws {
        let satz = Synthetik.hub(wiederholungen: 8)
        let genau = try #require(TempoBericht.zeile(ordner: "2026-10-01-0000-01", art: .stapel, werte: satz.werte,
                                                   rateHz: 50, repsWahr: 8))
        #expect(genau.wiederholungsfehler == 0)
        #expect(genau.teil == .abstimmung)
        let daneben = try #require(TempoBericht.zeile(ordner: "2026-11-01-0000-01", art: .stapel, werte: satz.werte,
                                                     rateHz: 50, repsWahr: 10))
        #expect(daneben.wiederholungsfehler == 2)
        #expect(daneben.teil == .pruefung)
        // Sauber bewegt traegt die Lage: Abweichung ueber sichere Messwerte klein, nichts ausserhalb.
        #expect(try #require(genau.abweichungSicher) <= 0.08)
        #expect(!genau.ausreisser)
    }

    @Test func verzoegerungEinesVerschobenenSignalsWirdGemessen() {
        // live = bezug um 6 Messwerte (120 ms bei 50 Hz) verzoegert
        #expect(abs(TempoBericht.verzoegerungMs(live: verschoben(um: 6), bezug: sinus(), rateHz: 50) - 120) <= 20)
    }

    @Test func torNimmtDieMedianeDerArt() {
        func z(_ art: Befestigungsart, _ ms: Double, _ ab: Double, _ aus: Bool) -> TempoZeile {
            TempoZeile(ordner: "x", art: art, verzoegerungMs: ms, abweichung: ab, abweichungSicher: ab / 2,
                       ausreisser: aus, sicherAnteil: 1, wiederholungsfehler: ab * 10)
        }
        let t = TempoBericht.tor([z(.stapel, 100, 0.1, false), z(.stapel, -200, 0.3, true),
                                  z(.stapel, -120, 0.2, false), z(.kurzhantel, 999, 9, true)], art: .stapel)
        #expect(t == TempoTor(saetze: 3, verzoegerungMs: -120, abweichung: 0.2, ausreisser: 1,
                              verzoegerungBetragMs: 120, abweichungSicher: 0.1, sicherAnteil: 1,
                              wiederholungsfehler: 2))
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
