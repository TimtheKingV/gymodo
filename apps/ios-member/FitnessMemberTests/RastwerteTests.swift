import Testing
@testable import FitnessMember

struct RastwerteTests {
    @Test func rastetAufDieSchrittweiteDesGeraets() {
        // designsystem.md SS7: die Rastung kommt aus dem Geraet, nicht aus
        // dem Entwurf. Ein Wert, den das Geraet nicht kann, wird damit
        // strukturell unmoeglich.
        let werte = Rastwerte.belastung(min: 5, max: 15, schritt: 2.5)
        #expect(werte == [5.0, 7.5, 10.0, 12.5, 15.0])
    }

    @Test func andereSchrittweiteAnderesRad() {
        let werte = Rastwerte.belastung(min: 10, max: 30, schritt: 5)
        #expect(werte == [10.0, 15.0, 20.0, 25.0, 30.0])
    }

    @Test func schliesstDasMaximumEinAuchWennEsNichtAufDerRasterFaellt() {
        // Quotient (12-5)/2.5 = 2,8 -- absichtlich ueber ,5, damit ein
        // versehentliches `.rounded()` statt `.rounded(.down)` hier auf 3
        // aufrunden und 12,5 liefern wuerde, statt bei 10 zu bleiben. Mit
        // max: 11 (Quotient 2,4) waere das nicht unterscheidbar gewesen.
        let werte = Rastwerte.belastung(min: 5, max: 12, schritt: 2.5)
        #expect(werte.last == 10.0)
        #expect(werte.allSatisfy { $0 <= 12 })
    }

    @Test func rastetKorrektTrotzGleitkommaUngenauigkeitAnDerGrenze() {
        // (0,3 - 0) / 0,1 wird in Gleitkomma zu 2.9999999999999996 statt 3.
        // Ohne Toleranz vor dem Abrunden wuerde 0,3 -- ein Wert, den das
        // Geraet tatsaechlich kann -- aus der Liste fallen (auf 0,2). Der
        // Vergleich toleriert die uebliche Gleitkomma-Odyssee von "3 * 0,1"
        // selbst statt sie mit `==` gegen das Literal zu verwechseln.
        let werte = Rastwerte.belastung(min: 0, max: 0.3, schritt: 0.1)
        #expect(abs(werte.last! - 0.3) < 1e-9)
    }

    @Test func ohneObergrenzeEndetDasRadNachZweihundertRasten() {
        // loadMax ist nullable. Der Server rechnet dort mit 9999 --
        // als Radlaenge waere das absurd.
        let werte = Rastwerte.belastung(min: 5, max: nil, schritt: 2.5)
        #expect(werte.count == Rastwerte.maxRastenOhneObergrenze + 1)
        #expect(werte.first == 5.0)
    }

    @Test func schuetztVorEinerUnbrauchbarenSchrittweite() {
        #expect(Rastwerte.belastung(min: 5, max: 100, schritt: 0) == [5.0])
        #expect(Rastwerte.belastung(min: 5, max: 100, schritt: -1) == [5.0])
    }

    @Test func wiederholungenRastenAufEins() {
        let werte = Rastwerte.umfang(.reps)
        #expect(werte.first == 1)
        #expect(werte.last == 40)
        #expect(werte.count == 40)
    }

    @Test func sekundenRastenAufHalbeMinutenBisNeunzigMinuten() {
        let werte = Rastwerte.umfang(.seconds)
        #expect(werte.first == 30)
        #expect(werte[1] == 60)
        #expect(werte.last == 5400)
        #expect(werte.count == 180)
    }

    @Test func meterRastenAufHundertBisZwanzigKilometer() {
        let werte = Rastwerte.umfang(.meters)
        #expect(werte.first == 100)
        #expect(werte[1] == 200)
        #expect(werte.last == 20_000)
        #expect(werte.count == 200)
    }

    @Test func keinUmfangsradIstLaengerAlsEinBelastungsradOhneAnschlag() {
        // Dieselbe Groessenordnung: was fuer den Daumen an einem Rad ohne
        // Obergrenze geht, geht auch hier.
        for art in [VolumeKind.reps, .seconds, .meters] {
            #expect(Rastwerte.umfang(art).count <= Rastwerte.maxRastenOhneObergrenze + 1)
        }
    }

    @Test func einUmfangAbseitsDerRasterRastetAufDenNaechstenWert() {
        // Cardio-Spec Abschnitt 12: 1195 s rastet auf 1200.
        #expect(Rastwerte.naechster(zu: 1195, in: Rastwerte.umfang(.seconds)) == 1200)
        #expect(Rastwerte.naechster(zu: 10, in: Rastwerte.umfang(.seconds)) == 30)
        #expect(Rastwerte.naechster(zu: 99_999, in: Rastwerte.umfang(.meters)) == 20_000)
        // Wiederholungen: dasselbe Klemmen wie vor dem Umbau.
        #expect(Rastwerte.naechster(zu: 0, in: Rastwerte.umfang(.reps)) == 1)
        #expect(Rastwerte.naechster(zu: 55, in: Rastwerte.umfang(.reps)) == 40)
        #expect(Rastwerte.naechster(zu: 11, in: Rastwerte.umfang(.reps)) == 11)
    }

    @Test func dieNebenbelastungRastetWieDieBelastung() {
        // Neigung am Laufband: 0 bis 15 Prozent in halben Schritten.
        let werte = Rastwerte.belastung(min: 0, max: 15, schritt: 0.5)
        #expect(werte.count == 31)
        #expect(werte.first == 0)
        #expect(werte.last == 15)
    }

    @Test func dasKoerpergewichtsradRastetNachDerselbenRechnung() {
        #expect(Rastwerte.gewichte(min: 20, max: 400, schritt: 0.5)
                == Rastwerte.belastung(min: 20, max: 400, schritt: 0.5))
    }

    @Test func naechsterWertRastetAufDieListe() {
        let werte = Rastwerte.belastung(min: 5, max: 100, schritt: 2.5)
        #expect(Rastwerte.naechster(zu: 81.2, in: werte) == 80.0)
        #expect(Rastwerte.naechster(zu: 1.0, in: werte) == 5.0)
        #expect(Rastwerte.naechster(zu: 999, in: werte) == 100.0)
    }
}
