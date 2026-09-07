import Foundation

/// Liest die drei Laufzeit-Werte aus Info.plist, die project.yml aus
/// Config.xcconfig einsetzt (Aufgabe 1). Fehlt einer, ist das ein
/// Entwicklungsfehler (Config.xcconfig nicht angelegt) -- deshalb fatalError
/// statt eines stillen Fallbacks.
enum AppConfig {
    static let apiBaseURL = url(for: "API_BASE_URL")
    static let supabaseURL = url(for: "SUPABASE_URL")
    static let supabaseAnonKey = string(for: "SUPABASE_ANON_KEY")

    static func string(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            fatalError("Info.plist-Schluessel \(key) fehlt -- Config.xcconfig pruefen (siehe Config.xcconfig.example).")
        }
        return value
    }

    private static func url(for key: String) -> URL {
        guard let url = URL(string: string(for: key)) else {
            fatalError("Info.plist-Schluessel \(key) ist keine gueltige URL.")
        }
        return url
    }
}
