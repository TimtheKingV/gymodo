import Foundation

/// Zahlen so, wie designsystem.md SS3 sie festlegt.
///
/// Gewichte tragen **immer** eine Nachkommastelle: ein Wechsel von 80 auf
/// 82,5 wirkte sonst wie ein Formatfehler statt wie eine Steigerung.
///
/// Das Gebietsschema ist fest auf Deutsch gesetzt, nicht `.current` -- das
/// Dezimalkomma ist hier eine Designentscheidung, kein Systemdetail.
enum Zahlformat {
    private static let gebietsschema = Locale(identifier: "de_DE")

    private static let gewichtFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = gebietsschema
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    /// `en_US_POSIX`, nicht `gebietsschema` (de_DE): bei einem fest
    /// vorgegebenen `dateFormat` ist das die kanonische Wahl -- ein
    /// regionsgebundenes Gebietsschema kann ein "HH"-Muster unter der
    /// Nutzereinstellung "24-Stunden-Zeit aus" umbiegen, `en_US_POSIX` nie.
    private static let uhrzeitFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func gewicht(_ kg: Double) -> String {
        gewichtFormatter.string(from: NSNumber(value: kg)) ?? "0,0"
    }

    /// "18:04" -- die Studio-Zeitzone spielt hier keine Rolle, weil die
    /// Einheit auf diesem Geraet lief.
    static func uhrzeit(_ zeitpunkt: Date) -> String {
        uhrzeitFormatter.string(from: zeitpunkt)
    }

    static func gewichtMitEinheit(_ kg: Double) -> String {
        "\(gewicht(kg)) kg"
    }

    /// Eine einzige Zeichenkette -- sonst liest VoiceOver "achtzig, Komma,
    /// null, k, g" als vier Elemente (designsystem.md SS12).
    static func gewichtGesprochen(_ kg: Double) -> String {
        "\(gewicht(kg)) Kilogramm"
    }

    static func wiederholungenGesprochen(_ reps: Int) -> String {
        reps == 1 ? "1 Wiederholung" : "\(reps) Wiederholungen"
    }

    /// "23:41", ab einer Stunde "1:20:14" -- sonst kippt die Lesart: "80:14"
    /// liest sich nicht mehr eindeutig als Minuten:Sekunden, und eine
    /// Trainingseinheit darf bis zu vier Stunden laufen
    /// (WorkoutSessionStore.sessionPause).
    static func verstrichen(seit start: Date, bis jetzt: Date) -> String {
        let sekunden = max(0, Int(jetzt.timeIntervalSince(start)))
        let stunden = sekunden / 3600
        let minuten = (sekunden % 3600) / 60
        let rest = sekunden % 60
        guard stunden > 0 else { return String(format: "%02d:%02d", minuten, rest) }
        return String(format: "%d:%02d:%02d", stunden, minuten, rest)
    }

    /// "23 Minuten trainiert" / "1 Stunde 20 Minuten trainiert" -- die
    /// gesprochene Gegenstelle zu verstrichen(seit:bis:): sonst liest
    /// VoiceOver "23:41" mit hoher Wahrscheinlichkeit als Uhrzeit
    /// (designsystem.md SS12, wie gewichtGesprochen).
    static func verstrichenGesprochen(seit start: Date, bis jetzt: Date) -> String {
        let minuten = max(0, Int(jetzt.timeIntervalSince(start) / 60))
        let stunden = minuten / 60
        let restminuten = minuten % 60
        guard stunden > 0 else {
            return minuten == 1 ? "1 Minute trainiert" : "\(minuten) Minuten trainiert"
        }
        let stundenteil = stunden == 1 ? "1 Stunde" : "\(stunden) Stunden"
        let minutenteil = restminuten == 1 ? "1 Minute" : "\(restminuten) Minuten"
        return "\(stundenteil) \(minutenteil) trainiert"
    }
}
