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
}
