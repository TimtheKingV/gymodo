import Foundation

/// Die Kurse aller Studios eines Mitglieds in einem Plan (Testnotiz 11.10.,
/// #15). Der Server liefert je Studio einen Wochenplan; die App fuehrt sie
/// zusammen, statt einen neuen Endpunkt zu brauchen -- die RLS laesst jedes
/// eigene Studio einzeln ohnehin durch.
enum KursePlan {
    /// Termine nach Beginn sortiert, jeder mit seinem Studio. Zeitzone und
    /// Frist des Ergebnisses sind die des ersten Teils (das aktive Studio
    /// steht vorn) und tragen nur Wochenstreifen und Ladefenster -- fuer
    /// einen einzelnen Termin gilt immer sein eigenes Studio.
    static func zusammenfuehren(_ teile: [(studioId: String, woche: CourseWeek)]) -> CourseWeek? {
        guard let erster = teile.first?.woche else { return nil }
        let termine = teile.flatMap { teil in
            teil.woche.sessions.map { termin in
                var markiert = termin
                markiert.studioId = teil.studioId
                return markiert
            }
        }
        // Gleichzeitige Termine bleiben in der Reihenfolge der Studios,
        // damit die Liste beim Neuladen nicht springt.
        let nummeriert: [(nummer: Int, termin: CourseWeekSession)] = termine.enumerated().map { ($0.offset, $0.element) }
        let sortiert = nummeriert.sorted { links, rechts in
            if links.termin.startsAt != rechts.termin.startsAt {
                return links.termin.startsAt < rechts.termin.startsAt
            }
            return links.nummer < rechts.nummer
        }.map(\.termin)
        return CourseWeek(from: erster.from, to: erster.to, timezone: erster.timezone,
                          cancellationDeadlineHours: erster.cancellationDeadlineHours,
                          sessions: sortiert)
    }
}

/// Welche Studios der Kurse-Tab zeigt (Testnotiz 11.10., #15). Gemerkt
/// werden die AUSGEBLENDETEN: ein neu beigetretenes Studio ist damit von
/// selbst sichtbar.
enum KurseFilter {
    static func sichtbar(_ termine: [CourseWeekSession], ausgeblendet: Set<String>) -> [CourseWeekSession] {
        termine.filter { termin in termin.studioId.map { !ausgeblendet.contains($0) } ?? true }
    }

    static func sichtbar(_ termine: [GespeicherterTermin], ausgeblendet: Set<String>) -> [GespeicherterTermin] {
        termine.filter { termin in termin.studioId.map { !ausgeblendet.contains($0) } ?? true }
    }

    /// Ein Studio plus Freies Training ist EIN Studio -- dann gibt es
    /// nichts zu waehlen.
    static func zeigtAuswahl(studios: Int) -> Bool { studios >= 2 }

    static func sichtbareStudios(alle: [String], ausgeblendet: Set<String>) -> [String] {
        alle.filter { !ausgeblendet.contains($0) }
    }

    /// Das letzte sichtbare Studio bleibt: ein leerer Plan saehe aus wie
    /// "keine Kurse", nicht wie "alles ausgeblendet".
    static func umschalten(_ studio: String, ausgeblendet: Set<String>, alle: [String]) -> Set<String> {
        if ausgeblendet.contains(studio) { return ausgeblendet.subtracting([studio]) }
        guard sichtbareStudios(alle: alle, ausgeblendet: ausgeblendet).count > 1 else { return ausgeblendet }
        return ausgeblendet.union([studio])
    }
}

/// Welche Studios Home und der Kurse-Tab laden. EIN Ort fuer die Regel,
/// damit beide dieselbe Menge anfragen -- sonst beschnitte der eine dem
/// anderen den Cache (KurseStore verwirft bei anderer Menge).
enum KurseStudios {
    /// Das aktive Studio vorn: der zusammengefuehrte Plan nimmt Zeitzone
    /// und Wochenstreifen vom ersten.
    static func reihenfolge(alle: [String], aktiv: String?) -> [String] {
        guard let aktiv, alle.contains(aktiv) else { return alle }
        return [aktiv] + alle.filter { $0 != aktiv }
    }
}
