import Foundation

/// Benachbarte Einheiten eines Tages, die als ein Training gelesen werden.
///
/// Fuenf Eintraege an einem Freitag sind nicht fuenf Trainings: wer nach
/// einer kurzen Pause weitermacht, hat einmal trainiert. Das Zusammenfassen
/// ist reine ANZEIGE -- in den Daten bleiben die Einheiten getrennt, kein
/// Satz wird umgehaengt.
struct Trainingskarte: Identifiable {
    /// Aufsteigend, der aelteste Teil zuerst.
    let teile: [SessionSummary]

    /// Die Id des aeltesten Teils: das Detail wird weiter ueber eine
    /// Session-Id angesteuert und sucht sich die uebrigen Teile selbst
    /// (`HomeZeilen.karte(fuer:in:)`).
    var id: String { teile[0].id }
}

extension Trainingskarte {
    /// Ein Teil genuegt: die Marke sagt, dass an dieser Karte ein Ende
    /// gesetzt statt bestaetigt wurde. Das gilt fuer die ganze Karte,
    /// sobald es fuer einen ihrer Teile gilt -- ihre Dauer ist dann eine
    /// Untergrenze (siehe HomeZeilen.dauerText).
    var istAutoBeendet: Bool {
        teile.contains { $0.completedReason == "auto" }
    }
}

/// Die reinen Ableitungen des Home-Tabs -- getrennt vom View, damit sie
/// pruefbar bleiben.
enum HomeZeilen {
    /// Was heute noch laeuft, ist kein Verlauf. Die laufende Einheit hat
    /// kein `completedAt` und steht im Training-Tab.
    static func abgeschlossene(_ sessions: [SessionSummary]) -> [SessionSummary] {
        sessions.filter { $0.completedAt != nil }
    }

    /// `nil` bei einer selbsttaetig beendeten Einheit: getSessions setzt
    /// deren Ende auf den letzten Satz, damit eine vergessene Einheit
    /// nicht rueckwirkend Stunden dauert. Die daraus gerechnete Dauer ist
    /// eine Untergrenze, keine Dauer.
    static func dauerText(_ session: SessionSummary) -> String? {
        dauerMinuten(session).map { "\($0) min" }
    }

    /// Die gerundeten Minuten hinter `dauerText` -- die Karte summiert sie
    /// ueber ihre Teile und braucht sie deshalb als Zahl.
    private static func dauerMinuten(_ session: SessionSummary) -> Int? {
        guard let start = Zeitpunkt.parse(session.startedAt),
              let ende = gueltigesEnde(session)
        else { return nil }

        return Int((ende.timeIntervalSince(start) / 60).rounded())
    }

    /// Kalendertage, nicht 24-Stunden-Schritte: "gestern" ist gestern,
    /// auch wenn dazwischen nur zwei Stunden liegen.
    static func tageHer(_ lastSessionAt: String?, jetzt: Date, kalender: Calendar) -> Int? {
        guard let lastSessionAt, let zeitpunkt = Zeitpunkt.parse(lastSessionAt) else { return nil }

        return kalender.dateComponents(
            [.day],
            from: kalender.startOfDay(for: zeitpunkt),
            to: kalender.startOfDay(for: jetzt)
        ).day
    }

    /// "Tag her" fuer genau einen Tag, sonst "Tage her" -- auch fuer 0
    /// ("heute" ist noch nicht so weit her wie "1 Tag", aber "0 Tage her"
    /// ist trotzdem Mehrzahl).
    static func tageHerLabel(_ tage: Int) -> String {
        tage == 1 ? "Tag her" : "Tage her"
    }

    /// Dieselbe Rechnung wie `tageHer`, aber fuer ein reines Ortsdatum
    /// ("yyyy-MM-dd") statt eines Zeitstempels: `Zeitpunkt.parse` erwartet
    /// ein volles ISO8601-Datum mit Uhrzeit und scheitert an
    /// `Messwert.measuredOn`, das nur einen Tag traegt (Aufgabe 8).
    ///
    /// Der Messtag ist ein ORTSTAG des Mitglieds (R9) -- "heute" wird
    /// deshalb zuerst als Tagesstring IN `zeitzone` gebaut, nicht per
    /// `Calendar.startOfDay` auf den UTC-Mitternachts-Zeitpunkt von `tag`
    /// angewandt: `startOfDay` auf einen UTC-Mitternachts-Instant
    /// verschiebt den Tag je nach Geraetezeitzone um bis zu einen Tag
    /// (Ruling R26 -- ein Geraet hinter UTC laesst "heute" sonst um einen
    /// Tag zurueckfallen). Die eigentliche Differenz danach ist reine
    /// Kalendertag-Arithmetik zwischen zwei Tagesstrings in einem festen
    /// UTC-Kalender (wie `HomeSerie`s privater Kalender) -- keine
    /// Instant-Subtraktion, die noch einmal von einer Zeitzone abhaengen
    /// koennte.
    static func tageHerVonTag(_ tag: String?, jetzt: Date, zeitzone: TimeZone = .current) -> Int? {
        guard let tag,
              let tagDatum = ortsdatumFormatter.date(from: tag),
              let heuteDatum = ortsdatumFormatter.date(from: ortstag(jetzt, zeitzone: zeitzone))
        else { return nil }

        return utcTageskalender.dateComponents([.day], from: tagDatum, to: heuteDatum).day
    }

