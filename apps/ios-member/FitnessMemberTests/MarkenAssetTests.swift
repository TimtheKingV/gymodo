import Testing
import UIKit

// Fehlt der Katalog in der Resources-Phase, zeigt SwiftUI an der Stelle
// still nichts. Der Test haengt am App-Bundle (TEST_HOST), damit genau
// das auffaellt.
struct MarkenAssetTests {
    @Test func wortmarkeLiegtImAppBundle() {
        #expect(UIImage(named: "GymtavoWordmark", in: .main, with: nil) != nil)
    }

    // Ohne AppIcon zeigt der Home-Bildschirm das leere Standardsymbol, und
    // App Store Connect lehnt den Upload ab.
    @Test func appIconIstEingetragen() {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primaer = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        #expect(primaer?["CFBundleIconName"] as? String == "AppIcon")
    }

    // Unter dem Icon stand "FitnessMember" (PRODUCT_NAME), weil kein
    // Anzeigename gesetzt war.
    @Test func anzeigenameIstGymtavo() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Gymtavo")
    }

    // Die Systemdialoge fuer Kamera und NFC nennen den Produktnamen;
    // sie liegen in project.yml, nicht im Swift-Code, und fallen beim
    // Textabgleich sonst durch.
    @Test(arguments: ["NSCameraUsageDescription", "NFCReaderUsageDescription"])
    func berechtigungstexteNennenGymtavo(schluessel: String) {
        let text = Bundle.main.object(forInfoDictionaryKey: schluessel) as? String ?? ""
        #expect(text.hasPrefix("Gymtavo "))
    }
}
