import Foundation
import Testing
@testable import FitnessMember

/// „Erkannt" oder „Ausgewaehlt" -- der Unterschied ist keine Kosmetik.
///
/// Nach einem Scan war das Telefon nachweislich am Geraet. Nach einer
/// Auswahl hat jemand etwas angetippt. Ein Wort, das eine Messung
/// behauptet, wo keine stattfand, verstoesst gegen die Produktgrenze
/// (designsystem.md SS10).
struct GeraetEinstiegsartTests {

    @Test func mitTokenHeisstEsErkannt() {
        #expect(GeraetModel.Einstiegsart(token: "abc123") == .erkannt)
    }

    @Test func ohneTokenHeisstEsAusgewaehlt() {
        #expect(GeraetModel.Einstiegsart(token: nil) == .ausgewaehlt)
    }

    @Test func dieBeschriftungBehauptetKeineMessung() {
        #expect(GeraetModel.Einstiegsart.erkannt.beschriftung == "ERKANNT")
        #expect(GeraetModel.Einstiegsart.ausgewaehlt.beschriftung == "AUSGEWÄHLT")
    }

    /// Listensymbol statt NFC-Wellen: das Zeichen muss denselben
    /// Unterschied tragen wie das Wort.
    @Test func dasSymbolPasstZumWeg() {
        #expect(GeraetModel.Einstiegsart.erkannt.symbol == "wave.3.right")
        #expect(GeraetModel.Einstiegsart.ausgewaehlt.symbol == "list.bullet")
    }
}
