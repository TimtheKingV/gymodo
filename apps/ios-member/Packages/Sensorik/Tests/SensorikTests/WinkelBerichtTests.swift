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

    @Test func einSprungDerAchseWirdGezaehltNichtVerschluckt() {
        // Ab der 5. Wiederholung springt der Rollwinkel um 180° (wie nahe Pitch ±90°)
        var werte = Synthetik.drehsatz(wiederholungen: 8).werte
        for i in werte.indices where werte[i].t > 3 + 4 * 4 {
            let m = werte[i]; var r = m.winkel.x + 180; if r > 180 { r -= 360 }
            werte[i] = SensorMesswert(t: m.t, beschleunigung: m.beschleunigung, drehrate: m.drehrate, winkel: Vektor3(x: r, y: m.winkel.y, z: m.winkel.z))
        }
        let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: werte.map { .messwert($0) }, rateHz: 50)
        #expect(z.groessterSprung > 0.2)
        #expect(WinkelBericht.tor([z]).spruenge == 1)
    }

    @Test func macAufnahmenVom23NovemberSindDabei() throws {
        let zeilen = try WinkelBericht.zeilen()
        let mac = zeilen.filter { $0.ordner.hasPrefix("2026-11-23-21") }
        #expect(mac.count == 11)
        #expect(mac.allSatisfy { $0.pruefung })
        #expect(mac.filter(WinkelBericht.geeignet).count >= 7)
        #expect(zeilen.count >= 150)
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
