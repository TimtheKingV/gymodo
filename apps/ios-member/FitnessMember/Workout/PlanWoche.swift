import Foundation

/// Die Art eines Wochenrasterplatzes (`wochenraster[].art` im Plan).
enum Wochenart: String, Decodable, Sendable {
    case kraft, kurs, cardio
}

/// Ein Platz im Wochenraster des Plans: `tag` ist der ISO-Wochentag
/// (1 = Montag ... 7 = Sonntag), `einheitKey` nennt bei Krafttagen die Einheit.
/// Die Wochentage sind nur eine Erinnerung -- der Plan folgt der Reihenfolge der
/// Einheiten, nicht dem Kalender.
struct Rasterplatz: Decodable, Equatable, Sendable {
    let tag: Int
    let art: Wochenart
    let einheitKey: String?
}

/// Ein Eintrag der Wochenansicht.
enum PlanTermin: Equatable {
    case einheit(key: String, erledigt: Bool)
    case kurs(titel: String, beginn: Date, angemeldet: Bool)
    case cardio(arten: [String], erledigt: Bool)
}

enum PlanFilter: CaseIterable {
    case alle, einheiten, kurse, cardio

    var titel: String {
        switch self {
        case .alle: "Alle"
        case .einheiten: "Einheiten"
        case .kurse: "Kurse"
        case .cardio: "Cardio"
        }
    }
}

/// Reine Darstellungslogik des Plan-Tabs: ordnet Raster, Kurse und Erledigtes den
/// Tagen einer Woche zu. Rechnet am Plan nichts um.
enum PlanWoche {
    /// Schluessel ist `startOfDay` des Tages. Tage ohne Termin fehlen. Die Zuordnung
    /// ISO-Wochentag -> Datum geht ueber den Wochentag des Datums selbst und ist
    /// damit von `Calendar.firstWeekday` unabhaengig.
    ///
    /// `cardioErledigt` enthaelt Tage als "YYYY-MM-DD", `einheitenErledigt` Einheit-Keys.
    /// Die Cardio-Arten stehen im Profil, nicht im Raster; hier bleibt `arten` leer
    /// und der Aufrufer reicht sie bei der Anzeige nach.
    static func termine(
        tage: [Date], kalender: Calendar, raster: [Rasterplatz], kurse: [CourseWeekSession],
        cardioErledigt: Set<String>, einheitenErledigt: Set<String>, filter: PlanFilter
    ) -> [Date: [PlanTermin]] {
        var ergebnis: [Date: [PlanTermin]] = [:]
        for tag in tage {
            let start = kalender.startOfDay(for: tag)
            let schluessel = tagesSchluessel(start, kalender)
            let iso = isoWochentag(start, kalender)
            var liste: [PlanTermin] = []

            let kursTermine: [PlanTermin] = kurse
                .filter { $0.localDay == schluessel && $0.status != "cancelled" }
                .sorted { $0.startsAt < $1.startsAt }
                .map { .kurs(titel: $0.name, beginn: Zeitpunkt.parse($0.startsAt) ?? start,
                             angemeldet: $0.ownStatus == "booked") }

            if filter == .kurse {
                liste = kursTermine
            } else {
                for platz in raster where platz.tag == iso {
                    switch platz.art {
                    case .kraft:
                        guard filter == .alle || filter == .einheiten, let key = platz.einheitKey else { continue }
                        liste.append(.einheit(key: key, erledigt: einheitenErledigt.contains(key)))
                    case .kurs:
                        continue // gebuchte Kurse kommen unten, unabhaengig vom Raster
                    case .cardio:
                        guard filter == .alle || filter == .cardio else { continue }
                        liste.append(.cardio(arten: [], erledigt: cardioErledigt.contains(schluessel)))
                    }
                }
                if filter == .alle {
                    liste += kursTermine.filter { if case .kurs(_, _, true) = $0 { true } else { false } }
                }
            }
            if !liste.isEmpty { ergebnis[start] = liste }
        }
        return ergebnis
    }

    /// Filter nur, wenn es neben den Einheiten Kurse oder Cardio gibt; sonst keine
    /// Leiste (Leinwand 2g).
    static func sichtbareFilter(hatPlan: Bool, hatKurse: Bool, hatCardio: Bool) -> [PlanFilter] {
        guard hatKurse || hatCardio else { return [] }
        var filter: [PlanFilter] = [.alle]
        if hatPlan { filter.append(.einheiten) }
        if hatKurse { filter.append(.kurse) }
        if hatCardio { filter.append(.cardio) }
        return filter
    }

    private static func isoWochentag(_ tag: Date, _ kalender: Calendar) -> Int {
        // Calendar.weekday: 1 = Sonntag ... 7 = Samstag.
        (kalender.component(.weekday, from: tag) + 5) % 7 + 1
    }

    private static func tagesSchluessel(_ tag: Date, _ kalender: Calendar) -> String {
        let c = kalender.dateComponents([.year, .month, .day], from: tag)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
