#if DEBUG
import Foundation
import Sensorik
import Testing
@testable import FitnessMember

@MainActor
struct BefestigungsspeicherTests {
    static func kontext(_ station: Station = Station(maschine: GeraetTestdaten.maschine),
                        uebung: String = "e1") -> SatzZaehlerKontext {
        SatzZaehlerKontext(station: station, exerciseId: uebung, volumeKind: .reps)
    }

    @Test func ohneWahlKommtDerVorschlag() {
        let sut = Befestigungsspeicher(einstellungen: UserDefaults(suiteName: UUID().uuidString)!)
        // GeraetTestdaten.maschine ist eine Beinpresse (kraft).
        #expect(sut.wahl(fuer: Self.kontext()) == BefestigungsWahl(art: .stapel, quelle: .vorschlag))
    }

    @Test func eineWahlGiltJeStationUndUebung() {
        let einstellungen = UserDefaults(suiteName: UUID().uuidString)!
        let sut = Befestigungsspeicher(einstellungen: einstellungen)
        sut.merken(.hebelarm, fuer: Self.kontext())
        #expect(sut.wahl(fuer: Self.kontext()) == BefestigungsWahl(art: .hebelarm, quelle: .gewaehlt))
        // Andere Uebung an derselben Station: wieder der Vorschlag.
        #expect(sut.wahl(fuer: Self.kontext(uebung: "e2"))?.quelle == .vorschlag)
        // Ein neuer Speicher auf denselben Einstellungen kennt die Wahl.
        #expect(Befestigungsspeicher(einstellungen: einstellungen).wahl(fuer: Self.kontext())?.art == .hebelarm)
    }

    @Test func cardioOhneVorschlag() {
        let sut = Befestigungsspeicher(einstellungen: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(sut.wahl(fuer: Self.kontext(GeraetTestdaten.cardioTyp)) == nil)
    }
}
#endif