    /// "heute" / "gestern" / "vor 3 Tagen" -- dieselbe Ausdrucksform wie
    /// in `HomeSerie.fussnote` ("...zuletzt gestern"), hier aber
    /// eigenstaendig: die Gewichtskarte (Aufgabe 8) braucht das Datum
    /// allein, ohne einen Halbsatz drumherum.
    static func tageHerText(_ tage: Int) -> String {
        switch tage {
        case ...0: "heute"
        case 1: "gestern"
        default: "vor \(tage) Tagen"
        }
    }

    /// "yyyy-MM-dd" des Geraets zum Zeitpunkt `jetzt`, IN `zeitzone` --
    /// der Messtag ist ein Ortstag (R9), niemand traegt "UTC-Mittwoch"
    /// ein. `Calendar.dateComponents` statt eines zweiten, mutierten
    /// `DateFormatter`: ein `DateFormatter` ist eine Klasse, und seine
    /// `timeZone` bei jedem Aufruf umzuschreiben waere ein geteilter,
    /// veraenderlicher Zustand ueber gleichzeitige Aufrufe hinweg.
    private static func ortstag(_ jetzt: Date, zeitzone: TimeZone) -> String {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        let teile = kalender.dateComponents([.year, .month, .day], from: jetzt)
        guard let jahr = teile.year, let monat = teile.month, let tag = teile.day else { return "" }
        return String(format: "%04d-%02d-%02d", jahr, monat, tag)
    }

