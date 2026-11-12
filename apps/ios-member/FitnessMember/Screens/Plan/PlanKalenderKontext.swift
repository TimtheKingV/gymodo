import Foundation

/// Zeitzone, Kalender und Termine des Plans, einmal gerechnet fuer Plan-Tab,
/// Einheiten-Detail und Home, damit alle denselben Tag nennen und dieselben
/// Tage markieren. Dazu der geplante Tag einer Einheit aus den Terminen von
/// `PlanKalender`.
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

    /// Dieselbe Zeitzone aus den Rohdaten: die erste Studio-Zone ist die des
    /// aktiven Studios (vorn in `KurseStudios.reihenfolge`).
    static func zeitzone(bootstrap: BootstrapResponse?, aktivesStudioId: String?, wochenZone: String?) -> String {
        let studios = KurseStudios.reihenfolge(alle: bootstrap?.studios.map(\.id) ?? [], aktiv: aktivesStudioId)
        return zeitzone(
            wochenZone: wochenZone,
            ersteStudioZone: studios.first.flatMap { erstes in
                bootstrap?.studios.first { $0.id == erstes }?.timezone
            })
    }

    /// Bisheriger Zusammenbau mit festen Tagen -- nur noch Home und
    /// Einheiten-Detail, entfaellt mit Task 13 (Plan-Tab nutzt `stand`).
    /// `PlanKalender.termine` mit den Eingaben, die Plan-Tab, Einheiten-Detail
    /// und Home gleich zusammensetzen: Raster wie angezeigt (`anzeigeRaster`),
    /// die Folge ab der Einheit von heute (`PlanAnzeige.heute`, sonst der
    /// Server), trainierte Tage und `verlaufAb` aus dem Verlauf.
    static func termine(
        plan: Trainingsplan, tage: [Date], kalender: Calendar, profil: TrainingsplanProfil?,
        heuteEinheitKey: String?, sessions: [SessionSummary], gesamt: Int?, verlaufGeladen: Bool,
        heute: Date, kurse: [CourseWeekSession], cardioErledigt: Set<String>,
        cardioGeladen: [ClosedRange<String>], filter: PlanFilter
    ) -> [Date: [PlanTermin]] {
        let beginn = plan.beginn.flatMap(Zeitpunkt.parse)
        return PlanKalender.termine(
            tage: tage, kalender: kalender,
            raster: PlanTabZustand.anzeigeRaster(
                planRaster: plan.wochenraster, einheiten: plan.einheiten.map(\.key), profil: profil),
            einheiten: plan.einheiten.map(\.key),
            naechsteEinheitKey: heuteEinheitKey ?? plan.naechsteEinheitKey,
            erledigt: plan.erledigt,
            trainiertAn: Set(HomeSerie.einheitenJeTag(sessions, zeitzone: kalender.timeZone.identifier).keys),
            beginn: beginn,
            verlaufAb: PlanKalender.verlaufAb(
                sessions: sessions, gesamt: gesamt, geladen: verlaufGeladen, beginn: beginn, kalender: kalender),
            heute: heute, kurse: kurse, cardioErledigt: cardioErledigt, cardioGeladen: cardioGeladen,
            filter: filter)
    }

    // MARK: - Woche ohne feste Tage (Spec P2 §8)

    /// Das Wochenziel des Servers; ein aelterer Server (Prod vor 0072) liefert
    /// keins -- dann zaehlen die Kraft-Tage des Plans, sonst 2, ohne Cardio.
    /// Die eine Stelle fuer diesen Ersatz (Plan-Tab und Home).
    static func wochenziel(server: Wochenziel?, raster: [Rasterplatz]) -> Wochenziel {
        if let server { return server }
        let kraftTage = raster.filter { $0.art == .kraft }.count
        return Wochenziel(kraft: kraftTage > 0 ? kraftTage : 2, cardio: 0, cardioMinuten: 30)
    }

    static func wochenziel(bootstrap: BootstrapResponse?) -> Wochenziel {
        wochenziel(
            server: bootstrap?.member.wochenziel,
            raster: PlanAnzeige.plan(bootstrap: bootstrap)?.wochenraster ?? [])
    }

    /// Der gemeinsame Zusammenbau der Woche fuer Plan-Tab und Home: Ziel (mit
    /// Ersatz), Folge ab der Einheit von heute (`PlanAnzeige.heute`, sonst der
    /// Server) und die gezaehlten Einheiten des Plans. Ohne Plan entfallen die
    /// offenen Kraft-Karten, Cardio und Kurse bleiben.
    static func stand(
        bootstrap: BootstrapResponse?, wocheStart: Date, heute: Date, kalender: Calendar,
        heuteEinheitKey: String?, sitzungen: [SessionSummary], cardioChecks: [CardioCheck],
        kurse: [CourseWeekSession], filter: PlanFilter
    ) -> PlanWochenStand {
        let plan = PlanAnzeige.plan(bootstrap: bootstrap)
        return PlanWochenRechnung.berechne(
            wocheStart: wocheStart, heute: heute, kalender: kalender, ziel: wochenziel(bootstrap: bootstrap),
            einheiten: plan?.einheiten.map(\.key) ?? [],
            naechsteEinheitKey: heuteEinheitKey ?? plan?.naechsteEinheitKey,
            sitzungen: sitzungen, erledigt: plan?.erledigt ?? [], cardioChecks: cardioChecks,
            kurse: kurse, filter: filter)
    }

    /// "yyyy-MM-dd" (Tages-Id der Streak-Woche) -> `startOfDay` im Kalender des Plans.
    static func tag(id: String, kalender: Calendar) -> Date? {
        let teile = id.split(separator: "-").compactMap { Int($0) }
        guard teile.count == 3 else { return nil }
        return kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))
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
