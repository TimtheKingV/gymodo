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
