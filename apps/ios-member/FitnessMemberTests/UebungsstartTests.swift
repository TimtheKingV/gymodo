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

    // MARK: - Cardio (Testnotiz 14.10., 18:45 #6)

    /// Bei Zeit oder Metern fragt der Drawer keine Startwerte -- da startet
    /// man einfach. Eine bekannte Cardio-Uebung braucht ihn gar nicht.
    @Test func eineBekannteCardioUebungStartetOhneDrawer() {
        #expect(Uebungsstart.schritte(erstkontakt: false, fragtEinstellung: false, volumeKind: .seconds) == [])
        #expect(Uebungsstart.schritte(erstkontakt: false, fragtEinstellung: true, volumeKind: .meters) == [])
    }

    @Test func beimErstkontaktBleibenEinweisungUndEinstellung() {
        #expect(Uebungsstart.schritte(erstkontakt: true, fragtEinstellung: true, volumeKind: .seconds)
                == [.einweisung, .einstellung])
        #expect(Uebungsstart.schritte(erstkontakt: true, fragtEinstellung: false, volumeKind: .seconds)
                == [.einweisung])
    }

    @Test func wiederholungenFragenWeiterNachStartwerten() {
        #expect(Uebungsstart.schritte(erstkontakt: false, fragtEinstellung: false, volumeKind: .reps) == [.startwerte])
    }

    /// Ohne Startwerte heisst "Kenne ich schon": gleich los.
    @Test func ueberspringenOhneStartwerteStartetSofort() {
        let schritte = Uebungsstart.schritte(erstkontakt: true, fragtEinstellung: true, volumeKind: .seconds)
        #expect(Uebungsstart.positionNachUeberspringen(in: schritte) == nil)
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

    // MARK: - Ring voll bei "Los!" (Testnotiz 12.10. abends, #2)

    /// Der Ring fuellt sich ueber die fuenf Zaehlsekunden, nicht ueber die
    /// ganze Dauer samt "Los!" -- sonst ist er beim Wechsel zu den Raedern
    /// nie voll.
    @Test func derRingIstBeiLosVoll() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(Startcountdown.zaehldauer == 5)
        #expect(Startcountdown.fortschritt(start: start, jetzt: start) == 0)
        #expect(Startcountdown.fortschritt(start: start, jetzt: start.addingTimeInterval(2.5)) == 0.5)
        #expect(Startcountdown.fortschritt(start: start, jetzt: start.addingTimeInterval(5)) == 1)
        #expect(Startcountdown.fortschritt(start: start, jetzt: start.addingTimeInterval(6)) == 1)
        #expect(Startcountdown.fortschritt(start: start, jetzt: start.addingTimeInterval(-1)) == 0)
    }

    // MARK: - Pause (Testnotiz 12.10. abends, #4)

    /// "± kg" statt "Gewicht" -- die Einheit kommt vom Geraet.
    @Test func derGewichtsknopfDerPauseTraegtDieEinheit() {
        #expect(PausenRad.gewichtTitel(.kg) == "± kg")
        #expect(PausenRad.gewichtTitel(.kmh) == "± km/h")
    }
}
