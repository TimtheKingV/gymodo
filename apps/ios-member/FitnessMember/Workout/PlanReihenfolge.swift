import CoreGraphics

/// Das Umsortieren der Planzeilen im Training: welche Verschiebungen eine
/// Zeile anbietet (VoiceOver-Aktionen) und wohin ein Ziehen sie setzt.
/// Rein, damit weder Geste noch View fuer die Regeln noetig sind.
enum PlanReihenfolge {
    enum Richtung: Equatable {
        case hoch, runter

        var name: String {
            switch self {
            case .hoch: "Nach oben verschieben"
            case .runter: "Nach unten verschieben"
            }
        }

        func ziel(von index: Int) -> Int {
            self == .hoch ? index - 1 : index + 1
        }
    }

    /// Die moeglichen Schritte einer Zeile; die unmoegliche faellt weg.
    static func aktionen(index: Int, anzahl: Int) -> [Richtung] {
        var ergebnis: [Richtung] = []
        if index > 0 { ergebnis.append(.hoch) }
        if index < anzahl - 1 { ergebnis.append(.runter) }
        return ergebnis
    }

    /// Die Trennlinie zwischen zwei Zeilen (1 pt) gehoert zum Platz der Zeile.
    static let trennlinie: CGFloat = 1

    /// Die Plaetze der Zeilen samt Trennlinie; damit rechnen Ziel und Ausweichen.
    static func plaetze(_ hoehen: [CGFloat]) -> [CGFloat] {
        hoehen.map { $0 + trennlinie }
    }

    /// Der Versatz, auf die Liste begrenzt: die gezogene Zeile bleibt mit
    /// ihrer Kante innerhalb der Karte.
    static func begrenzt(_ versatz: CGFloat, von: Int, hoehen: [CGFloat]) -> CGFloat {
        guard hoehen.indices.contains(von) else { return 0 }
        let oben = -hoehen[..<von].reduce(0, +)
        let unten = hoehen[(von + 1)...].reduce(0, +)
        return min(max(versatz, oben), unten)
    }

    /// Wohin die gezogene Zeile `von` faellt, wenn sie um `versatz` gewandert
    /// ist: hinter so viele andere Zeilen, wie ihre vordere Kante in
    /// Zugrichtung passiert hat (unten die Unterkante, oben die Oberkante --
    /// so erreicht auch eine hohe Zeile die aeussersten Plaetze). Das
    /// Ergebnis ist der Index nach dem Verschieben (`TrainingsplanAblauf.umordnen`).
    static func zielIndex(von: Int, versatz: CGFloat, hoehen: [CGFloat]) -> Int {
        guard hoehen.indices.contains(von) else { return von }
        var mitten: [CGFloat] = []
        var oben: CGFloat = 0
        for hoehe in hoehen {
            mitten.append(oben + hoehe / 2)
            oben += hoehe
        }
        let d = begrenzt(versatz, von: von, hoehen: hoehen)
        let eigeneOberkante = mitten[von] - hoehen[von] / 2
        if d >= 0 {
            let unterkante = eigeneOberkante + hoehen[von] + d
            return von + mitten.indices.filter { $0 > von && mitten[$0] < unterkante }.count
        }
        let oberkante = eigeneOberkante + d
        return von - mitten.indices.filter { $0 < von && mitten[$0] > oberkante }.count
    }

    /// Wie weit eine andere Zeile ausweicht, solange `von` Richtung `ziel`
    /// gezogen wird: um die Hoehe der gezogenen Zeile, damit eine Luecke bleibt.
    static func verschiebung(index: Int, von: Int, ziel: Int, hoehe: CGFloat) -> CGFloat {
        if von < ziel, index > von, index <= ziel { return -hoehe }
        if ziel < von, index >= ziel, index < von { return hoehe }
        return 0
    }

    /// Die Ansage nach einer Verschiebung per VoiceOver-Aktion.
    static func ansage(_ richtung: Richtung, neuerIndex: Int, anzahl: Int) -> String {
        let was = richtung == .hoch ? "Nach oben verschoben" : "Nach unten verschoben"
        return "\(was), Position \(neuerIndex + 1) von \(anzahl)"
    }
}
