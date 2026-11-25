#if DEBUG
import Foundation

/// Kameraprofile aus dem Zuordnungsvorschlag, nur im Debug-Build: damit der
/// Kamera-Ablauf gebaut und probiert werden kann, ohne Katalog, Freischalt-
/// Liste oder Datenbank anzufassen (Prod kennt 0077 noch nicht, die API
/// liefert kein `kamera`). Die Datei `KameraTestprofile.json` erzeugt
/// `tools/kamera-zuordnung/testprofile.py`.
enum KameraTestprofile {
    static let schluessel = "kamera.testprofile"

    /// Schalter im Profil ("Kamera-Testprofile"), Standard aus.
    static var aktiv: Bool {
        get { UserDefaults.standard.bool(forKey: schluessel) }
        set { UserDefaults.standard.set(newValue, forKey: schluessel) }
    }

    struct Eintrag: Decodable {
        let name: String
        let key: String
        let kamera: Kamera
        let tempo: Tempo

        struct Kamera: Decodable {
            let profil: String
            let signal: String?
            let seite: String?
            let beginntMit: String
            enum CodingKeys: String, CodingKey {
                case profil, signal, seite
                case beginntMit = "beginnt_mit"
            }
        }

        struct Tempo: Decodable {
            let senkenS: Double
            let haltenS: Double
            let hebenS: Double
            enum CodingKeys: String, CodingKey {
                case senkenS = "senken_s", haltenS = "halten_s", hebenS = "heben_s"
            }
        }
    }

    /// Je Name der erste Eintrag nach Schluessel (die Datei ist danach sortiert):
    /// mehrere Katalogschluessel teilen sich einen Namen, die Profile sind dort
    /// gleich oder nahezu gleich.
    static let eintraege: [String: Eintrag] = {
        guard let url = Bundle.main.url(forResource: "KameraTestprofile", withExtension: "json"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Eintrag].self, from: daten) else { return [:] }
        return Dictionary(liste.map { ($0.name, $0) }, uniquingKeysWith: { erster, _ in erster })
    }()

    /// Nur wenn `aktiv` und die Uebung kein Serverprofil hat; studioeigene
    /// Uebungen (unbekannter Name) bleiben ohne.
    static func ergaenzt(_ uebung: BootstrapResponse.Exercise) -> BootstrapResponse.Exercise {
        guard aktiv, uebung.kamera == nil, let eintrag = eintraege[uebung.name] else { return uebung }
        var ergebnis = uebung
        ergebnis.kamera = KameraDTO(profil: eintrag.kamera.profil, signal: eintrag.kamera.signal,
                                    seite: eintrag.kamera.seite, beginntMit: eintrag.kamera.beginntMit)
        ergebnis.tempo = TempoDTO(senkenS: eintrag.tempo.senkenS, haltenS: eintrag.tempo.haltenS,
                                  hebenS: eintrag.tempo.hebenS)
        return ergebnis
    }

    /// Katalogschluessel zu einem Uebungsnamen (fuer die Abspielquelle).
    static func katalogKey(name: String) -> String? {
        eintraege[name]?.key
    }
}
#endif
