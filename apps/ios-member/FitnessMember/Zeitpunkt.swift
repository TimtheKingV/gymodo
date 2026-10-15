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
    // Einmal angelegt statt je Aufruf: die Geraeteliste parst bei jedem
    // Tastendruck alle letzten Saetze, und zwei neue Formatter je Satz
    // haben die Suche spuerbar ausgebremst (Offline-Spec 1b).
    // ISO8601DateFormatter ist laut Apple-Doku threadsicher.
    nonisolated(unsafe) private static let mitBruchteilen: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let ohneBruchteile = ISO8601DateFormatter()

    static func parse(_ iso: String) -> Date? {
        mitBruchteilen.date(from: iso) ?? ohneBruchteile.date(from: iso)
    }
}
