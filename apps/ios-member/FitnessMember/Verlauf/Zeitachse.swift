import Foundation

/// Die x-Achse der beiden Verlaufsdiagramme (Gewichtsverlauf,
/// Uebungsfortschritt) -- eine Regel fuer beide, wie
/// `Fortschrittsfenster.achsenbereich` fuer die y-Achse.
enum Zeitachse {
    /// Unter zwei Tagen Spanne waere ein einzelner Eintrag ein Strich ohne
    /// Achse, und zwei Eintraege von gestern und heute klebten an den
    /// Raendern.
    static let mindestspanne: TimeInterval = 2 * 24 * 60 * 60

    /// Der juengste Eintrag steht auf zwei Dritteln der Achse, nicht am
    /// rechten Rand (Testnotiz 05.10., #3). Rechts bleibt Platz fuer den
    /// naechsten Eintrag, und der letzte Punkt samt Beschriftung klebt
    /// nicht mehr an der Kante. Links ein Zwanzigstel Luft, damit der
    /// erste Punkt nicht halb auf der y-Achse sitzt.
    static func bereich(_ daten: [Date]) -> ClosedRange<Date>? {
        guard let erster = daten.min(), let letzter = daten.max() else { return nil }
        let spanne = max(letzter.timeIntervalSince(erster), mindestspanne)
        let unten = letzter.addingTimeInterval(-spanne * 1.05)
        let oben = letzter.addingTimeInterval(letzter.timeIntervalSince(unten) / 2)
        return unten ... oben
    }

    /// Fuer ein Fenster ohne Eintrag ("3 Monate", aber der letzte ist
    /// aelter): irgendein gueltiger Bereich, das Diagramm bleibt leer.
    static var leererBereich: ClosedRange<Date> {
        let jetzt = Date()
        return jetzt.addingTimeInterval(-mindestspanne) ... jetzt
    }

    /// Ab drei Punkten schwingt die Linie, zwei verbindet eine Gerade
    /// (Testnotiz 05.10., #6). Die Diagramme nehmen dafuer `.monotone`:
    /// die Kurve laeuft durch jeden Messpunkt und schiesst zwischen zwei
    /// Punkten nie ueber sie hinaus -- sie zeigt also weiterhin nur, was
    /// eingetragen ist, keinen erfundenen Tiefst- oder Hoechstwert.
    static func geschwungen(anzahl: Int) -> Bool { anzahl >= 3 }
}
