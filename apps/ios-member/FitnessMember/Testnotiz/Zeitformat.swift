#if DEBUG
import Foundation

/// Uhrzeiten fuer Ordnernamen und Markdown, ohne Locale: dieselbe Eingabe
/// ergibt auf jedem Geraet denselben Text, und die Tests brauchen keine
/// Formatter-Einstellungen.
enum Zeitformat {
    static func teile(_ datum: Date, zeitzone: TimeZone) -> DateComponents {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        return kalender.dateComponents([.year, .month, .day, .hour, .minute, .second], from: datum)
    }

    /// yyyy-MM-dd-HHmm
    static func ordnername(_ datum: Date, zeitzone: TimeZone) -> String {
        let t = teile(datum, zeitzone: zeitzone)
        return String(format: "%04d-%02d-%02d-%02d%02d", t.year!, t.month!, t.day!, t.hour!, t.minute!)
    }

    /// yyyy-MM-dd HH:mm
    static func datumUhrzeit(_ datum: Date, zeitzone: TimeZone) -> String {
        let t = teile(datum, zeitzone: zeitzone)
        return String(format: "%04d-%02d-%02d %02d:%02d", t.year!, t.month!, t.day!, t.hour!, t.minute!)
    }

    /// HH:mm oder HH:mm:ss
    static func uhrzeit(_ datum: Date, zeitzone: TimeZone, sekunden: Bool = false) -> String {
        let t = teile(datum, zeitzone: zeitzone)
        return sekunden
            ? String(format: "%02d:%02d:%02d", t.hour!, t.minute!, t.second!)
            : String(format: "%02d:%02d", t.hour!, t.minute!)
    }
}
#endif
