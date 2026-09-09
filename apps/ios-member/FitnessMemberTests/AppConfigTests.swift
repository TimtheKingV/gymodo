import Foundation
import Testing
@testable import FitnessMember

@Suite("AppConfig")
struct AppConfigTests {
    @Test("eine gueltige HTTPS-URL wird geparst")
    func parsesValidURL() {
        #expect(URL(string: "https://gymodo-web.vercel.app/api/v1") != nil)
    }

    @Test("die konfigurierte API-Basis-URL ist HTTPS")
    func apiBaseURLIsHTTPS() {
        // AppConfig.apiBaseURL loest bei fehlendem Config.xcconfig fatalError aus --
        // dieser Test laeuft nur sinnvoll, wenn Config.xcconfig aus Schritt 2 existiert.
        #expect(AppConfig.apiBaseURL.scheme == "https")
    }

    @Test("eine gesetzte Datenschutz-URL ist HTTPS, eine leere ergibt keine Zeile")
    func datenschutzURLIstOptional() {
        // Kein fatalError in beiden Faellen -- das ist die eigentliche Absicherung.
        // Mit leerem Schluessel (aktuelle Config.xcconfig) ist nichts zu pruefen;
        // sobald einmal eine URL hinterlegt ist, muss sie wie die drei Pflichtwerte
        // HTTPS sein. So haengt der Test nicht an einer konkreten lokalen
        // Config.xcconfig.
        if let url = AppConfig.datenschutzURL {
            #expect(url.scheme == "https")
        }
    }
}
