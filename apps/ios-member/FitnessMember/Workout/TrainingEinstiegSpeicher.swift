import Foundation

/// Haelt den Einstieg (E8) der laufenden Session fest, damit ein Neustart
/// mitten im freien Training nicht wieder an den Plan bindet (Review Focus 5).
/// Ein Eintrag gilt nur fuer die Session, unter deren ID er steht; er wird
/// am Ende nicht geloescht, damit "Fortsetzen" ihn wiederfindet.
struct TrainingEinstiegSpeicher {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static let schluesselSession = "training.einstieg.sessionId"
    private static let schluesselEinstieg = "training.einstieg.wert"

    func speichern(_ einstieg: TrainingEinstieg, sessionId: UUID) {
        defaults.set(sessionId.uuidString, forKey: Self.schluesselSession)
        defaults.set(einstieg.rawValue, forKey: Self.schluesselEinstieg)
    }

    func laden(sessionId: UUID) -> TrainingEinstieg? {
        guard defaults.string(forKey: Self.schluesselSession) == sessionId.uuidString,
              let roh = defaults.string(forKey: Self.schluesselEinstieg) else { return nil }
        return TrainingEinstieg(rawValue: roh)
    }
}
