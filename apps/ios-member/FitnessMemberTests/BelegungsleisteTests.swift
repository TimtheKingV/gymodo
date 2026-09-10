import Foundation
import Testing
@testable import FitnessMember

/// Die Leiste ersetzt die Zahl nicht, sie stellt sie daneben -- und sie
/// hoert auf, wo ein Segment schmaler waere als der Spalt daneben.
struct BelegungsleisteTests {

    // MARK: - Ab wann die Leiste nichts mehr hergibt

    @Test func kleineUndMittlereKurseBekommenEineLeiste() {
        #expect(Belegungsleiste.zeigtLeiste(kapazitaet: 1))
        #expect(Belegungsleiste.zeigtLeiste(kapazitaet: 16))
        #expect(Belegungsleiste.zeigtLeiste(kapazitaet: 40))
    }

    @Test func jenseitsVonVierzigPlaetzenBleibtNurDieZahl() {
        #expect(!Belegungsleiste.zeigtLeiste(kapazitaet: 41))
        #expect(!Belegungsleiste.zeigtLeiste(kapazitaet: 120))
    }

    /// Ein Kurs ohne Plaetze ist ein Datenfehler, keine leere Leiste:
    /// 0 Segmente waeren ein durchgehender Strich in Linienfarbe, den
    /// niemand als "keine Plaetze" liest.
    @Test func ohneKapazitaetGibtEsKeineLeiste() {
        #expect(!Belegungsleiste.zeigtLeiste(kapazitaet: 0))
        #expect(!Belegungsleiste.zeigtLeiste(kapazitaet: -3))
    }

    // MARK: - Abstand

    @Test func bisVierundzwanzigPlaetzenZweiPunktAbstand() {
        #expect(Belegungsleiste.segmentAbstand(kapazitaet: 8) == 2)
        #expect(Belegungsleiste.segmentAbstand(kapazitaet: 24) == 2)
    }

    @Test func abFuenfundzwanzigPlaetzenEinPunktAbstand() {
        #expect(Belegungsleiste.segmentAbstand(kapazitaet: 25) == 1)
        #expect(Belegungsleiste.segmentAbstand(kapazitaet: 40) == 1)
    }

    // MARK: - Wie viele Segmente belegt sind

    @Test func belegteSegmenteEntsprechenDerBelegung() {
        #expect(Belegungsleiste.belegteSegmente(belegt: 12, kapazitaet: 16) == 12)
        #expect(Belegungsleiste.belegteSegmente(belegt: 0, kapazitaet: 16) == 0)
        #expect(Belegungsleiste.belegteSegmente(belegt: 16, kapazitaet: 16) == 16)
    }

    /// Der Server zaehlt `bookedCount` und `capacity` unabhaengig
    /// voneinander; eine ueberbuchte Zeile (Nachruecken waehrend einer
    /// Kapazitaetsaenderung) darf nicht mehr Segmente faerben, als es
    /// ueberhaupt gibt.
    @Test func mehrBuchungenAlsPlaetzeFaerbenHoechstensAlleSegmente() {
        #expect(Belegungsleiste.belegteSegmente(belegt: 19, kapazitaet: 16) == 16)
    }

    @Test func negativeBelegungFaerbtNichts() {
        #expect(Belegungsleiste.belegteSegmente(belegt: -2, kapazitaet: 16) == 0)
    }
}
