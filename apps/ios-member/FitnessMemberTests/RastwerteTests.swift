import Testing
@testable import FitnessMember

struct RastwerteTests {
    @Test func rastetAufDieSchrittweiteDesGeraets() {
        // designsystem.md SS7: die Rastung kommt aus dem Geraet, nicht aus
        // dem Entwurf. Ein Wert, den das Geraet nicht kann, wird damit
        // strukturell unmoeglich.
        let werte = Rastwerte.gewichte(min: 5, max: 15, schritt: 2.5)
        #expect(werte == [5.0, 7.5, 10.0, 12.5, 15.0])
    }

    @Test func andereSchrittweiteAnderesRad() {
        let werte = Rastwerte.gewichte(min: 10, max: 30, schritt: 5)
        #expect(werte == [10.0, 15.0, 20.0, 25.0, 30.0])
    }

    @Test func schliesstDasMaximumEinAuchWennEsNichtAufDerRasterFaellt() {
        let werte = Rastwerte.gewichte(min: 5, max: 11, schritt: 2.5)
        #expect(werte.last == 10.0)
        #expect(werte.allSatisfy { $0 <= 11 })
    }

    @Test func ohneObergrenzeEndetDasRadNachZweihundertRasten() {
        // maxWeightKg ist nullable. Der Server rechnet dort mit 9999 --
        // als Radlaenge waere das absurd.
        let werte = Rastwerte.gewichte(min: 5, max: nil, schritt: 2.5)
        #expect(werte.count == Rastwerte.maxRastenOhneObergrenze + 1)
        #expect(werte.first == 5.0)
    }

    @Test func schuetztVorEinerUnbrauchbarenSchrittweite() {
        #expect(Rastwerte.gewichte(min: 5, max: 100, schritt: 0) == [5.0])
        #expect(Rastwerte.gewichte(min: 5, max: 100, schritt: -1) == [5.0])
    }

    @Test func wiederholungenRastenAufEins() {
        #expect(Rastwerte.wiederholungen.first == 1)
        #expect(Rastwerte.wiederholungen.last == 40)
        #expect(Rastwerte.wiederholungen.count == 40)
    }

    @Test func naechsterWertRastetAufDieListe() {
        let werte = Rastwerte.gewichte(min: 5, max: 100, schritt: 2.5)
        #expect(Rastwerte.naechster(zu: 81.2, in: werte) == 80.0)
        #expect(Rastwerte.naechster(zu: 1.0, in: werte) == 5.0)
        #expect(Rastwerte.naechster(zu: 999, in: werte) == 100.0)
    }
}
