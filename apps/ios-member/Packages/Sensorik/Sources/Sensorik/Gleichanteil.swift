import Foundation

/// Schaetzt den Gleichanteil der Vertikalbeschleunigung (Schraeglage, falsch
/// geschaetzte Schwerkraft) aus der Wiederholung der Bewegung.
///
/// Die rohe, nie berichtigte Geschwindigkeit `u` ist die wahre plus Gleichanteil
/// mal Zeit. Die Extreme der Beschleunigung liegen an Umkehrpunkten und an den
/// Raendern eines Halts, wo die wahre Geschwindigkeit null ist; ihr Zeitpunkt
/// haengt nicht vom Gleichanteil ab. Zwischen zwei gleichartigen Extremen ist
/// (u₂ − u₁) / (t₂ − t₁) daher der Gleichanteil; gleichartige Extreme liegen eine
/// Wiederholung auseinander, ein Versatz des Abtastzeitpunkts hebt sich auf.
/// Das braucht weder erkannte Umkehrpunkte noch Extreme von `u`: Ist der
/// Gleichanteil groesser als die Spitzenbeschleunigung (langsames Tempo), steigt
/// oder faellt `u` stetig, die Beschleunigung schwankt trotzdem.
/// Gleichartig heisst: gleiche Art und aehnliche Hoehe (`hoehenToleranz` des
/// Ausschlags dazwischen), also dieselbe Stelle zweier Wiederholungen; die Extreme
/// an einem Halt mitten im Weg sind hoeher als die am Umkehrpunkt und paaren sich
/// nicht mit ihnen. Das erste Extrem nach Ruhe paart sich nicht: Am Start aus der
/// Ruhe geht kein Ablassen voraus, es ist nicht dieselbe Stelle wie die spaeteren
/// unteren Umkehrpunkte. Der Median der letzten drei Schaetzungen verwirft einzelne Ausreisser.
struct Gleichanteil: Sendable {
    /// Ein Extrem mit gepaarter Schaetzung: Dort stand die Last (fast) still.
    struct Stillpunkt: Sendable { var beschleunigung: Double; var u: Double; var schritt: Int }
    private struct Punkt: Sendable { var beschleunigung: Double; var u: Double; var schritt: Int }
    private enum Suche: Sendable {
        case offen(bezug: Double?)
        case maximum(Punkt)
        case minimum(Punkt)
    }

    /// Ausschlag der Beschleunigung (m/s²), ab dem ein Extrem bestaetigt ist.
    /// Gut unter den ±0,12 m/s² bei 4 s je Weg.
    private static let hysterese = 0.05
    private static let hoehenToleranz = 0.2
    /// So nah (m/s²) muessen die beiden juengsten Schaetzungen beieinander liegen,
    /// damit der Gleichanteil als bekannt gilt. Eine Bewegung, die wie Ruhe begann,
    /// laesst die Schwerkraftschaetzung anfangs mitlaufen; das erste Paar stimmt dann nicht.
    private static let einigkeit = 0.02

    /// Rohe, nie berichtigte Geschwindigkeit (m/s).
    private(set) var u = 0.0
    private var suche = Suche.offen(bezug: nil)
    private var letztesMaximum: Punkt?
    private var letztesMinimum: Punkt?
    /// Ob das erste Extrem nach Ruhe schon verworfen ist.
    private var erstesVerworfen = false
    private var schaetzungen: [Double] = []
    private(set) var wert = 0.0
    /// Ob die beiden juengsten Schaetzungen uebereinstimmen.
    var bestaetigt: Bool {
        schaetzungen.count >= 2 && abs(schaetzungen[schaetzungen.count - 1] - schaetzungen[schaetzungen.count - 2]) <= Self.einigkeit
    }

    /// Gibt das Extrem zurueck, wenn an ihm eine neue Schaetzung eingegangen ist.
    mutating func verarbeite(_ beschleunigung: Double, schritt: Int, dt: Double) -> Stillpunkt? {
        u += beschleunigung * dt
        let jetzt = Punkt(beschleunigung: beschleunigung, u: u, schritt: schritt)
        switch suche {
        case let .offen(bezug):
            guard let bezug else { suche = .offen(bezug: beschleunigung); return nil }
            if beschleunigung > bezug + Self.hysterese { suche = .maximum(jetzt) }
            else if beschleunigung < bezug - Self.hysterese { suche = .minimum(jetzt) }
            return nil
        case let .maximum(p):
            if beschleunigung > p.beschleunigung { suche = .maximum(jetzt); return nil }
            guard beschleunigung < p.beschleunigung - Self.hysterese else { return nil }
            suche = .minimum(jetzt)
            defer { if merken() { letztesMaximum = p } }
            return schaetze(von: letztesMaximum, bis: p, gegenueber: letztesMinimum, dt: dt)
        case let .minimum(p):
            if beschleunigung < p.beschleunigung { suche = .minimum(jetzt); return nil }
            guard beschleunigung > p.beschleunigung + Self.hysterese else { return nil }
            suche = .maximum(jetzt)
            defer { if merken() { letztesMinimum = p } }
            return schaetze(von: letztesMinimum, bis: p, gegenueber: letztesMaximum, dt: dt)
        }
    }

    /// In Ruhe und nach Luecken: Extreme davor gehoeren zu keiner Wiederholung mehr.
    mutating func zuruecksetzen() {
        u = 0
        suche = .offen(bezug: nil)
        letztesMaximum = nil
        letztesMinimum = nil
        erstesVerworfen = false
        schaetzungen = []
    }

    /// `gegenueber` ist das Extreme der anderen Art zwischen `a` und `b`.
    /// Ob ein bestaetigtes Extrem fuer spaetere Paare gemerkt wird (nicht das erste nach Ruhe).
    private mutating func merken() -> Bool {
        defer { erstesVerworfen = true }
        return erstesVerworfen
    }

    private mutating func schaetze(von a: Punkt?, bis b: Punkt, gegenueber: Punkt?, dt: Double) -> Stillpunkt? {
        guard let a, let gegenueber, b.schritt > a.schritt else { return nil }
        let ausschlag = abs(b.beschleunigung - gegenueber.beschleunigung)
        guard abs(b.beschleunigung - a.beschleunigung) <= Self.hoehenToleranz * ausschlag else { return nil }
        schaetzungen.append((b.u - a.u) / (Double(b.schritt - a.schritt) * dt))
        if schaetzungen.count > 3 { schaetzungen.removeFirst() }
        let sortiert = schaetzungen.sorted()
        wert = sortiert.count == 2 ? (sortiert[0] + sortiert[1]) / 2 : sortiert[sortiert.count / 2]
        return Stillpunkt(beschleunigung: b.beschleunigung, u: b.u, schritt: b.schritt)
    }
}
