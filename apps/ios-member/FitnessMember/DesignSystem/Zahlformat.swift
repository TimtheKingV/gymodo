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

    private static let uhrzeitFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = gebietsschema
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
}
