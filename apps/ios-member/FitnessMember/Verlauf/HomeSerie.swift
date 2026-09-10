import Foundation

/// Ein Tag im Wochenstreifen des Home-Tabs.
///
/// `id` ist das Ortsdatum ("yyyy-MM-dd") in der Zeitzone des Studios --
/// dasselbe Format, in dem `Serienstand` seine Tage nennt, damit der
/// Abgleich ein Stringvergleich bleibt. Derselbe Kniff wie bei
/// `KurseWochentag.id` gegen `CourseWeekSession.localDay`.
struct HomeSerieTag: Identifiable, Equatable {
    let id: String
    /// "MO", "DI", ... -- "ccc" (stand-alone) liefert das ohne Punkt.
    let kuerzel: String
    /// "Montag", "Dienstag", ... fuer VoiceOver.
    let wochentagVoll: String
    let tagesnummer: Int
    /// Mindestens eine Einheit an diesem Tag: die Hantel statt der Zahl.
    let trainiert: Bool
    let istHeute: Bool
}

/// Die reinen Ableitungen des Serien-Streifens -- getrennt vom View,
/// damit sie pruefbar bleiben (wie `HomeZeilen`).
///
/// **Hier wird nicht gerechnet, hier wird gelesen.** Serie, Wochenbeginn
/// und Trainingstage kommen fertig vom Server (`Serienstand`), weil nur
/// dort die Zeitzone des Studios und die ganze Geschichte des Mitglieds
/// liegen: die Liste im Client ist auf 50 Einheiten gedeckelt, und eine
/// daraus gerechnete Serie waere bei "12 Wochen" eine Untergrenze, die
/// sich als Wahrheit ausgibt.
enum HomeSerie {
    /// Die sieben Tagesboxen von Montag bis Sonntag.
    ///
    /// Gerechnet wird auf reinen Kalendertagen in UTC, nicht in der
    /// Systemzeitzone: `weekStart` IST schon ein Ortsdatum des Studios,
    /// und es ein zweites Mal durch eine Zeitzone zu schicken verschoebe
    /// es um bis zu einen Tag.
    ///
    /// Leer bei unlesbarem `weekStart`: der Wert kann aus einem
    /// gemerkten Stand kommen. Kein Streifen ist besser als ein
    /// geratener.
    static func tage(_ stand: Serienstand) -> [HomeSerieTag] {
        guard let montag = datumsFormatter.date(from: stand.weekStart) else { return [] }

        let trainiert = Set(stand.trainedDays)
        return (0..<7).compactMap { versatz in
            guard let tag = kalender.date(byAdding: .day, value: versatz, to: montag) else {
                return nil
            }
            let id = datumsFormatter.string(from: tag)
            return HomeSerieTag(
                id: id,
                kuerzel: kuerzelFormatter.string(from: tag).uppercased(),
                wochentagVoll: vollFormatter.string(from: tag),
                tagesnummer: kalender.component(.day, from: tag),
                trainiert: trainiert.contains(id),
                istHeute: id == stand.today)
        }
    }

    /// "Woche" nur bei genau einer -- "1 Wochen" soll gar nicht erst
    /// entstehen koennen. Null Wochen bleiben Mehrzahl.
    static func wochenLabel(_ wochen: Int) -> String {
        wochen == 1 ? "Woche" : "Wochen"
    }

    /// "34 Einheiten gesamt · zuletzt gestern" -- die Zeile unter dem
    /// Streifen. Sie traegt, was die frueheren Kennzahlen "gesamt" und
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

    /// Der ganze Streifen als EIN Satz.
    ///
    /// Er ist nicht bedienbar -- sieben einzeln vorgelesene Tagesboxen
    /// waeren nur Weg zwischen der Ueberschrift und dem, was darunter
    /// steht. Dieselbe Ueberlegung wie beim Punkt unter der Tagesbox im
    /// Kursplan, der fuer VoiceOver unsichtbar ist und seine Aussage im
    /// Label des Tages traegt.
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

    private static let kuerzelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        // "ccc" (stand-alone), nicht "EEE" -- liefert "Do" ohne Punkt.
        formatter.dateFormat = "ccc"
        return formatter
    }()

    private static let vollFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
