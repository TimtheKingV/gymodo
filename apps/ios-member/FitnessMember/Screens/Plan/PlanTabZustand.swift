import Foundation

/// Woche (Streifen) oder Monat (Gitter) im Plan-Tab.
enum PlanAnsicht: CaseIterable {
    case woche, monat

    var titel: String {
        switch self {
        case .woche: "Woche"
        case .monat: "Monat"
        }
    }
}

/// Der reine Zustand des Plan-Tabs: gewaehlter Tag und Filter, beide `nil`,
/// solange niemand getippt hat -- dann gelten die Vorauswahlen. Dasselbe Muster
/// wie `gewaehlterTagId`/`gewaehlteAnsicht` im Kurse-Screen: eine abgeleitete
/// Vorauswahl bleibt richtig, wenn ueber Mitternacht oder nach neuem Laden die
/// Daten unter der offenen App wechseln.
struct PlanTabZustand: Equatable {
    var gewaehlterTag: Date?
    var gewaehlterFilter: PlanFilter?
    var ansicht: PlanAnsicht

    init(gewaehlterTag: Date? = nil, gewaehlterFilter: PlanFilter? = nil, ansicht: PlanAnsicht = .woche) {
        self.gewaehlterTag = gewaehlterTag
        self.gewaehlterFilter = gewaehlterFilter
        self.ansicht = ansicht
    }

    // MARK: - Tag

    /// Heute, wenn heute in `tage` liegt, sonst der erste Tag (Montag). Beim
    /// Blaettern in eine andere Woche steht die Auswahl damit auf deren Montag,
    /// zurueck in die laufende Woche wieder auf heute.
    static func vorauswahl(tage: [Date], heute: Date, kalender: Calendar) -> Date {
        let heuteStart = kalender.startOfDay(for: heute)
        if let treffer = tage.first(where: { kalender.isDate($0, inSameDayAs: heuteStart) }) {
            return kalender.startOfDay(for: treffer)
        }
        return tage.first.map { kalender.startOfDay(for: $0) } ?? heuteStart
    }

    /// Die Seite des Streifens: die Woche des gewaehlten Tages, ohne Auswahl
    /// die laufende. Seit der Streifen in die Vergangenheit reicht, ist die
    /// laufende Woche nicht mehr Index 0. Liegt der Tag vor der ersten Seite,
    /// gilt ebenfalls die laufende Woche.
    static func wochenIndex(montage: [Date], tag: Date?, heute: Date) -> Int {
        let laufend = montage.lastIndex { $0 <= heute } ?? 0
        guard let tag else { return laufend }
        return montage.lastIndex { $0 <= tag } ?? laufend
    }

    /// Der getippte Tag, solange er in `tage` liegt (der sichtbaren Woche),
    /// sonst die Vorauswahl.
    func geltenderTag(tage: [Date], heute: Date, kalender: Calendar) -> Date {
        if let gewaehlterTag, tage.contains(where: { kalender.isDate($0, inSameDayAs: gewaehlterTag) }) {
            return kalender.startOfDay(for: gewaehlterTag)
        }
        return Self.vorauswahl(tage: tage, heute: heute, kalender: kalender)
    }

    // MARK: - Filter

    /// Der getippte Filter, solange er noch angeboten wird -- verschwinden etwa
    /// die Kurse (Studio verlassen), gilt wieder `.alle`. Ohne Filterleiste
    /// (Leinwand 2g) gibt es nur `.alle`. Wie `KurseAnsicht.geltend`.
    func geltenderFilter(sichtbar: [PlanFilter]) -> PlanFilter {
        guard let gewaehlterFilter, sichtbar.contains(gewaehlterFilter) else { return .alle }
        return gewaehlterFilter
    }

    // MARK: - Woche

    /// "KW 44 · 26. Okt – 1. Nov" -- ISO-Kalenderwoche, Monate ohne Punkt.
    static func wochenTitel(tage: [Date], kalender: Calendar) -> String {
        guard let erster = tage.first, let letzter = tage.last else { return "" }
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = kalender.timeZone
        let kw = iso.component(.weekOfYear, from: erster)

        let monat = DateFormatter()
        monat.locale = Locale(identifier: "de_DE")
        monat.timeZone = kalender.timeZone
        monat.dateFormat = "LLL"
        func text(_ d: Date) -> String {
            let m = monat.string(from: d).replacingOccurrences(of: ".", with: "")
            return "\(kalender.component(.day, from: d)). \(m)"
        }
        // Im selben Monat steht er einmal: "9.–15. Nov" (Leinwand "Kalender B").
        if kalender.isDate(erster, equalTo: letzter, toGranularity: .month) {
            return "KW \(kw) · \(kalender.component(.day, from: erster)).–\(text(letzter))"
        }
        return "KW \(kw) · \(text(erster)) – \(text(letzter))"
    }
}

/// Die deutschen Namen der Cardio-Arten (Schluessel aus CARDIO_ARTEN).
enum CardioArtName {
    static func text(_ art: String) -> String {
        switch art {
        case "laufen": "Laufen"
        case "radfahren": "Radfahren"
        case "schwimmen": "Schwimmen"
        case "wandern": "Wandern"
        case "anderes": "Anderes"
        default: PlanNamen.lesbar(art)
        }
    }

    /// "Laufen oder Schwimmen · du wählst"; ohne Arten nur "Du wählst die Art".
    static func zeile(_ arten: [String]) -> String {
        guard !arten.isEmpty else { return "Du wählst die Art" }
        let namen = arten.map(text)
        let liste = namen.count == 1
            ? namen[0]
            : namen.dropLast().joined(separator: ", ") + " oder " + namen.last!
        return namen.count == 1 ? liste : "\(liste) · du wählst"
    }
}
