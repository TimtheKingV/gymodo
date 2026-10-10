import Foundation
import Testing
@testable import Sensorik

struct GueteberichtTests {
    private func ergebnis(_ wahr: Int, _ gezaehlt: Int, unsicher: UnsicherGrund? = nil,
                          tag: Int = 1, fuer: Bool = true, art: Befestigungsart = .langhantel) -> AufnahmeErgebnis {
        let start = Date(timeIntervalSince1970: 1_800_000_000 + Double(tag) * 86_400)
        return AufnahmeErgebnis(ordner: "x", startedAt: start, art: art, repsWahr: wahr, fuerZaehler: fuer,
                                gezaehlt: gezaehlt, unsicher: unsicher, ereignisse: [])
    }

    /// Ruecknahmen zaehlen nicht als Fehlzaehlung, aber als eigene Quote
    /// (Spec B 5.5) -- sonst wuerde ein Zaehler belohnt, der nie zweifelt.
    @Test func quotenTrennenRuecknahmenVonFehlzaehlungen() {
        let q = Guetebericht.quoten([
            ergebnis(10, 10, tag: 1), ergebnis(10, 9, tag: 2), ergebnis(10, 7, tag: 3),
            ergebnis(10, 4, unsicher: .luecke, tag: 3),
        ])
        #expect(q.saetze == 4)
        #expect(q.tage == 3)
        #expect(q.ruecknahmen == 0.25)
        #expect(abs(q.exakt - 1.0 / 3) < 1e-9)
        #expect(abs(q.plusMinusEins - 2.0 / 3) < 1e-9)
    }

    @Test func dasTorBrauchtMengeTageUndQuoten() {
        let gut = Quoten(saetze: 20, tage: 3, exakt: 0.9, plusMinusEins: 0.98, ruecknahmen: 0.1)
        #expect(Guetebericht.torErreicht(gut))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 19, tage: 3, exakt: 1, plusMinusEins: 1, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 2, exakt: 1, plusMinusEins: 1, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 3, exakt: 0.89, plusMinusEins: 1, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 3, exakt: 1, plusMinusEins: 0.97, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 3, exakt: 1, plusMinusEins: 1, ruecknahmen: 0.11)))
    }

    /// Ohne eingefrorenes Profil gibt es kein Torset: wer noch abstimmt,
    /// kann sich nicht selbst pruefen.
    @Test func ohneEingefrorenesProfilIstDasTorsetLeer() {
        #expect(ZaehlerProfil.fuer(.langhantel).eingefrorenAm == nil)
        #expect(Guetebericht.torset([ergebnis(10, 10)], art: .langhantel).isEmpty)
    }

    @Test func ohneSaetzeSindDieQuotenNull() {
        #expect(Guetebericht.quoten([]) == Quoten(saetze: 0, tage: 0, exakt: 0, plusMinusEins: 0, ruecknahmen: 0))
    }

    /// Schreibt den Bericht und haelt jede freigegebene Art am Tor fest.
    @Test func berichtSchreibenUndFreigegebeneArtenPruefen() throws {
        let ergebnisse = try AufnahmeLauf.ueberAlle()
        let text = Guetebericht.markdown(ergebnisse)
        try text.write(to: Pfade.aufnahmen.appendingPathComponent("guetebericht.md"),
                       atomically: true, encoding: .utf8)
        for art in Befestigungsart.freigegeben {
            let q = Guetebericht.quoten(Guetebericht.torset(ergebnisse, art: art))
            #expect(Guetebericht.torErreicht(q), "\(art.rawValue) ist freigegeben, haelt das Tor aber nicht: \(q)")
        }
    }
}
