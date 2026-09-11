import Foundation

/// Ein Tag im Kalender des Home-Tabs -- im Wochenstreifen wie im
/// Monatsgitter.
///
/// `id` ist das Ortsdatum ("yyyy-MM-dd") in der Zeitzone des Studios --
/// dasselbe Format, in dem `Serienstand` seine Tage nennt, damit der
/// Abgleich ein Stringvergleich bleibt. Derselbe Kniff wie bei
/// `KurseWochentag.id` gegen `CourseWeekSession.localDay`.
struct HomeSerieTag: Identifiable, Equatable {
    let id: String
    /// "M", "D", "M", ... -- die schmalste Form ("ccccc", stand-alone).
    /// Sieben Zellen nebeneinander sind ein Raster, kein Text: der zweite
    /// Buchstabe kostet Breite und sagt nichts, was die Stellung im
    /// Streifen nicht schon sagt. Im Monatsgitter steht er ohnehin nur
    /// einmal als Spaltenkopf.
    let buchstabe: String
    /// "Montag", "Dienstag", ... fuer VoiceOver.
    let wochentagVoll: String
    let tagesnummer: Int
    /// Mindestens eine Einheit an diesem Tag: die Hantel statt der Zahl.
    let trainiert: Bool
    let istHeute: Bool
    /// Nur im Monatsgitter belegt: ein Tag aus dem Vor- oder Folgemonat,
    /// der eine Zeile auffuellt. Er wird gezeigt, damit das Gitter keine
    /// Loecher hat, aber nicht bedient.
    var ausserhalb: Bool = false
}

/// Die reinen Ableitungen des Home-Kalenders -- getrennt vom View,
/// damit sie pruefbar bleiben (wie `HomeZeilen`).
///
/// **Zwei Quellen, und beide sind noetig.** Serie, Wochenbeginn und die
/// Trainingstage der laufenden Woche kommen fertig vom Server
/// (`Serienstand`), weil nur dort die Zeitzone des Studios und die ganze
/// Geschichte des Mitglieds liegen: die Liste im Client ist auf 50
/// Einheiten gedeckelt, und eine daraus gerechnete Serie waere bei "12
/// Wochen" eine Untergrenze, die sich als Wahrheit ausgibt.
///
/// Das Monatsgitter kann der Server so aber nicht beantworten -- sein
/// `trainedDays` reicht genau ueber die laufende Woche. Es liest deshalb
/// die Einheitenliste (`einheitenJeTag`), und `trainingstage(...)` legt
/// beide Quellen zusammen, damit derselbe Tag in Woche und Monat nicht
/// verschieden aussieht. Der Deckel bleibt: 50 Einheiten sind bei drei
/// Einheiten die Woche rund vier Monate, der offene Monat liegt immer
/// darin. Faellt ein Tag doch heraus, fehlt seine Hantel -- eine
/// erfundene waere schlimmer.
enum HomeSerie {
    /// Die Tage mit mindestens einer Einheit, aus beiden Quellen.
    ///
    /// Die laufende Woche gewinnt aus `trainedDays` auch die Tage, an
    /// denen gerade noch eine Einheit laeuft: die hat kein `completedAt`
    /// und steht darum in keiner Buendelung.
    static func trainingstage(
        stand: Serienstand, einheitenJeTag: [String: [SessionSummary]]
    ) -> Set<String> {
        Set(stand.trainedDays).union(einheitenJeTag.keys)
    }

    /// Die abgeschlossenen Einheiten, nach ORTSTAG des Studios gebuendelt
    /// und je Tag mit der juengsten zuerst.
    ///
    /// Die Zeitzone kommt vom Aufrufer (Bootstrap des Studios), nicht aus
    /// `TimeZone.current`: eine Einheit gehoert dem Studio, nicht dem
    /// Geraet, und sonst schoebe ein Mitglied im Urlaub seine Abendeinheit
    /// auf den Folgetag. Dieselbe Festlegung wie im Kursplan.
    static func einheitenJeTag(
        _ sessions: [SessionSummary], zeitzone: String
    ) -> [String: [SessionSummary]] {
        let formatter = DateFormatter()
        // en_US_POSIX fuer ein rein numerisches, festes Muster -- dieselbe
        // Begruendung wie bei KursZeit.uhrzeit.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"

        var gebuendelt: [String: [SessionSummary]] = [:]
        for einheit in HomeZeilen.abgeschlossene(sessions) {
            guard let start = Zeitpunkt.parse(einheit.startedAt) else { continue }
            gebuendelt[formatter.string(from: start), default: []].append(einheit)
        }
        return gebuendelt.mapValues { $0.sorted { $0.startedAt > $1.startedAt } }
    }

