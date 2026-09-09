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

    /// "47 min · 3 Geräte · 8 Sätze" -- die Zeile unter dem Datum in
    /// "Letzte Trainings". Ohne Dauer bei einer selbsttaetig beendeten
    /// Einheit (siehe dauerText) faellt das erste Glied einfach weg,
    /// statt eine erfundene Dauer zu zeigen.
    static func zeilenText(_ einheit: SessionSummary) -> String {
        let geraete = zahlWortMitPlural(einheit.machineCount, singular: "Gerät", plural: "Geräte")
        let saetze = zahlWortMitPlural(einheit.setCount, singular: "Satz", plural: "Sätze")
        return [dauerText(einheit), geraete, saetze]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// "18:04 – 18:51 · 47 min · 3 Geräte · 8 Sätze" -- die Zeile unter dem Datum
    /// im Session-Detail. Bei einer selbsttaetig beendeten Einheit entfallen
    /// Zeitraum und Dauer: ihr Ende liegt beim letzten Satz, nicht beim Ende
    /// des Trainings.
    static func detailUntertitel(_ einheit: SessionSummary) -> String {
        var teile: [String] = []

        if einheit.completedReason != "auto",
           let start = Zeitpunkt.parse(einheit.startedAt),
           let endeIso = einheit.completedAt,
           let ende = Zeitpunkt.parse(endeIso) {
            teile.append("\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende))")
        }
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
