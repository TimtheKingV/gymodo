import Foundation

/// Ein Tag im Kalender: die Streak-Woche auf Home und das Monatsgitter des
/// Plan-Tabs (`PlanMonatsgitter`).
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
    /// Nur in der Streak-Woche belegt: die Marke des Tages (Kraft, Cardio,
    /// Kurs, gebuchter Kurs) aus `PlanWochenStand.marken`, dieselbe wie im
    /// Plan-Tab. nil = nichts geleistet und kein Kurs gebucht.
    var geplant: TagMarke? = nil
}

/// Was ein Tipp auf einen Tag der Streak-Woche tut (Spec 1.1).
enum HomeSerieTipp: Equatable {
    /// Die Trainings und Kurse des Tages darunter zeigen.
    case ausklappen
    /// In den Plan-Tab auf genau diesen Tag springen (`PlanSprung.tag`).
    case planTag
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
    /// In welcher Zeitzone Einheiten zu Tagen gebuendelt werden. Ohne
    /// aktives Studio (Freies Training) die des Geraets statt UTC: UTC
    /// schob eine Abendeinheit in Berlin auf den Folgetag (Testnotiz
    /// 11.10., #1).
    static func zeitzone(studio: String?, geraet: TimeZone = .current) -> String {
        studio ?? geraet.identifier
    }

    /// Die Tage mit mindestens einer Einheit, aus beiden Quellen.
    ///
    /// Die laufende Woche gewinnt aus `trainedDays` auch die Tage, an
    /// denen gerade noch eine Einheit laeuft: die hat kein `completedAt`
    /// und steht darum in keiner Buendelung.
    ///
    /// Seit P2 nennt der Server in `trainedDays` auch Tage, die nur einen
    /// Cardio-Handhaken oder einen begonnenen Kurs tragen (sie zaehlen fuer die
    /// Serie). Die Hantel heisst aber "Training": Tage aus `cardioOderKursTage`
    /// verlieren sie, ausser eine Sitzung (`sitzungstage`, auch laufende, oder
    /// `einheitenJeTag`) liegt am selben Tag. Ein Servertag, den weder eine
    /// geladene Sitzung noch Cardio/Kurs erklaert (Liste noch nicht geladen),
    /// behaelt sie. Die Serienzahl rechnet weiter allein der Server.
    static func trainingstage(
        stand: Serienstand, einheitenJeTag: [String: [SessionSummary]],
        sitzungstage: Set<String> = [], cardioOderKursTage: Set<String> = []
    ) -> Set<String> {
        let mitSitzung = sitzungstage.union(einheitenJeTag.keys)
        return Set(stand.trainedDays).subtracting(cardioOderKursTage).union(mitSitzung)
    }

    /// Die Tage ("yyyy-MM-dd") mit Cardio- oder Kursmarke (`PlanWochenStand.marken`):
    /// Handhaken, Auto-Cardio, begonnene Kurse. Gebuchte, noch nicht begonnene
    /// Kurse nicht -- die stehen nie in `trainedDays`.
    static func cardioOderKursTage(_ marken: [Date: [TagMarke]], kalender: Calendar) -> Set<String> {
        Set(marken.compactMap { tag, liste in
            liste.contains(where: { $0 == .cardio || $0 == .kurs }) ? PlanWoche.tagesSchluessel(tag, kalender) : nil
        })
    }

    /// Die Ortstage aller geladenen Sitzungen, auch der noch laufenden (ohne
    /// `completedAt`), dazu die lokal laufende (`laufendSeit`).
    static func sitzungstage(
        _ sessions: [SessionSummary], laufendSeit: Date?, zeitzone: String
    ) -> Set<String> {
        let formatter = ortsTagFormatter(zeitzone)
        var tage = Set(sessions.compactMap { Zeitpunkt.parse($0.startedAt).map(formatter.string(from:)) })
        if let laufendSeit { tage.insert(formatter.string(from: laufendSeit)) }
        return tage
    }

