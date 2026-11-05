import Foundation

/// Zeitzone und Kalender des Plans, einmal gerechnet fuer Plan-Tab und
/// Einheiten-Detail, damit beide denselben Tag nennen. Dazu der geplante Tag
/// einer Einheit aus den Terminen von `PlanKalender`.
enum PlanKalenderKontext {
    /// Tage, die das Einheiten-Detail nach vorn schaut.
    static let fensterTage = 28

    /// Zeitzone der Kurswoche, sonst die des ersten Studios (aktives vorn),
    /// sonst die des Geraets.
    static func zeitzone(
        wochenZone: String?, ersteStudioZone: String?, geraet: String = TimeZone.current.identifier
    ) -> String {
        wochenZone ?? ersteStudioZone ?? geraet
    }

    static func kalender(zeitzone: String) -> Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: zeitzone) ?? .current
        k.locale = Locale(identifier: "de_DE")
        return k
    }

    /// Die Tage ab heute, die `geplanterTag` durchsucht.
    static func fenster(heute: Date, kalender: Calendar) -> [Date] {
        let start = kalender.startOfDay(for: heute)
        return (0..<fensterTage).compactMap { kalender.date(byAdding: .day, value: $0, to: start) }
    }

    /// Erster Tag ab heute, an dem `einheitKey` mit Zustand .geplant liegt; nil,
    /// wenn die Einheit im Fenster nicht drankommt.
    static func geplanterTag(
        einheitKey: String, termine: [Date: [PlanTermin]], heute: Date, kalender: Calendar
    ) -> Date? {
        let start = kalender.startOfDay(for: heute)
        let ende = kalender.date(byAdding: .day, value: fensterTage, to: start) ?? .distantFuture
        return termine.keys.filter { $0 >= start && $0 < ende }.sorted().first { tag in
            termine[tag]?.contains(.einheit(key: einheitKey, zustand: .geplant)) ?? false
        }
    }

    static func istGeplanterTag(_ tag: Date?, heute: Date, kalender: Calendar) -> Bool {
        tag.map { kalender.isDate($0, inSameDayAs: heute) } ?? false
    }
}