    /// Die sieben Tageszellen von Montag bis Sonntag.
    ///
    /// Gerechnet wird auf reinen Kalendertagen in UTC, nicht in der
    /// Systemzeitzone: `weekStart` IST schon ein Ortsdatum des Studios,
    /// und es ein zweites Mal durch eine Zeitzone zu schicken verschoebe
    /// es um bis zu einen Tag.
    ///
    /// Leer bei unlesbarem `weekStart`: der Wert kann aus einem
    /// gemerkten Stand kommen. Kein Streifen ist besser als ein
    /// geratener.
    ///
    /// `trainingstage` uebergibt der Aufrufer, damit Woche und Monat
    /// dieselbe Menge lesen; ohne Angabe bleibt es bei dem, was der
    /// Server fuer diese Woche nennt.
    static func tage(_ stand: Serienstand, trainingstage: Set<String>? = nil) -> [HomeSerieTag] {
        guard let montag = datumsFormatter.date(from: stand.weekStart) else { return [] }

        let trainiert = trainingstage ?? Set(stand.trainedDays)
        return (0..<7).compactMap { versatz in
            guard let tag = kalender.date(byAdding: .day, value: versatz, to: montag) else {
                return nil
            }
            return bauen(tag, heute: stand.today, trainingstage: trainiert)
        }
    }

    /// Das Monatsgitter um einen Tag herum -- volle Wochen von Montag bis
    /// Sonntag, so viele Zeilen wie der Monat braucht (vier bis sechs).
    ///
    /// Keine feste Sechszeiligkeit: der Monat hat keine Vor/Zurueck-Taste,
    /// es wird also nie zwischen zwei Monaten umgeschaltet, und eine
    /// dauerhaft leere sechste Zeile waere 52 pt Nichts unter dem Gitter.
    ///
    /// Die auffuellenden Tage der Nachbarmonate stehen mit
    /// `ausserhalb == true` drin, statt zu fehlen: ein Gitter mit Loechern
    /// laesst die Spalten wandern, und dann steht der 1. nicht mehr unter
    /// seinem Wochentag.
    ///
    /// Leer bei unlesbarem `tagId` -- wie `tage(_:)`.
    static func monatstage(
        um tagId: String, heute: String, trainingstage: Set<String>
    ) -> [HomeSerieTag] {
        guard let anker = datumsFormatter.date(from: tagId),
              let erster = kalender.date(
                from: kalender.dateComponents([.year, .month], from: anker)),
              let tageImMonat = kalender.range(of: .day, in: .month, for: anker)?.count
        else { return [] }

        // component(.weekday) liefert 1 = Sonntag ... 7 = Samstag, immer
        // in dieser Zaehlung. Die Woche beginnt hier am Montag, nicht an
        // `Calendar.firstWeekday` -- dieselbe Festlegung wie im Kursplan.
        let wochentagIndex = kalender.component(.weekday, from: erster)
        let vorlauf = wochentagIndex == 1 ? 6 : wochentagIndex - 2
        let zellen = Int((Double(vorlauf + tageImMonat) / 7).rounded(.up)) * 7
        let monat = kalender.component(.month, from: anker)

        return (0..<zellen).compactMap { versatz in
            guard let tag = kalender.date(
                byAdding: .day, value: versatz - vorlauf, to: erster) else { return nil }
            var gebaut = bauen(tag, heute: heute, trainingstage: trainingstage)
            gebaut.ausserhalb = kalender.component(.month, from: tag) != monat
            return gebaut
        }
    }

    /// "September 2026" -- die Ueberschrift ueber dem Monatsgitter. Mit
    /// Jahr, anders als `tagestitel`: das Gitter kann ueber den
    /// Jahreswechsel reichen, und dann ist "Januar" allein zweideutig.
    static func monatstitel(_ tagId: String) -> String {
        guard let tag = datumsFormatter.date(from: tagId) else { return "" }
        return monatsFormatter.string(from: tag)
    }

    /// "Freitag, 11. September" -- die Zeile ueber den Karten eines
    /// ausgeklappten Tages. Ohne Jahr, wie `Zahlformat.wochentagDatum`:
    /// der gewaehlte Tag steht zwei Zentimeter darueber im Gitter.
    static func tagestitel(_ tagId: String) -> String {
        guard let tag = datumsFormatter.date(from: tagId) else { return "" }
        return tagesFormatter.string(from: tag)
    }

