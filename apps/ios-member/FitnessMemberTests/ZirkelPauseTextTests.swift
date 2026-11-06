import Foundation
import Testing
@testable import FitnessMember

/// Was der Pausenscreen im Zirkel in Worten sagt (Spec Mini-Zirkel 21.10.,
/// Entscheidung 5). Kopf, Stand und Rundenzusammenfassung sind mit dem
/// einen Pausen-Screen entfallen (UX-Paket 2, 2.1).
struct ZirkelPauseTextTests {

    @Test func startTitelNenntDieUebung() {
        #expect(ZirkelPauseText.startTitel(uebungsname: "Seitheben") == "Seitheben starten")
    }
}
