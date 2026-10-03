import Testing
import UIKit

// Fehlt der Katalog in der Resources-Phase, zeigt SwiftUI an der Stelle
// still nichts. Der Test haengt am App-Bundle (TEST_HOST), damit genau
// das auffaellt.
struct MarkenAssetTests {
    @Test func wortmarkeLiegtImAppBundle() {
        #expect(UIImage(named: "GymtavoWordmark", in: .main, with: nil) != nil)
    }
}