    /// "Woche" nur bei genau einer -- "1 Wochen" soll gar nicht erst
    /// entstehen koennen. Null Wochen bleiben Mehrzahl.
    static func wochenLabel(_ wochen: Int) -> String {
        wochen == 1 ? "Woche" : "Wochen"
    }

    /// "34 Einheiten gesamt · zuletzt gestern" -- die Zeile neben der
    /// Flamme. Sie traegt, was die frueheren Kennzahlen "gesamt" und
    /// "Tage her" sagten; der Streifen selbst ersetzt "diese Woche".
    ///
    /// Ohne Verlauf steht hier keine Null (designsystem.md SS5), sondern
    /// der Satz, der sagt, was fehlt.
    static func fussnote(
        gesamt: Int, lastSessionAt: String?, jetzt: Date, kalender: Calendar
    ) -> String {
        guard gesamt > 0 else { return "Noch keine Einheit erfasst" }

        let einheiten = "\(gesamt) \(gesamt == 1 ? "Einheit" : "Einheiten") gesamt"
        guard let tage = HomeZeilen.tageHer(lastSessionAt, jetzt: jetzt, kalender: kalender) else {
            return einheiten
        }
        return "\(einheiten) · zuletzt \(zuletzt(tage))"
    }

    /// Serie und Trainingstage als EIN Satz -- das Label der Flamme.
    ///
    /// Die Tageszellen sind seit dem Ausklapper einzeln bedienbar und
    /// tragen ihr eigenes Label; dieser Satz bleibt trotzdem, weil er die
    /// Woche auf einmal beantwortet, ohne dass VoiceOver sieben Elemente
    /// durchlaufen muss.
    static func vorlesetext(wochen: Int, tage: [HomeSerieTag]) -> String {
        let serie = wochen == 0
            ? "Keine laufende Serie."
            : "Serie: \(wochen) \(wochenLabel(wochen))."

        let trainingstage = tage.filter(\.trainiert).map(\.wochentagVoll)
        let woche = trainingstage.isEmpty
            ? "Diese Woche noch nicht trainiert."
            : "Diese Woche \(aufzaehlung(trainingstage)) trainiert."

        return "\(serie) \(woche)"
    }

    // MARK: - Innereien

    private static func bauen(
        _ tag: Date, heute: String, trainingstage: Set<String>
    ) -> HomeSerieTag {
        let id = datumsFormatter.string(from: tag)
        return HomeSerieTag(
            id: id,
            buchstabe: buchstabenFormatter.string(from: tag).uppercased(),
            wochentagVoll: vollFormatter.string(from: tag),
            tagesnummer: kalender.component(.day, from: tag),
            trainiert: trainingstage.contains(id),
            istHeute: id == heute)
    }

    /// "heute" und "gestern" statt "vor 0 Tagen" -- eine Zahl, die
    /// niemand so sagt, liest sich wie ein Formatfehler.
    private static func zuletzt(_ tage: Int) -> String {
        switch tage {
        case ...0: "heute"
        case 1: "gestern"
        default: "vor \(tage) Tagen"
        }
    }

    /// "Montag, Dienstag und Freitag" -- wie man es spricht.
    private static func aufzaehlung(_ namen: [String]) -> String {
        guard let letzter = namen.last else { return "" }
        guard namen.count > 1 else { return letzter }
        return namen.dropLast().joined(separator: ", ") + " und " + letzter
    }

    /// UTC, siehe `tage(_:)`. Gregorianisch fest vorgegeben: ein
    /// Systemkalender koennte ein anderer sein, und dann stimmten die
    /// Tagesnummern nicht mehr mit dem Datum des Servers ueberein.
    private static let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!
        return kalender
    }()

    /// en_US_POSIX fuer ein rein numerisches, festes Muster -- dieselbe
    /// Begruendung wie bei KursZeit.uhrzeit.
    private static let datumsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let buchstabenFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        // "ccccc" (stand-alone, narrow) liefert "M", "D", "M", "D", "F",
        // "S", "S" -- nicht "EEEEE", das in manchen Sprachen die Form fuer
        // "am Montag" waehlt.
        formatter.dateFormat = "ccccc"
        return formatter
    }()

    private static let vollFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let monatsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter
    }()

    private static let tagesFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("EEEEddMMMM")
        return formatter
    }()
}
