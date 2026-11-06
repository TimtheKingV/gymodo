import Foundation
import Testing
@testable import FitnessMember

/// Was der Pausenscreen im Zirkel in Worten sagt (Spec Mini-Zirkel 21.10.,
/// Entscheidung 5). Wo man steht, sagen seit dem einen Pausen-Screen
/// (UX-Paket 2, 2.1) Ablaufzeile und Ablauf-Liste; hier bleibt der Text
/// des Hauptknopfs.
struct ZirkelPauseTextTests {

    @Test func startTitelNenntDieUebung() {
        #expect(ZirkelPauseText.startTitel(uebungsname: "Seitheben") == "Seitheben starten")
    }
}
