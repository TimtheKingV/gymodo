import Foundation

/// Bildet apps/web/lib/api/respond.ts 1:1 ab: fuenf Codes, feste
/// Status-Zuordnung. .offline ist ein rein clientseitiger Fall (kein
/// HTTP-Response ueberhaupt) und hat kein Server-Gegenstueck.
enum APIError: Error, Equatable {
    case offline
    case unauthorized(message: String)
    case validation(message: String)
    case notFound(message: String)
    case conflict(message: String)
    case server(message: String)
    /// Die Anfrage konnte gar nicht erst codiert werden -- der Schreibvorgang
    /// hat das Geraet nie verlassen. Getrennt von .decodingFailed, weil die
    /// beiden Faelle das Gegenteil bedeuten (siehe istDauerhaft).
    case encodingFailed
    /// Die Antwort kam mit 2xx zurueck, liess sich aber nicht parsen -- der
    /// Schreibvorgang ist auf dem Server angekommen. Getrennt von
    /// .encodingFailed, weil die beiden Faelle das Gegenteil bedeuten (siehe
    /// istDauerhaft).
    case decodingFailed

    /// Ob ein Wiederholen aussichtslos ist.
    ///
    /// Die Schreib-Warteschlange behielt bisher bei jedem Fehler. Ein
    /// stillgelegtes Geraet oder eine entfernte Uebung kommt nie zurueck --
    /// der Eintrag wuerde sonst bei jedem Netzwechsel neu versucht, fuer
    /// immer.
    ///
    /// .encodingFailed und .decodingFailed sehen aehnlich aus, sind aber
    /// Gegenteile: .encodingFailed scheitert vor dem Request -- der
    /// Schreibvorgang hat das Geraet nie verlassen, und ein erneuter Versuch
    /// wuerde denselben, unveraenderten Body wieder nicht codieren koennen,
    /// also dauerhaft. .decodingFailed scheitert dagegen erst beim Parsen
    /// einer 2xx-Antwort -- der Server hat den Schreibvorgang bereits
    /// angenommen. putSet ist ein PUT und damit idempotent: ein Wiederholen
    /// ist sicher und liefert entweder eine lesbare Antwort oder den echten
    /// Fehler, also transient. Waere .decodingFailed dauerhaft, wuerde ein
    /// erfolgreich gespeicherter Satz als "nicht gespeichert" gemeldet --
    /// das Gegenteil dessen, was SS5 verlangt.
    var istDauerhaft: Bool {
        switch self {
        case .offline, .server, .decodingFailed: false
        case .unauthorized, .validation, .notFound, .conflict, .encodingFailed: true
        }
    }

    /// Der Satz, den ein Screen zeigt -- der Servertext WOERTLICH, wo es
    /// einen gibt.
    ///
    /// Eine Stelle statt vier: `KurseWochenView`, `KursDetailView`,
    /// `KurseMeineView` und `TrainingAbschlussView` hatten dieselbe
    /// Verzweigung je einmal kopiert. Vier Kopien heisst frueher oder
    /// spaeter vier Formulierungen fuer denselben Fall -- genau der
    /// Befund, der in dieser Welle dreimal aufgeschlagen ist.
    ///
    /// `.offline` gehoert hier NICHT her und muss von jedem Aufrufer
    /// vorher abgefangen werden: ohne Empfang gibt es keinen Servertext,
    /// und der ehrliche Satz haengt daran, was der Screen gerade tut
    /// ("gespeichert, wird gesendet" beim Schreiben, "Stand: ..." beim
    /// Lesen, "wir wissen nicht, ob es ankam" beim Buchen). Der Zweig
    /// unten existiert nur, weil `switch` vollstaendig sein muss -- er
    /// ist absichtlich der karge Notnagel, nicht die Antwort. Wer ihn zu
    /// sehen bekommt, hat eine Fallunterscheidung vergessen.
    /// `.encodingFailed`/`.decodingFailed` sind rein clientseitige Faelle
    /// ohne Servertext; hier ein knapper, ehrlicher Ersatz statt eines
    /// erfundenen Server-Zitats.
    var servertext: String {
        switch self {
        case .offline:
            "Keine Verbindung."
        case .unauthorized(let message), .validation(let message),
             .notFound(let message), .conflict(let message), .server(let message):
            message
        case .encodingFailed:
            "Die Anfrage konnte nicht gesendet werden."
        case .decodingFailed:
            "Die Antwort deines Studios ließ sich nicht lesen."
        }
    }

    static func map(code: String, message: String) -> APIError {
        switch code {
        case "unauthorized": .unauthorized(message: message)
        case "validation_failed": .validation(message: message)
        case "not_found": .notFound(message: message)
        case "conflict": .conflict(message: message)
        default: .server(message: message)
        }
    }
}
