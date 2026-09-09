import Foundation

/// Parst startsAt -- eine Postgres-`timestamptz` (course_sessions.starts_at,
/// via course_week ungefiltert nach JSON durchgereicht), nicht ein
/// clientseitig erzeugtes Datum wie `performedAt` in Sub-Projekt 2.
/// `ISO8601DateFormatter()` parst standardmaessig KEINE Sekundenbruchteile;
/// Postgres liefert sie nur, wenn die Mikrosekunden ungleich null sind --
/// im Regelfall (Kurse beginnen auf die Minute) also nicht, aber
/// garantiert ist das nicht. Scheitert das Parsen still, wuerde
/// `zustand(fuer:jetzt:)` die Vorbei-Pruefung einfach uebergehen und ein
/// laengst gelaufener Kurs erschiene als buchbar -- deshalb EINE Stelle
/// statt drei einzeln angelegter Formatierer.
enum Zeitpunkt {
    static func parse(_ iso: String) -> Date? {
        let mitBruchteilen = ISO8601DateFormatter()
        mitBruchteilen.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let datum = mitBruchteilen.date(from: iso) { return datum }
        return ISO8601DateFormatter().date(from: iso)
    }
}
