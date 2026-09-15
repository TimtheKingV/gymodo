import Foundation
import Testing
@testable import FitnessMember

struct GewichtsverlaufHilfenTests {
    // MARK: - kopfZielText

    /// Wortwoertlich aus Gewichtsverlauf.dc.html: die zweite Zahl traegt
    /// KEIN "kg" -- die Einheit steht schon bei der ersten.
    @Test func kopfZielTextTrenntZielUndAbstand() {
        #expect(GewichtsverlaufHilfen.kopfZielText(zielwert: 78, aktuell: 82.5) == "Ziel 78,0 kg · noch 4,5")
    }

    @Test func kopfZielTextIstNilOhneZiel() {
        #expect(GewichtsverlaufHilfen.kopfZielText(zielwert: nil, aktuell: 82.5) == nil)
    }

    /// Der Abstand ist ein Betrag -- ob das Mitglied ueber oder unter dem
    /// Ziel liegt, sagt diese Zahl nicht (Spec Abschnitt 6, wie
    /// HomeZiele.abstandText).
    @Test func kopfZielTextZeigtDenAbstandAlsBetrag() {
        #expect(GewichtsverlaufHilfen.kopfZielText(zielwert: 78, aktuell: 74.5) == "Ziel 78,0 kg · noch 3,5")
    }

    // MARK: - seitText

    @Test func seitTextNenntDenErstenMesswert() {
        #expect(GewichtsverlaufHilfen.seitText("2026-08-01") == "seit 1. August")
    }

    @Test func seitTextIstNilBeiEinemUnlesbarenDatum() {
        #expect(GewichtsverlaufHilfen.seitText("keine-angabe") == nil)
    }

    // MARK: - vorheriger

    private var verlauf: [Messwert] {
        [
            Messwert(measuredOn: "2026-08-01", weightKg: 84.5),
            Messwert(measuredOn: "2026-09-06", weightKg: 83.5),
            Messwert(measuredOn: "2026-09-10", weightKg: 83.0),
            Messwert(measuredOn: "2026-09-13", weightKg: 82.5),
        ]
    }

    @Test func vorherigerFindetDenUnmittelbarenVorgaenger() {
        let vorheriger = GewichtsverlaufHilfen.vorheriger(verlauf, vor: verlauf[2])

        #expect(vorheriger == verlauf[1])
    }

    /// Der erste je eingetragene Messwert hat keinen Vorgaenger -- keine
    /// erfundene Differenz zu einem Tag, den es nicht gibt.
    @Test func derErsteMesswertHatKeinenVorgaenger() {
        #expect(GewichtsverlaufHilfen.vorheriger(verlauf, vor: verlauf[0]) == nil)
    }

    /// Der Vorgaenger kommt aus der VOLLSTAENDIGEN Liste -- unabhaengig
    /// davon, ob ein Fenster (3/6 Monate) den Vorgaenger selbst schon
    /// abgeschnitten haette. Ein auf zwei Punkte gekuerztes "Fenster" darf
    /// die Differenz trotzdem gegen den echten Vortag rechnen.
    @Test func derVorgaengerGiltAuchAusserhalbEinesGekuerztenFensters() {
        let gekuerzt = Array(verlauf.suffix(1))

        let vorheriger = GewichtsverlaufHilfen.vorheriger(verlauf, vor: gekuerzt[0])

        #expect(vorheriger == verlauf[2])
    }
}
