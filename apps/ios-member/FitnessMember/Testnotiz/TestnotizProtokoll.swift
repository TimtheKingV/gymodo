#if DEBUG
import OSLog

enum TestnotizProtokoll {
    static let subsystem = "de.gymtaro.member"

    /// Nur Kategorien, deren Zeilen nachweislich keine Personendaten tragen.
    /// Im eigenen Prozess schwaerzt OSLogStore privacy: .private NICHT (Spike
    /// 2026-09-14) -- eine neue Kategorie kommt erst nach einem Blick auf
    /// ihre Zeilen hierher.
    static let kategorien: Set<String> = ["tag"]

    static func stufe(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        case .undefined: "undefined"
        @unknown default: "undefined"
        }
    }

    /// Ein Lesefehler kostet das Protokoll, nie den Eintrag.
    static func lesen(seit sekunden: TimeInterval, bis jetzt: Date, kategorien: Set<String> = kategorien) -> [TestnotizEintrag.Protokollzeile] {
        do {
            let speicher = try OSLogStore(scope: .currentProcessIdentifier)
            let ab = speicher.position(date: jetzt.addingTimeInterval(-sekunden))
            let praedikat = NSPredicate(format: "subsystem == %@ AND category IN %@", subsystem, Array(kategorien))
            return try speicher.getEntries(at: ab, matching: praedikat)
                .compactMap { $0 as? OSLogEntryLog }
                .map { TestnotizEintrag.Protokollzeile(at: $0.date, level: stufe($0.level), category: $0.category, message: $0.composedMessage) }
        } catch {
            return []
        }
    }

    /// OSLogStore braucht bei vollem Speicher Sekunden; nicht auf dem Main Thread.
    static func lesenImHintergrund(seit sekunden: TimeInterval, bis jetzt: Date) async -> [TestnotizEintrag.Protokollzeile] {
        await Task.detached(priority: .userInitiated) {
            lesen(seit: sekunden, bis: jetzt)
        }.value
    }
}
#endif