    /// Der Ortstag der lokal laufenden Sitzung; nil ohne laufende.
    static func laufenderTag(_ seit: Date?, zeitzone: String) -> String? {
        seit.map(ortsTagFormatter(zeitzone).string(from:))
    }

    /// Ob unter der Serie "Kraft 1/2 · Cardio 0/1" steht (Spec §5): mit Plan,
    /// oder ohne Plan nur mit einem Ziel des Mitglieds (Kraft- oder
    /// Cardio-Zaehler im Profil, weekly_days). Das `wochenziel` des Servers
    /// kommt immer, auch erfunden ("2") -- es allein ist kein Ziel. Ohne
    /// `wochenziel` (alte Prod-API) bleibt ohne Plan die alte Zeile.
    static func zeigtZielZeile(hatPlan: Bool, member: BootstrapResponse.Member?) -> Bool {
        if hatPlan { return true }
        guard let member, member.wochenziel != nil else { return false }
        let profil = member.trainingProfile
        return profil?.kraftProWoche != nil || (profil?.cardioProWoche ?? 0) > 0 || member.goals.weeklyDays != nil
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
        let formatter = ortsTagFormatter(zeitzone)
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
    /// Server fuer diese Woche nennt. `geplant` (Tagesschluessel -> Marke,
    /// aus `planMarken`) legt die Planmarken auf die Tage.
    static func tage(
        _ stand: Serienstand, trainingstage: Set<String>? = nil, geplant: [String: TagMarke] = [:]
    ) -> [HomeSerieTag] {
        tage(stand, wochenVersatz: 0, trainingstage: trainingstage, geplant: geplant)
    }

    /// Eine Woche vor oder zurueck (Testnotiz 19.10., #1): Montag ist
    /// `weekStart` plus sieben Tage je Versatz. Die Planmarken gelten nur fuer
    /// die laufende Woche (Versatz 0) -- mehr liefert `PlanWochenStand` nicht.
    static func tage(
        _ stand: Serienstand, wochenVersatz: Int, trainingstage: Set<String>?, geplant: [String: TagMarke]
    ) -> [HomeSerieTag] {
        guard let laufenderMontag = datumsFormatter.date(from: stand.weekStart),
              let montag = kalender.date(byAdding: .day, value: 7 * wochenVersatz, to: laufenderMontag)
        else { return [] }

        let trainiert = trainingstage ?? Set(stand.trainedDays)
        return (0..<7).compactMap { versatz in
            guard let tag = kalender.date(byAdding: .day, value: versatz, to: montag) else {
                return nil
            }
            var gebaut = bauen(tag, heute: stand.today, trainingstage: trainiert)
            if wochenVersatz == 0 { gebaut.geplant = geplant[gebaut.id] }
            return gebaut
        }
    }

    /// Wie weit der Streifen wischt: zurueck bis zur Woche des fruehesten
    /// geladenen Trainingstags (hoechstens `maxZurueck` Wochen, wie die
    /// Kurswoche), vor bis zur Woche des spaetesten eigenen Kurses. Ohne
    /// beides nur die laufende Woche. Tage als "yyyy-MM-dd".
    static func wochenBereich(
        weekStart: String, fruehesterTag: String?, spaetesterTag: String?,
        maxZurueck: Int = KurseWochenBerechnung.maxWochenZurueck
    ) -> ClosedRange<Int> {
        guard let montag = datumsFormatter.date(from: weekStart) else { return 0...0 }
        func woche(_ tag: String?) -> Int? {
            guard let tag, let datum = datumsFormatter.date(from: tag),
                  let tage = kalender.dateComponents([.day], from: montag, to: datum).day else { return nil }
            return Int((Double(tage) / 7).rounded(.down))
        }
        let unten = max(min(woche(fruehesterTag) ?? 0, 0), -maxZurueck)
        let oben = max(woche(spaetesterTag) ?? 0, 0)
        return unten...oben
    }

    /// Die Marken der Woche (`PlanWochenStand.marken`, je Tag nach Rang
    /// sortiert) als eine Marke je Tag: die erste, also Kraft vor Kurs. Tage
    /// ohne Marke bekommen keinen Eintrag. Schluessel "yyyy-MM-dd" im Kalender
    /// des Plans, dasselbe Format wie `HomeSerieTag.id`.
    static func planMarken(_ marken: [Date: [TagMarke]], kalender: Calendar) -> [String: TagMarke] {
        var ergebnis: [String: TagMarke] = [:]
        for (tag, liste) in marken {
            if let erste = liste.first { ergebnis[PlanWoche.tagesSchluessel(tag, kalender)] = erste }
        }
        return ergebnis
    }

    /// "Kraft 1/2 · Cardio 0/1" -- die Zeile unter der Serie. Der Cardio-Teil
    /// steht nur mit Cardio-Ziel (Auto-Cardio zaehlt auch ohne, wird aber
    /// nicht gezeigt). nil, wenn gar kein Ziel steht.
    static func zielZeile(stand: PlanWochenStand, ziel: Wochenziel) -> String? {
        guard ziel.kraft > 0 || ziel.cardio > 0 else { return nil }
        var teile = ["Kraft \(stand.kraftErledigt)/\(ziel.kraft)"]
        if ziel.cardio > 0 { teile.append("Cardio \(stand.cardioErledigt)/\(ziel.cardio)") }
        return teile.joined(separator: " · ")
    }

    /// "Kraft 1 von 2, Cardio 0 von 1" -- die Zielzeile fuer VoiceOver; "1/2"
    /// liest sie sonst als Bruch oder Datum.
    static func zielVorlesetext(stand: PlanWochenStand, ziel: Wochenziel) -> String {
        var teile = ["Kraft \(stand.kraftErledigt) von \(ziel.kraft)"]
        if ziel.cardio > 0 { teile.append("Cardio \(stand.cardioErledigt) von \(ziel.cardio)") }
        return teile.joined(separator: ", ")
    }

    /// Der Einheiten-Teil des Tageslabels. "Training läuft." nur mit laufender
    /// Sitzung an diesem Tag; ein Hanteltag ohne gebuendelte Einheit (Servertag
    /// ausserhalb der geladenen Liste) heisst schlicht "Training.".
    static func einheitenVorlesetext(anzahl: Int, trainiert: Bool, laeuft: Bool) -> String {
        let einheiten: String? = switch anzahl {
        case 0: laeuft ? nil : (trainiert ? "Training." : "Kein Training.")
        case 1: "Eine Einheit."
        default: "\(anzahl) Einheiten."
        }
        return [einheiten, laeuft ? "Training läuft." : nil].compactMap { $0 }.joined(separator: " ")
    }

    /// Ein Tag mit Inhalt (Einheit oder eigener Kurs) klappt ihn auf -- auch
    /// heute, sonst waeren die Trainings von heute auf Home nicht mehr zu
    /// erreichen (R8). Ohne Inhalt fuehrt heute oder ein kuenftiger Tag mit
    /// Marke (gebuchter Kurs) in den Plan-Tab; kuenftige Tage mit Marke immer.
    /// nil = kein Knopf. Die Ids sind "yyyy-MM-dd" und vergleichen sich als Text.
    static func tippZiel(_ tag: HomeSerieTag, heute: String, hatInhalt: Bool) -> HomeSerieTipp? {
        guard !tag.ausserhalb else { return nil }
        if tag.id > heute, tag.geplant != nil { return .planTag }
        if hatInhalt { return .ausklappen }
        return tag.id == heute && tag.geplant != nil ? .planTag : nil
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

    /// Ob die Flamme brennt -- die Farbe der Serie, nicht ihre Zahl.
    ///
    /// **Zwei verschiedene Aussagen, die auseinanderfallen duerfen.** Die
    /// Zahl beantwortet "wie viele Wochen in Folge" und bleibt in einer
    /// noch leeren Woche stehen: der Server zaehlt die laufende Woche erst
    /// mit, sobald ihre erste Einheit steht (`serienstand` in
    /// packages/domain/src/sessions.ts), damit die Serie nicht jeden
    /// Montagmorgen um eins faellt. Wer zwei Wochen hintereinander
    /// trainiert hat, liest am Mittwoch der dritten weiterhin "2".
    ///
    /// Die FARBE beantwortet etwas anderes: "steht diese Woche schon
    /// etwas?". Gruen in einer leeren Woche sagte dem Mitglied, alles sei
    /// erledigt, obwohl die Serie bis Sonntag an einer Einheit haengt.
    /// Gedeckt sagt: hier ist noch etwas zu tun, die Zahl daneben sagt,
    /// worum es geht (Testnotiz vom 19. September, Eintrag 3).
    ///
    /// `trainedDays` reicht dafuer genau: es sind die Tage der LAUFENDEN
    /// Woche mit mindestens einer Einheit, fertig vom Server und in der
    /// Zeitzone des Studios gerechnet -- keine zweite Wochengrenze im
    /// Client.
    static func serieLaeuft(_ stand: Serienstand) -> Bool {
        stand.weeks > 0 && !stand.trainedDays.isEmpty
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
    ///
    /// `ziel` haengt einen dritten Halbsatz an, nur wenn eins steht --
    /// dieselbe Regel wie bei der sichtbaren Zielzeile: die Serie zaehlt
    /// unveraendert Wochen, das Wochenziel ist eine zweite, unabhaengige
    /// Aussage (nicht-verhandelbare Regel 1), und VoiceOver muss beide
    /// hoeren koennen, ohne dass eine die andere ersetzt.
    static func vorlesetext(wochen: Int, tage: [HomeSerieTag], ziel: Int? = nil) -> String {
        let serie = wochen == 0
            ? "Keine laufende Serie."
            : "Serie: \(wochen) \(wochenLabel(wochen))."

        let trainingstage = tage.filter(\.trainiert).map(\.wochentagVoll)
        let woche = trainingstage.isEmpty
            ? "Diese Woche noch nicht trainiert."
            : "Diese Woche \(aufzaehlung(trainingstage)) trainiert."

        guard let ziel else { return "\(serie) \(woche)" }
        let zielEinheit = ziel == 1 ? "Tag" : "Tage"
        return "\(serie) \(woche) Ziel \(ziel) \(zielEinheit), \(trainingstage.count) erreicht."
    }

    /// "2 von 3 Tagen diese Woche" / "3 von 3 Tagen · Ziel erreicht" -- die
    /// Zeile unter dem Wochenstreifen, nur mit gesetztem Wochenziel.
    ///
    /// `trainiert >= ziel` gilt als erreicht, auch darueber ("4 von 3"):
    /// mehr als das Ziel ist erreicht, nicht falsch. Das ist eine zweite,
    /// unabhaengige Aussage neben der Serie (nicht-verhandelbare Regel 1)
    /// -- sie zaehlt hier nach, rechnet aber keine zweite Wochengrenze,
    /// sondern vergleicht nur die Anzahl, die der Streifen ohnehin zeigt.
    static func zielzeile(trainiert: Int, ziel: Int) -> String {
        let einheit = ziel == 1 ? "Tag" : "Tagen"
        guard trainiert < ziel else {
            return "\(trainiert) von \(ziel) \(einheit) · Ziel erreicht"
        }
        return "\(trainiert) von \(ziel) \(einheit) diese Woche"
    }

    /// "Ziel 3 Tage" / "Ziel 1 Tag" -- rechts ueber dem Kalender. Der View
    /// setzt die Zeile in Grossbuchstaben; die Einzahl entscheidet sich
    /// hier, damit "ZIEL 1 TAGE" nicht entstehen kann.
    static func zielkopf(ziel: Int) -> String {
        "Ziel \(ziel) \(ziel == 1 ? "Tag" : "Tage")"
    }

    // MARK: - Innereien

    /// "yyyy-MM-dd" in der Zeitzone des Studios. en_US_POSIX fuer ein rein
    /// numerisches, festes Muster -- dieselbe Begruendung wie bei KursZeit.uhrzeit.
    private static func ortsTagFormatter(_ zeitzone: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

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
