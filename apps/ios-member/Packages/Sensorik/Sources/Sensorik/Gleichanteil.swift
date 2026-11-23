import Foundation

/// Schaetzt den Gleichanteil der Vertikalbeschleunigung (Schraeglage, falsch
/// geschaetzte Schwerkraft) aus der Wiederholung der Bewegung: Die rohe, nie
/// berichtigte Geschwindigkeit `u` ist die wahre plus Gleichanteil mal Zeit.
/// Gleichartige Extreme von `u` liegen eine Wiederholung auseinander, die wahre
/// Geschwindigkeit ist dort gleich, also ist (u₂ − u₁) / (t₂ − t₁) der Gleichanteil.
/// Das braucht keine erkannten Umkehrpunkte: Bei grossem Gleichanteil wechselt die
/// berichtigte Geschwindigkeit sonst nie das Vorzeichen. Der Median der letzten
/// drei Schaetzungen verwirft einzelne Ausreisser, etwa die Paare um einen Halt.
struct Gleichanteil: Sendable {
    private struct Punkt: Sendable { var u: Double; var schritt: Int }
    private enum Suche: Sendable {
        case offen(bezug: Double)
        case maximum(Punkt)
        case minimum(Punkt)
    }

    /// Ausschlag von `u` (m/s), ab dem ein Extrem bestaetigt ist.
    private static let hysterese = 0.05

    private var u = 0.0
    private var suche = Suche.offen(bezug: 0)
    private var letztesMaximum: Punkt?
    private var letztesMinimum: Punkt?
    private var schaetzungen: [Double] = []
    private(set) var wert = 0.0

    /// Gibt `true` zurueck, wenn eine neue Schaetzung eingegangen ist.
    mutating func verarbeite(_ beschleunigung: Double, schritt: Int, dt: Double) -> Bool {
        u += beschleunigung * dt
        let jetzt = Punkt(u: u, schritt: schritt)
        switch suche {
        case let .offen(bezug):
            if u > bezug + Self.hysterese { suche = .maximum(jetzt) }
            else if u < bezug - Self.hysterese { suche = .minimum(jetzt) }
            return false
        case let .maximum(p):
            if u > p.u { suche = .maximum(jetzt); return false }
            guard u < p.u - Self.hysterese else { return false }
            suche = .minimum(jetzt)
            defer { letztesMaximum = p }
            return schaetze(von: letztesMaximum, bis: p, dt: dt)
        case let .minimum(p):
            if u < p.u { suche = .minimum(jetzt); return false }
            guard u > p.u + Self.hysterese else { return false }
            suche = .maximum(jetzt)
            defer { letztesMinimum = p }
            return schaetze(von: letztesMinimum, bis: p, dt: dt)
        }
    }

    /// In Ruhe und nach Luecken: Extreme davor gehoeren zu keiner Wiederholung mehr.
    mutating func zuruecksetzen() {
        u = 0
        suche = .offen(bezug: 0)
        letztesMaximum = nil
        letztesMinimum = nil
        schaetzungen = []
    }

    private mutating func schaetze(von a: Punkt?, bis b: Punkt, dt: Double) -> Bool {
        guard let a, b.schritt > a.schritt else { return false }
        schaetzungen.append((b.u - a.u) / (Double(b.schritt - a.schritt) * dt))
        if schaetzungen.count > 3 { schaetzungen.removeFirst() }
        let sortiert = schaetzungen.sorted()
        wert = sortiert.count == 2 ? (sortiert[0] + sortiert[1]) / 2 : sortiert[sortiert.count / 2]
        return true
    }
}
