import Foundation

/// Womit der Training-Tab startet (E8).
/// String-Rohwerte: `TrainingEinstiegSpeicher` legt ihn je Session ab.
enum TrainingEinstieg: String, Equatable { case auswahl, plan, frei }

/// Ein weiterer Plantermin dieser Woche in der Auswahl.
enum TrainingAuswahlOption: Equatable, Identifiable {
    case einheit(key: String, tag: Date)
    case cardio(tag: Date)
    case kurs(titel: String, beginn: Date, tag: Date)

    var id: String {
        switch self {
        case .einheit(let key, _): "einheit-\(key)"
        case .cardio(let tag): "cardio-\(Self.tagFormat.string(from: tag))"
        case .kurs(_, let beginn, _): "kurs-\(beginn.formatted(.iso8601))"
        }
    }

    // Nur fuer stabile IDs; Zone fest, damit die ID nicht vom Geraetekalender abhaengt.
    private static let tagFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

struct TrainingAuswahlModell: Equatable {
    /// Die Einheit von "Heute geplant"; nil an Tagen ohne Krafttermin heute.
    let heuteEinheitKey: String?
    /// Chronologisch, heute bis Sonntag.
    let weitere: [TrainingAuswahlOption]
}

enum TrainingAuswahl {
    static func modell(termine: [Date: [PlanTermin]], heute: Date, naechsteEinheitKey: String?,
                       kalender: Calendar) -> TrainingAuswahlModell {
        let start = kalender.startOfDay(for: heute)
        // Gregorian weekday: 1 = Sonntag ... 7 = Samstag; Woche endet Sonntag.
        let wochentag = kalender.component(.weekday, from: start)
        let tageBisSonntag = (8 - wochentag) % 7

        var heuteKey: String?
        var gesehen = Set<String>()
        var optionen: [TrainingAuswahlOption] = []
        var ersterTagJeEinheit: [String: Date] = [:]

        for offset in 0...tageBisSonntag {
            guard let tag = kalender.date(byAdding: .day, value: offset, to: start) else { continue }
            var cardioSchon = false
            for termin in termine[tag] ?? [] where termin.zustand == .geplant {
                switch termin {
                case .einheit(let key, _):
                    if ersterTagJeEinheit[key] == nil { ersterTagJeEinheit[key] = tag }
                    if offset == 0 { heuteKey = naechsteEinheitKey ?? key }
                    optionen.append(.einheit(key: key, tag: tag))
                case .cardio:
                    if !cardioSchon { optionen.append(.cardio(tag: tag)); cardioSchon = true }
                case .kurs(let titel, let beginn, let angemeldet, _):
                    if angemeldet { optionen.append(.kurs(titel: titel, beginn: beginn, tag: tag)) }
                }
            }
        }

        var weitere: [TrainingAuswahlOption] = []
        for option in optionen {
            if case .einheit(let key, _) = option {
                if key == heuteKey || !gesehen.insert(key).inserted { continue }
            }
            weitere.append(option)
        }

        // Ohne heutigen Krafttermin ist die naechste Einheit ohnehin dran: sie steht vorn.
        if heuteKey == nil, let next = naechsteEinheitKey {
            weitere.removeAll { $0 == .einheit(key: next, tag: ersterTagJeEinheit[next] ?? start) }
            weitere.insert(.einheit(key: next, tag: ersterTagJeEinheit[next] ?? start), at: 0)
        }
        return TrainingAuswahlModell(heuteEinheitKey: heuteKey, weitere: weitere)
    }

    /// Schluessel der Einheit, die nach dem Vorziehen von `einheitKey` drankommt (E9).
    static func danach(einheitKey: String, einheitKeys: [String]) -> String {
        TrainingsplanFolge.naechsteEinheitKey(einheitKeys: einheitKeys, zuletzt: einheitKey)
    }
}
