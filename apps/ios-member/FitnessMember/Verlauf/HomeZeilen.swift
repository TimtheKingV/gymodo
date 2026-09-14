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
        guard session.completedReason != "auto",
              let endeIso = session.completedAt,
              let start = Zeitpunkt.parse(session.startedAt),
              let ende = Zeitpunkt.parse(endeIso)
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

    /// "47 min · 3 Geräte · 8 Sätze" -- die Zeile unter der Uhrzeit auf
    /// einer Tageskarte. Ohne Dauer bei einer selbsttaetig beendeten
    /// Einheit (siehe dauerText) faellt das erste Glied einfach weg,
    /// statt eine erfundene Dauer zu zeigen.
    static func zeilenText(_ einheit: SessionSummary) -> String {
        let geraete = zahlWortMitPlural(einheit.machineCount, singular: "Gerät", plural: "Geräte")
        let saetze = zahlWortMitPlural(einheit.setCount, singular: "Satz", plural: "Sätze")
        return [dauerText(einheit), geraete, saetze]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// "18:04 – 18:51" -- der Zeitraum einer Einheit. `nil` bei einer
    /// selbsttaetig beendeten: ihr Ende liegt beim letzten Satz, nicht beim
    /// Ende des Trainings (siehe dauerText).
    static func zeitraum(_ einheit: SessionSummary) -> String? {
        guard einheit.completedReason != "auto",
              let start = Zeitpunkt.parse(einheit.startedAt),
              let endeIso = einheit.completedAt,
              let ende = Zeitpunkt.parse(endeIso)
        else { return nil }

        return "\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende))"
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
    /// ein erfundenes Ende waere schlimmer als ein offener Zeitraum
    /// (wie bei kartenTitel).
    static func kleineZeile(_ einheit: SessionSummary) -> String {
        let geraete = zahlWortMitPlural(einheit.machineCount, singular: "Gerät", plural: "Geräte")
        if let zeitraum = zeitraum(einheit) { return "\(zeitraum) · \(geraete)" }
        guard let start = Zeitpunkt.parse(einheit.startedAt) else { return geraete }
        return "ab \(Zahlformat.uhrzeit(start)) · \(geraete)"
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
    /// Regel, damit Liste und Detail nicht verschieden gruppieren.
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

        guard let start = Zeitpunkt.parse(karte.teile[0].startedAt) else { return geraete }

        let letzter = karte.teile[karte.teile.count - 1]
        if letzter.completedReason != "auto",
           let endeIso = letzter.completedAt,
           let ende = Zeitpunkt.parse(endeIso) {
            return "\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende)) · \(geraete)"
        }
        return "ab \(Zahlformat.uhrzeit(start)) · \(geraete)"
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

    /// Die Titelzeile einer Karte im Tages-Ausklapper des Home-Kalenders.
    ///
    /// Dort steht die Uhrzeit, wo in "Letzte Trainings" das Datum stand:
    /// welcher Tag es ist, sagt der Kalender darueber, und zwei Einheiten
    /// desselben Tages unterscheiden sich nur in der Uhrzeit.
    ///
    /// "ab 18:04" bei einer selbsttaetig beendeten Einheit -- ein
    /// erfundenes Ende waere schlimmer als ein offener Zeitraum.
    static func kartenTitel(_ einheit: SessionSummary) -> String {
        if let zeitraum = zeitraum(einheit) { return zeitraum }
        guard let start = Zeitpunkt.parse(einheit.startedAt) else { return "" }
        return "ab \(Zahlformat.uhrzeit(start))"
    }

    /// "18:04 – 18:51 · 47 min · 3 Geräte · 8 Sätze" -- die Zeile unter dem Datum
    /// im Session-Detail. Bei einer selbsttaetig beendeten Einheit entfallen
    /// Zeitraum und Dauer: ihr Ende liegt beim letzten Satz, nicht beim Ende
    /// des Trainings.
    static func detailUntertitel(_ einheit: SessionSummary) -> String {
        var teile: [String] = []

        if let zeitraum = zeitraum(einheit) { teile.append(zeitraum) }
        if let dauer = dauerText(einheit) { teile.append(dauer) }
        teile.append(zahlWortMitPlural(einheit.machineCount, singular: "Gerät", plural: "Geräte"))
        teile.append(zahlWortMitPlural(einheit.setCount, singular: "Satz", plural: "Sätze"))

        return teile.joined(separator: " · ")
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
