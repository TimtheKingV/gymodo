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

enum PlanFilter: CaseIterable {
    case alle, kraft, kurse, cardio

    var titel: String {
        switch self {
        case .alle: "Alle"
        case .kraft: "Kraft"
        case .kurse: "Kurse"
        case .cardio: "Cardio"
        }
    }
}

/// Reine Darstellungslogik des Plan-Tabs. Die Termine je Tag legt
/// `PlanKalender` an.
enum PlanWoche {
    /// Filter nur, wenn es neben Kraft Kurse oder Cardio gibt; sonst keine
    /// Leiste (Leinwand 2g).
    static func sichtbareFilter(hatPlan: Bool, hatKurse: Bool, hatCardio: Bool) -> [PlanFilter] {
        guard hatKurse || hatCardio else { return [] }
        var filter: [PlanFilter] = [.alle]
        if hatPlan { filter.append(.kraft) }
        if hatKurse { filter.append(.kurse) }
        if hatCardio { filter.append(.cardio) }
        return filter
    }

    /// ISO-Wochentag (1 = Montag ... 7 = Sonntag), unabhaengig von `Calendar.firstWeekday`.
    static func isoWochentag(_ tag: Date, _ kalender: Calendar) -> Int {
        // Calendar.weekday: 1 = Sonntag ... 7 = Samstag.
        (kalender.component(.weekday, from: tag) + 5) % 7 + 1
    }

    /// Der Tag als "YYYY-MM-DD" im `kalender`.
    static func tagesSchluessel(_ tag: Date, _ kalender: Calendar) -> String {
        let c = kalender.dateComponents([.year, .month, .day], from: tag)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
