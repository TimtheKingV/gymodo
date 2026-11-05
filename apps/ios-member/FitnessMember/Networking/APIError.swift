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
    /// 422: fuer den Plan fehlen Angaben im Trainingsprofil (`fehlt` nennt sie).
    case profilUnvollstaendig(message: String, fehlt: [String])
    /// 422: fuer einen Baustein gibt es keine passende Uebung; `grund` ist der
    /// feste Servercode, nicht zur Anzeige.
    case planNichtMoeglich(message: String, baustein: String, grund: String)
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
        // Dieselbe Anfrage ergibt dasselbe Profil und denselben Katalog -- ein
        // Wiederholen aendert nichts, erst eine Eingabe des Mitglieds.
        case .unauthorized, .validation, .notFound, .conflict, .encodingFailed,
             .profilUnvollstaendig, .planNichtMoeglich: true
        }
    }

    /// 401 -- in der Warteschlange voruebergehend: offline gibt es keinen
    /// gueltigen Token, und der Satz darf deshalb nicht verloren gehen
    /// (Offline-Spec 4c). `istDauerhaft` bleibt fuer andere Aufrufer gleich.
    var istAnmeldefehler: Bool {
        if case .unauthorized = self { true } else { false }
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
             .notFound(let message), .conflict(let message), .server(let message),
             .profilUnvollstaendig(let message, _), .planNichtMoeglich(let message, _, _):
            message
        case .encodingFailed:
            "Die Anfrage konnte nicht gesendet werden."
        case .decodingFailed:
            "Die Antwort deines Studios ließ sich nicht lesen."
        }
    }

    static func map(code: String, message: String, detail: JSONValue? = nil) -> APIError {
        switch code {
        case "unauthorized": .unauthorized(message: message)
        case "validation_failed": .validation(message: message)
        case "not_found": .notFound(message: message)
        case "conflict": .conflict(message: message)
        case "profil_unvollstaendig": .profilUnvollstaendig(message: message, fehlt: detail?.textliste("fehlt") ?? [])
        case "plan_nicht_moeglich":
            .planNichtMoeglich(message: message, baustein: detail?.text("baustein") ?? "", grund: detail?.text("grund") ?? "")
        default: .server(message: message)
        }
    }
}

private extension JSONValue {
    func text(_ schluessel: String) -> String? {
        if case .object(let o) = self, case .string(let t)? = o[schluessel] { t } else { nil }
    }

    func textliste(_ schluessel: String) -> [String]? {
        guard case .object(let o) = self, case .array(let a)? = o[schluessel] else { return nil }
        return a.compactMap { if case .string(let t) = $0 { t } else { nil } }
    }
}
