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
        /// true fuer Eintraege aus data/koerperbild/flow-zuordnung.json.
        let flow: Bool?

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
    static let eintraege: [String: Eintrag] =
        Dictionary(alle.map { ($0.name, $0) }, uniquingKeysWith: { erster, _ in erster })

    /// Nur die Eintraege der Flow-Zuordnung, je Name. Im Flow gewinnen sie: ein Name
    /// kann im Katalog mehrfach vorkommen („Ausfallschritt – rückwärts“ viermal), der
    /// Flow meint aber genau die Uebung, die gegen ihr Video geprueft wurde.
    static let flowEintraege: [String: Eintrag] =
        Dictionary(alle.filter { $0.flow == true }.map { ($0.name, $0) }, uniquingKeysWith: { erster, _ in erster })

    /// Alle Eintraege der Datei in ihrer Reihenfolge.
    static let alle: [Eintrag] = {
        guard let url = Bundle.main.url(forResource: "KameraTestprofile", withExtension: "json"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Eintrag].self, from: daten) else { return [] }
        return liste
    }()

    /// Nur wenn `aktiv` und die Uebung kein Serverprofil hat; studioeigene
    /// Uebungen (unbekannter Name) bleiben ohne.
    /// `eingeschaltet` laesst Tests den Schalter vorgeben, ohne UserDefaults anzufassen.
    /// `imFlow`: nur die Eintraege der Flow-Zuordnung (am Video geprueft), kein Rueckfall
    /// auf die Vorschlagsprofile des normalen Trainings.
    static func ergaenzt(_ uebung: BootstrapResponse.Exercise,
                         eingeschaltet: Bool = KameraTestprofile.aktiv,
                         imFlow: Bool = false) -> BootstrapResponse.Exercise {
        guard eingeschaltet, uebung.kamera == nil,
              let eintrag = imFlow ? flowEintraege[uebung.name] : eintraege[uebung.name] else { return uebung }
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

    /// Katalogschluessel im Flow: nur aus der Flow-Zuordnung.
    static func flowKatalogKey(name: String) -> String? {
        flowEintraege[name]?.key
    }
}
#endif
