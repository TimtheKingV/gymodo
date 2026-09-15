import Foundation

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
        guard session.completedReason != "auto",
              let endeIso = session.completedAt,
              let start = Zeitpunkt.parse(session.startedAt),
              let ende = Zeitpunkt.parse(endeIso)
        else { return nil }

        let minuten = Int((ende.timeIntervalSince(start) / 60).rounded())
        return "\(minuten) min"
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
    static func tageHerVonTag(_ tag: String?, jetzt: Date, kalender: Calendar) -> Int? {
        guard let tag, let zeitpunkt = ortsdatumFormatter.date(from: tag) else { return nil }

        return kalender.dateComponents(
            [.day],
            from: kalender.startOfDay(for: zeitpunkt),
            to: kalender.startOfDay(for: jetzt)
        ).day
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

    /// en_US_POSIX/UTC fuer ein rein numerisches, festes Ortsdatum --
    /// dieselbe Begruendung wie bei `HomeSerie.datumsFormatter`.
    private static let ortsdatumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
