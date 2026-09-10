import Foundation

/// Der Punkt unter einer Tagesbox im Wochenstreifen.
///
/// Er ist ein Hinweis, keine Aussage -- die Tagesliste bleibt die
/// Wahrheit. Er beantwortet die eine Frage, die man dem Streifen sonst
/// nicht ansieht: an welchen Tagen ueberhaupt etwas laeuft, und an
/// welchen davon man selbst einen Platz hat.
///
/// Der Akzent ist dabei eng gefasst. `angemeldet` heisst ausschliesslich
/// "dein Platz steht" -- eine Warteliste faerbt nichts, weil die Karte
/// darueber ausdruecklich sagt, dass bis zum Nachruecken nichts
/// reserviert ist. Ein gruener Punkt fuer eine Warteliste waere ein
/// Versprechen, das die App an anderer Stelle zuruecknimmt.
enum KurseTagesindikator: Equatable {
    /// Kein Termin an diesem Tag -- kein Punkt. Der Platz darunter bleibt
    /// trotzdem stehen, sonst wackelten die Tagesboxen in der Hoehe.
    case keiner
    /// Termine, aber kein eigener bestaetigter Platz.
    case kurse
    /// Mindestens ein bestaetigter, noch bevorstehender eigener Platz.
    case angemeldet

    /// `termine` ist die ungefilterte Liste des ganzen Wochenplans; der
    /// Abgleich laeuft ueber `localDay`, das der Server bereits in der
    /// Studio-Zeitzone berechnet hat (siehe `KurseWochentag.id`, das
    /// bewusst im selben Format steht). Ein zweiter, eigener
    /// Zeitzonen-Abgleich waere doppelte und angreifbare Arbeit.
    static func fuer(tagId: String, termine: [CourseWeekSession], jetzt: Date) -> KurseTagesindikator {
        let desTages = termine.filter { $0.localDay == tagId }
        guard !desTages.isEmpty else { return .keiner }

        // Ueber KursZustandRechner, nicht ueber ownStatus: dort ist schon
        // entschieden, dass `abgesagt` und `vorbei` jeden eigenen Status
        // schlagen. Ein Kurs von heute Morgen ist kein Platz mehr, und ein
        // abgesagter erst recht nicht.
        let habeIchEinenPlatz = desTages.contains {
            KursZustandRechner.zustand(fuer: $0, jetzt: jetzt) == .angemeldet
        }
        return habeIchEinenPlatz ? .angemeldet : .kurse
    }
}
