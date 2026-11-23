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
    /// Am Geraet rauscht die Beschleunigung um bis zu ±1 m/s² (Stapel); mit der
    /// festen Hysterese waere jedes Zittern ein Extrem und paarte sich mit einem
    /// beliebigen anderen, die Schaetzungen sprangen um ±1 m/s². Ein Extrem zaehlt
    /// deshalb erst ab diesem Anteil des letzten Ausschlags: Rauschen und kleine
    /// Wellen zwischen den Umkehrpunkten sind keine Stelle der Wiederholung.
    private static let hystereseAnteil = 0.3
    /// Gleichartige Extreme liegen eine Wiederholung auseinander, mindestens so lang (s).
    private static let kleinsterAbstand = 0.8
    private static let hoehenToleranz = 0.2
    /// So nah (m/s²) muessen die beiden juengsten Schaetzungen beieinander liegen,
    /// damit der Gleichanteil als bekannt gilt. Eine Bewegung, die wie Ruhe begann,
    /// laesst die Schwerkraftschaetzung anfangs mitlaufen; das erste Paar stimmt dann nicht.
    private static let einigkeit = 0.02

    /// Rohe, nie berichtigte Geschwindigkeit (m/s).
    private(set) var u = 0.0
    /// Abstand des letzten bestaetigten Maximums zum letzten Minimum (m/s²).
    private var ausschlag = 0.0
    private var aktuelleHysterese: Double { max(Self.hysterese, Self.hystereseAnteil * ausschlag) }
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
        let hysterese = aktuelleHysterese
        switch suche {
        case let .offen(bezug):
            guard let bezug else { suche = .offen(bezug: beschleunigung); return nil }
            if beschleunigung > bezug + hysterese { suche = .maximum(jetzt) }
            else if beschleunigung < bezug - hysterese { suche = .minimum(jetzt) }
            return nil
        case let .maximum(p):
            if beschleunigung > p.beschleunigung { suche = .maximum(jetzt); return nil }
            guard beschleunigung < p.beschleunigung - hysterese else { return nil }
            suche = .minimum(jetzt)
            if let m = letztesMinimum { ausschlag = p.beschleunigung - m.beschleunigung }
            defer { if merken() { letztesMaximum = p } }
            return schaetze(von: letztesMaximum, bis: p, gegenueber: letztesMinimum, dt: dt)
        case let .minimum(p):
            if beschleunigung < p.beschleunigung { suche = .minimum(jetzt); return nil }
            guard beschleunigung > p.beschleunigung + hysterese else { return nil }
            suche = .maximum(jetzt)
            if let m = letztesMaximum { ausschlag = m.beschleunigung - p.beschleunigung }
            defer { if merken() { letztesMinimum = p } }
            return schaetze(von: letztesMinimum, bis: p, gegenueber: letztesMaximum, dt: dt)
        }
    }

    /// In Ruhe und nach Luecken: Extreme davor gehoeren zu keiner Wiederholung mehr.
    mutating func zuruecksetzen() {
        u = 0
        ausschlag = 0
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
        guard let a, let gegenueber, Double(b.schritt - a.schritt) * dt >= Self.kleinsterAbstand else { return nil }
        let ausschlag = abs(b.beschleunigung - gegenueber.beschleunigung)
        guard abs(b.beschleunigung - a.beschleunigung) <= Self.hoehenToleranz * ausschlag else { return nil }
        schaetzungen.append((b.u - a.u) / (Double(b.schritt - a.schritt) * dt))
        if schaetzungen.count > 3 { schaetzungen.removeFirst() }
        let sortiert = schaetzungen.sorted()
        wert = sortiert.count == 2 ? (sortiert[0] + sortiert[1]) / 2 : sortiert[sortiert.count / 2]
        return Stillpunkt(beschleunigung: b.beschleunigung, u: b.u, schritt: b.schritt)
    }
}
