import Foundation
import Testing
import Sensorik   // bewusst ohne @testable: hier zaehlt nur, was die App sieht

/// Was die App aus dem Package braucht, muss oeffentlich sein (Fix-Welle B.9 und die neuen Teile aus B).
struct OeffentlicheSchnittstelleTests {
    @Test func tempoergebnisLaesstSichAnlegen() {
        let e = Tempoergebnis(quote: 0.8, perioden: [1, nil, 0.6], kraftweg: .imTempo, ablassen: .zuSchnell(1, von: 2))
        #expect(e.quote == 0.8 && e.perioden.count == 3 && e.ablassen == .zuSchnell(1, von: 2))
    }

    @Test func satzablaufDerWinkellage() {
        var s = Winkellage(rateHz: 50, wartetAufLos: true)
        s.los()
        _ = s.verarbeite(SensorMesswert(t: 7, beschleunigung: Vektor3(x: 0, y: 0, z: 1), drehrate: Vektor3(x: 0, y: 0, z: 0),
                                        winkel: Vektor3(x: 0, y: 0, z: 0)))
        #expect(s.losZeit == 7 && s.sekundenSeitLos(9.5) == 2.5)
        s.ende()
        #expect(Sollwelle(vorgabe: .standard, halbeBahnbreite: 0.3).halbeBahnbreite == 0.3)
    }
}
