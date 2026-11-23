import Foundation
import Testing
@testable import Sensorik

/// Winkel-Versuch (Task 5b): Schwerkraftrichtung je Messwert aus den Winkeln
/// des Sensors oder aus der aufintegrierten Drehrate.
struct SchwerkraftquelleTests {
    private func nah(_ a: Vektor3, _ b: Vektor3, _ toleranz: Double = 1e-9) -> Bool {
        abs(a.x - b.x) <= toleranz && abs(a.y - b.y) <= toleranz && abs(a.z - b.z) <= toleranz
    }

    /// Roll dreht um x, Pitch um y; gemessen in Ruhe an den Aufnahmen (siehe
    /// `winkelTreffenInRuheDieGemesseneBeschleunigung`).
    @Test func richtungAusRollUndPitch() {
        #expect(nah(Schwerkraftquelle.richtung(winkel: Vektor3(x: 0, y: 0, z: 37)), Vektor3(x: 0, y: 0, z: 1)))
        #expect(nah(Schwerkraftquelle.richtung(winkel: Vektor3(x: 90, y: 0, z: 0)), Vektor3(x: 0, y: 1, z: 0)))
        #expect(nah(Schwerkraftquelle.richtung(winkel: Vektor3(x: 0, y: 90, z: 0)), Vektor3(x: -1, y: 0, z: 0)))
        #expect(nah(Schwerkraftquelle.richtung(winkel: Vektor3(x: 180, y: 0, z: 0)), Vektor3(x: 0, y: 0, z: -1)))
    }

    /// Ein ortsfester Vektor dreht sich im Sensorrahmen gegen die Drehrate.
    @Test func drehenFolgtDerDrehrate() {
        var g = Vektor3(x: 0, y: 0, z: 1)
        // 90 °/s um x ueber eine Sekunde: (0, sin θ, cos θ) mit θ = 90°.
        for _ in 0..<50 { g = Schwerkraftquelle.drehen(g, drehrate: Vektor3(x: 90, y: 0, z: 0), dt: 0.02) }
        #expect(nah(g, Vektor3(x: 0, y: 1, z: 0), 1e-9))
    }

    /// B1: Die aus Roll und Pitch berechnete Richtung trifft in Ruhe die gemessene
    /// Beschleunigung; je Art im Median hoechstens 3°.
    @Test func winkelTreffenInRuheDieGemesseneBeschleunigung() throws {
        let fehler = try TempoBericht.ruhewinkelfehler(TempoBericht.aufnahmen())
        for art in TempoBericht.arten {
            let f = try #require(fehler[art])
            #expect(f.count >= 1000, "\(art.rawValue): nur \(f.count) ruhende Messwerte")
            #expect(TempoBericht.median(f) <= 3, "\(art.rawValue): \(TempoBericht.median(f))°")
        }
    }

    /// Mittlerer Fehler ab Wdh. 3 gegen die Wahrheit, wie in `LageschaetzerTests`.
    private func mittlererFehler(_ satz: Synthetik.Hubsatz, quelle: Schwerkraftquelle) -> Double {
        var s = Lageschaetzer(rateHz: 50, schwerkraft: quelle)
        let lagen = satz.werte.map { s.verarbeite($0) }
        let beginne = satz.lage.indices.dropFirst().filter {
            abs(satz.lage[$0 - 1]) < 1e-12 && abs(satz.lage[$0]) >= 1e-12
        }
        let ab = beginne[2]
        let d = (ab..<satz.lage.count).map { abs(lagen[$0].lage - satz.lage[$0]) }
        return d.reduce(0, +) / Double(d.count)
    }

    /// Der Mechanismus der Hanteln: Kippt die Last je Wiederholung um 80°, liegt die
    /// Schwerkraft nicht mehr dort, wo sie in Ruhe lag, und die Projektion darauf
    /// erzeugt Scheinbeschleunigung von fast 1 g. `.ruhe` versagt daran.
    @Test func gekippteHantelLaesstDieRuheSchwerkraftVersagen() {
        let satz = Synthetik.hub(wiederholungen: 12, drehungGrad: 80)
        #expect(mittlererFehler(satz, quelle: .ruhe) > 0.3)
    }

    @Test(arguments: [Schwerkraftquelle.winkel, .drehrate])
    func gekippteHantelFolgtMitBekannterSchwerkraft(quelle: Schwerkraftquelle) {
        let satz = Synthetik.hub(wiederholungen: 12, drehungGrad: 80)
        #expect(mittlererFehler(satz, quelle: quelle) <= 0.12)
    }

    /// Ohne Drehung aendern die neuen Quellen nichts Wesentliches.
    @Test(arguments: [Schwerkraftquelle.winkel, .drehrate])
    func ohneDrehungWieRuhe(quelle: Schwerkraftquelle) {
        let satz = Synthetik.hub(wiederholungen: 12)
        #expect(mittlererFehler(satz, quelle: quelle) <= 0.08)
    }

    /// Das Kunstsignal ist stimmig: Winkel, Drehrate und Beschleunigung beschreiben dieselbe Kippung.
    @Test func kunstsignalIstStimmig() {
        let satz = Synthetik.hub(wiederholungen: 3, drehungGrad: 80)
        var g = Vektor3(x: 0, y: 0, z: 1)
        var groessterFehler = 0.0
        for m in satz.werte.dropFirst() {
            g = Schwerkraftquelle.drehen(g, drehrate: m.drehrate, dt: 0.02)
            let w = Schwerkraftquelle.richtung(winkel: m.winkel)
            groessterFehler = max(groessterFehler, abs(g.x - w.x) + abs(g.y - w.y) + abs(g.z - w.z))
        }
        // Gedreht wird mit der Drehrate am Ende des Schritts: Das eilt um einen halben
        // Schritt nach (θ'·dt/2, hier bis 0,8°), laeuft aber nicht weg.
        #expect(groessterFehler <= 0.03)
    }
}
