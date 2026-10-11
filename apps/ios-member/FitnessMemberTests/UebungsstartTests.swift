import Foundation
import Testing
@testable import FitnessMember

/// Der Drawer vor einer Uebung (Testnotiz 11.10., #6, #10, #11): eine neue
/// Uebung zeigt erst die Einweisung, jede endet bei den Startwerten.
struct UebungsstartTests {

    @Test func erstkontaktMitEinstellparameternZeigtAlleDreiSchritte() {
        #expect(Uebungsstart.schritte(erstkontakt: true, fragtEinstellung: true)
                == [.einweisung, .einstellung, .startwerte])
    }

    @Test func erstkontaktOhneEinstellparameterUeberspringtDieEinstellung() {
        #expect(Uebungsstart.schritte(erstkontakt: true, fragtEinstellung: false)
                == [.einweisung, .startwerte])
    }

    /// Eine schon trainierte Uebung braucht keine Einweisung -- der Drawer
    /// zeigt gleich, was beim letzten Mal galt (#10).
    @Test func eineBekannteUebungZeigtNurDieStartwerte() {
        #expect(Uebungsstart.schritte(erstkontakt: false, fragtEinstellung: true) == [.startwerte])
    }

    /// "Kenne ich schon" fuehrt an Einweisung und Einstellung vorbei zu den
    /// Startwerten -- nie aus dem Drawer heraus, ohne Werte gesehen zu haben.
    @Test func ueberspringenLandetBeiDenStartwerten() {
        let schritte = Uebungsstart.schritte(erstkontakt: true, fragtEinstellung: true)
        #expect(Uebungsstart.positionNachUeberspringen(in: schritte) == 2)
    }

    // MARK: - Countdown (#10)

    /// Fuenf Sekunden zaehlen, dann eine Sekunde "Los!" in der Mitte.
    @Test func derCountdownZaehltVonFuenfUndEndetMitLos() {
        #expect(Startcountdown.anzeige(restsekunden: 6) == "5")
        #expect(Startcountdown.anzeige(restsekunden: 2) == "1")
        #expect(Startcountdown.anzeige(restsekunden: 1) == "Los!")
        #expect(Startcountdown.anzeige(restsekunden: 0) == "Los!")
    }

    @Test func derCountdownDauertFuenfSekundenUndDasLos() {
        #expect(Startcountdown.dauer == 6)
    }
}