    /// en_US_POSIX/UTC fuer ein rein numerisches, festes Ortsdatum --
    /// dieselbe Begruendung wie bei `HomeSerie.datumsFormatter`.
    private static let ortsdatumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// UTC, fest -- fuer die Differenz zweier Tagesstrings, die beide ueber
    /// `ortsdatumFormatter` auf UTC-Mitternacht geparst wurden: eine reine
    /// Kalendertag-Subtraktion ohne Zeitzonen-Einfluss, dieselbe
    /// Festlegung wie `HomeSerie`s privater Kalender.
    private static let utcTageskalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!
        return kalender
    }()

    /// "08:32 – 09:06", sonst "ab 08:32" -- die Ueberschrift ueber den
    /// Bloecken eines Teils im Session-Detail. Sie steht nur da, wo eine
    /// Karte mehrere Teile traegt, und muss dann sagen, welcher Teil
    /// darunter liegt; die Uhrzeit ist das Einzige, was sie unterscheidet.
    ///
    /// Ohne lesbaren Beginn bleibt sie leer: eine Ueberschrift ohne Zeit
    /// sagt weniger als keine, und erfunden wird keine (designsystem.md SS10).
    static func teilUeberschrift(_ einheit: SessionSummary) -> String {
        zeitangabe(beginn: Zeitpunkt.parse(einheit.startedAt), ende: gueltigesEnde(einheit)) ?? ""
    }

    /// Das BESTAETIGTE Ende einer Einheit. `nil` bei einer selbsttaetig
    /// beendeten: getSessions setzt deren Ende auf den letzten Satz, das
    /// ist der letzte Satz und nicht das Ende des Trainings (siehe dauerText).
    private static func gueltigesEnde(_ einheit: SessionSummary) -> Date? {
        guard einheit.completedReason != "auto", let endeIso = einheit.completedAt else { return nil }
        return Zeitpunkt.parse(endeIso)
    }

    /// Die eine Stelle, an der aus zwei Zeitpunkten Text wird: "08:32 – 09:06"
    /// mit Ende, "ab 08:32" ohne. Ueberschrift, kleine Zeile der Einheit und
    /// kleine Zeile der Karte sagen dasselbe und sollen es gleich schreiben.
    private static func zeitangabe(beginn: Date?, ende: Date?) -> String? {
        guard let beginn else { return nil }
        guard let ende else { return "ab \(Zahlformat.uhrzeit(beginn))" }
        return "\(Zahlformat.uhrzeit(beginn)) – \(Zahlformat.uhrzeit(ende))"
    }

    /// "41 min · 3 Sätze" -- die grosse Zeile der getauschten Karte (Plan
    /// Punkt 17): Zeit und Saetze sagen, wie viel trainiert wurde, das
    /// gehoert nach oben. Ohne Dauer bei einer selbsttaetig beendeten
    /// Einheit (siehe dauerText) bleiben nur die Saetze.
    static func grosseZeile(_ einheit: SessionSummary) -> String {
        let saetze = zahlWortMitPlural(einheit.setCount, singular: "Satz", plural: "Sätze")
        return [dauerText(einheit), saetze]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// "15:36 – 16:16 · 1 Gerät" -- die kleine Zeile der getauschten Karte:
    /// Uhrzeit und Geraetezahl sagen, was fuer ein Training es war, nicht
    /// wie viel, darum keine Akzentflaeche und keine grosse Schrift dafuer.
    /// "ab 15:36 · 1 Gerät" bei einer selbsttaetig beendeten Einheit --
    /// ein erfundenes Ende waere schlimmer als ein offener Zeitraum.
    static func kleineZeile(_ einheit: SessionSummary) -> String {
        let geraete = zahlWortMitPlural(einheit.machineCount, singular: "Gerät", plural: "Geräte")
        let zeit = zeitangabe(beginn: Zeitpunkt.parse(einheit.startedAt), ende: gueltigesEnde(einheit))
        return [zeit, geraete].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Benachbarte Einheiten werden eine Karte

    /// Fasst benachbarte Einheiten zu Trainingskarten zusammen: liegen
    /// zwischen dem Ende der einen und dem Beginn der naechsten weniger
    /// als `luecke`, gehoeren sie auf eine Karte.
    ///
    /// Die Grenze gehoert nach oben, nicht nach unten: genau 60 Minuten
    /// Pause sind zwei Trainings, 59 sind eines.
    ///
    /// Reihenfolge wie die Tagesliste sie braucht -- die juengste Karte
    /// zuerst, innerhalb einer Karte der aelteste Teil zuerst. Kein
    /// `Date()`: die Karte haengt nur an den Zeitstempeln, sonst saehe
    /// dieselbe Liste morgen anders aus.
    static func trainingskarten(
        _ einheiten: [SessionSummary], luecke: TimeInterval = 3600
    ) -> [Trainingskarte] {
        var gefaltet: [[SessionSummary]] = []

        for einheit in aufsteigend(einheiten) {
            if let vorherige = gefaltet.last?.last, schliesstAn(vorherige, einheit, luecke: luecke) {
                gefaltet[gefaltet.count - 1].append(einheit)
            } else {
                gefaltet.append([einheit])
            }
        }

        return gefaltet.reversed().map(Trainingskarte.init)
    }

    /// Die Karte, auf der diese Einheit liegt -- fuer das Detail, das nur
    /// eine Session-Id bekommt. Faltet dieselbe Liste nach derselben
    /// Regel, damit Liste und Detail gleich gruppieren. Die eine Ausnahme
    /// ist gewollt: die Liste faltet je Ortstag, das Detail den ganzen
    /// Verlauf -- eine Karte ueber Mitternacht zeigt im Detail beide
    /// Tage, in der Liste je Tag ihren Teil.
    static func karte(fuer sessionId: String, in einheiten: [SessionSummary]) -> Trainingskarte? {
        trainingskarten(einheiten).first { karte in
            karte.teile.contains { $0.id == sessionId }
        }
    }

    /// "64 min · 8 Sätze" -- die grosse Zeile einer Karte: die SUMMIERTE
    /// Trainingszeit ihrer Teile, nicht die Spanne. 08:32-09:06 und
    /// 09:20-09:50 sind 64 Minuten Training, nicht 78 -- die Pause
    /// dazwischen ist keine (designsystem.md SS10: die App misst nichts,
    /// was nicht aus bestaetigten Saetzen kommt).
    ///
    /// Summiert wird ueber die je Teil gerundeten Minuten, damit eine
    /// Karte aus einem Teil genau dieselbe Zahl zeigt wie `dauerText`.
    /// Selbsttaetig beendete Teile zaehlen fuer die Saetze, aber nicht fuer
    /// die Dauer (siehe dauerText); traegt die Karte nur solche Teile,
    /// bleiben wie bei der einzelnen Einheit nur die Saetze.
    static func grosseZeile(_ karte: Trainingskarte) -> String {
        let minuten = karte.teile.compactMap(dauerMinuten)
        let dauer = minuten.isEmpty ? nil : "\(minuten.reduce(0, +)) min"
        let saetze = zahlWortMitPlural(
            karte.teile.reduce(0) { $0 + $1.setCount }, singular: "Satz", plural: "Sätze")

        return [dauer, saetze].compactMap { $0 }.joined(separator: " · ")
    }

    /// "08:32 – 09:50 · 3 Geräte" -- die kleine Zeile einer Karte: die
    /// Spanne vom Beginn des ersten bis zum Ende des letzten Teils.
    ///
    /// Die Geraetezahl kommt aus den VERSCHIEDENEN `machineId` aller Teile,
    /// nicht aus der Summe der `machineCount`: wer nach der Pause an
    /// dasselbe Geraet zurueckkehrt, hat kein zweites benutzt.
    ///
    /// Endet der letzte Teil selbsttaetig, bleibt die Spanne offen
    /// ("ab 08:32") -- ein erfundenes Ende waere schlimmer (wie bei der
    /// einzelnen Einheit).
    static func kleineZeile(_ karte: Trainingskarte) -> String {
        let geraete = zahlWortMitPlural(
            verschiedeneGeraete(karte), singular: "Gerät", plural: "Geräte")
        let spanne = zeitangabe(
            beginn: Zeitpunkt.parse(karte.teile[0].startedAt),
            ende: karte.teile.last.flatMap(gueltigesEnde))

        return [spanne, geraete].compactMap { $0 }.joined(separator: " · ")
    }

    private static func verschiedeneGeraete(_ karte: Trainingskarte) -> Int {
        Set(karte.teile.flatMap { $0.blocks.map(\.machineId) }).count
    }

    /// Nach Beginn sortiert, nicht nach der Reihenfolge der Liste: die
    /// Tagesliste kommt absteigend, gefaltet wird vorwaerts. Einheiten ohne
    /// lesbaren Beginn ans Ende -- sie stehen ohnehin allein.
    private static func aufsteigend(_ einheiten: [SessionSummary]) -> [SessionSummary] {
        einheiten.sorted { links, rechts in
            switch (Zeitpunkt.parse(links.startedAt), Zeitpunkt.parse(rechts.startedAt)) {
            case let (linksBeginn?, rechtsBeginn?): return linksBeginn < rechtsBeginn
            case (_?, nil): return true
            default: return false
            }
        }
    }

    /// Ohne lesbare Zeitstempel gibt es keine Luecke, und ohne Luecke keine
    /// Nachbarschaft: eine Einheit ohne lesbares `completedAt` oder
    /// `startedAt` steht allein, statt zwei fremde Trainings zu verkleben.
    private static func schliesstAn(
        _ vorherige: SessionSummary, _ naechste: SessionSummary, luecke: TimeInterval
    ) -> Bool {
        guard let ende = vollstaendig(vorherige)?.ende,
              let beginn = vollstaendig(naechste)?.beginn
        else { return false }

        return beginn.timeIntervalSince(ende) < luecke
    }

    private static func vollstaendig(_ einheit: SessionSummary) -> (beginn: Date, ende: Date)? {
        guard let beginn = Zeitpunkt.parse(einheit.startedAt),
              let endeIso = einheit.completedAt,
              let ende = Zeitpunkt.parse(endeIso)
        else { return nil }

        return (beginn, ende)
    }

    /// Helper fuer Singular/Plural bei Zaehler > 1.
    private static func zahlWortMitPlural(_ zahl: Int, singular: String, plural: String) -> String {
        "\(zahl) \(zahl == 1 ? singular : plural)"
    }

    /// "+15,0" / "±0" -- eine Rechnung, keine Empfehlung (designsystem.md SS10).
    static func veraenderung(_ kg: Double) -> String {
        guard kg != 0 else { return "±0" }
        return (kg > 0 ? "+" : "-") + Zahlformat.gewicht(abs(kg))
    }

    /// Der erste Namensteil -- "Hallo Lena", nicht "Hallo Lena Wagner".
    static func vorname(_ displayName: String?) -> String? {
        geputzt(displayName)?.split(separator: " ").first.map(String.init)
    }

    /// Hoechstens zwei Buchstaben. `nil` ohne gesetzten Namen: aus einer
    /// Mailadresse abgeleitet saehen Initialen so lange richtig aus, bis
    /// sie jemanden treffen, dessen Adresse nicht sein Name ist.
    static func initialen(_ displayName: String?) -> String? {
        guard let name = geputzt(displayName) else { return nil }

        let buchstaben = name.split(separator: " ").prefix(2).compactMap(\.first)
        return buchstaben.isEmpty ? nil : String(buchstaben).uppercased()
    }

    private static func geputzt(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return nil }
        return name
    }
}
