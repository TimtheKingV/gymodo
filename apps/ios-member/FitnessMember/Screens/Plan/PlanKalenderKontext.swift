import Foundation

/// Zeitzone, Kalender und Wochenstand des Plans, einmal gerechnet fuer Plan-Tab
/// und Home, damit beide denselben Tag nennen und dieselbe Woche zaehlen.
enum PlanKalenderKontext {
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

    // MARK: - Woche ohne feste Tage (Spec P2 §8)

    /// Das Wochenziel des Servers; ein aelterer Server (Prod vor 0072) liefert
    /// keins -- dann zaehlen die Kraft-Tage des Plans, sonst 2, ohne Cardio.
    /// Die eine Stelle fuer diesen Ersatz (Plan-Tab und Home).
    ///
    /// Der Ersatz im Client gilt nur fuer die alte Prod-API ohne `wochenziel`
    /// im Bootstrap; nach dem API-Deploy von P2 kann er samt `raster` entfallen.
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
}
