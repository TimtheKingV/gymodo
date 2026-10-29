import Foundation

/// Der reine Zustand des Plan-Tabs: gewaehlter Tag und Filter, beide `nil`,
/// solange niemand getippt hat -- dann gelten die Vorauswahlen. Dasselbe Muster
/// wie `gewaehlterTagId`/`gewaehlteAnsicht` im Kurse-Screen: eine abgeleitete
/// Vorauswahl bleibt richtig, wenn ueber Mitternacht oder nach neuem Laden die
/// Daten unter der offenen App wechseln.
struct PlanTabZustand: Equatable {
    var gewaehlterTag: Date?
    var gewaehlterFilter: PlanFilter?

    init(gewaehlterTag: Date? = nil, gewaehlterFilter: PlanFilter? = nil) {
        self.gewaehlterTag = gewaehlterTag
        self.gewaehlterFilter = gewaehlterFilter
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

    // MARK: - Anzeige-Raster

    /// Das Raster, das der Tab zeigt.
    ///
    /// Der Plan bleibt stabil (F14): eine Profilaenderung ("Einplanen") schreibt
    /// nur die Wochentage ins Profil, `plan.wochenraster` bleibt, wie es beim
    /// Erzeugen war. Weichen die Profil-Tage davon ab, gelten fuer die Anzeige
    /// die Profil-Tage -- sonst haette "Einplanen" keine sichtbare Wirkung.
    /// Je Art gilt: nicht leeres Profilfeld vor Raster (Regel siehe unten).
    ///
    /// Die Einheiten auf den Krafttagen folgen der Folge, nicht dem Kalender:
    /// erste Einheit des Rasters (sonst die erste des Plans), dann weiter in
    /// Planreihenfolge im Kreis. Gleiche Tage ergeben damit genau das Raster.
    static func anzeigeRaster(
        planRaster: [Rasterplatz], einheiten: [String], profil: TrainingsplanProfil?
    ) -> [Rasterplatz] {
        // Der Server liefert die Felder nie als nil, sondern leer (DB-Default
        // '{}'): leer heisst "nicht gesetzt". Sind Kraft-Tage gesetzt, ist das
        // Profil durch "Einplanen" vollstaendig -- dann heissen leere Kurs-
        // oder Cardio-Tage "keine" (Ruling Fix-Runde 1).
        let kraftProfil = profil?.kraftTage ?? []
        let kursProfil = profil?.kursTage ?? []
        let cardioProfil = profil?.cardioTage ?? []
        let vollstaendig = !kraftProfil.isEmpty
        guard vollstaendig || !kursProfil.isEmpty || !cardioProfil.isEmpty else { return planRaster }

        func rasterTage(_ art: Wochenart) -> [Int] {
            planRaster.filter { $0.art == art }.map(\.tag)
        }
        let kurs = vollstaendig || !kursProfil.isEmpty ? kursProfil : rasterTage(.kurs)
        let cardio = vollstaendig || !cardioProfil.isEmpty ? cardioProfil : rasterTage(.cardio)
        let kraft = vollstaendig ? kraftProfil : rasterTage(.kraft)

        let ersteRasterEinheit = planRaster.sorted { $0.tag < $1.tag }.first { $0.art == .kraft }?.einheitKey
        let start = ersteRasterEinheit.flatMap { einheiten.firstIndex(of: $0) } ?? 0

        var ergebnis: [Rasterplatz] = []
        for (i, tag) in Set(kraft).sorted().enumerated() {
            let key = einheiten.isEmpty ? nil : einheiten[(start + i) % einheiten.count]
            ergebnis.append(Rasterplatz(tag: tag, art: .kraft, einheitKey: key))
        }
        ergebnis += Set(kurs).map { Rasterplatz(tag: $0, art: .kurs, einheitKey: nil) }
        ergebnis += Set(cardio).map { Rasterplatz(tag: $0, art: .cardio, einheitKey: nil) }
        // Nach Tag, an einem Tag Kraft vor Kurs vor Cardio (wie der Server sortiert).
        let rang: [Wochenart: Int] = [.kraft: 0, .kurs: 1, .cardio: 2]
        return ergebnis.sorted { ($0.tag, rang[$0.art] ?? 0) < ($1.tag, rang[$1.art] ?? 0) }
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
        return "KW \(kw) · \(text(erster)) – \(text(letzter))"
    }

    /// Die naechsten Termine NACH `nach` (der Tag selbst zaehlt nicht), fuer
    /// "Als nächstes" auf einem leeren Tag.
    static func alsNaechstes(
        termine: [Date: [PlanTermin]], nach: Date, anzahl: Int
    ) -> [(tag: Date, termin: PlanTermin)] {
        termine.keys.filter { $0 > nach }.sorted()
            .flatMap { tag in (termine[tag] ?? []).map { (tag: tag, termin: $0) } }
            .prefix(anzahl)
            .map { $0 }
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
