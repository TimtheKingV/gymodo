import Testing
@testable import FitnessMember

/// Wohin das Kreuz der Einweisung fuehrt (Testnotiz 11.10., #6): auf die
/// Seite des Geraets, nicht zurueck zur Liste.
struct PfadregelTests {
    private let station = "geraet:m1"

    @Test func ausDerListeGehtEsEinenSchrittZurueckAufDieGeraeteseite() {
        let pfad: [GeraetRoute] = [.erkannt(station: station, token: nil),
                                   .geraet(station: station, exerciseId: "u1", token: nil)]
        #expect(Pfadregel.nachEinweisungAbbruch(pfad: pfad, uebungsanzahl: 3)
                == [.erkannt(station: station, token: nil)])
    }

    @Test func nachDemDirektsprungTrittDieGeraeteseiteAnDieStelleDesSatzpfads() {
        // Scan beim Stammgast: unter dem Satzpfad liegt nichts.
        let pfad: [GeraetRoute] = [.geraet(station: station, exerciseId: "u1", token: "t")]
        #expect(Pfadregel.nachEinweisungAbbruch(pfad: pfad, uebungsanzahl: 3)
                == [.erkannt(station: station, token: "t")])
    }

    @Test func mitNurEinerUebungGehtEsZurListe() {
        // Die Geraeteseite wird fuer dieses Geraet uebersprungen (#4) --
        // sie hier doch zu zeigen, waere eine Seite, die sonst nie kommt.
        let pfad: [GeraetRoute] = [.geraet(station: station, exerciseId: "u1", token: nil)]
        #expect(Pfadregel.nachEinweisungAbbruch(pfad: pfad, uebungsanzahl: 1) == [])
    }

    @Test func einLeererPfadBleibtLeer() {
        #expect(Pfadregel.nachEinweisungAbbruch(pfad: [], uebungsanzahl: 3) == [])
    }
}
