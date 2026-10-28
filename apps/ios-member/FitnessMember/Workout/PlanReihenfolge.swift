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

    /// Wohin die gezogene Zeile `von` faellt, wenn ihre Mitte um `versatz`
    /// gewandert ist: hinter so viele andere Zeilen, wie ihre Mitte
    /// passiert hat. Das Ergebnis ist der Index nach dem Verschieben
    /// (`TrainingsplanAblauf.umordnen`).
    static func zielIndex(von: Int, versatz: CGFloat, hoehen: [CGFloat]) -> Int {
        guard hoehen.indices.contains(von) else { return von }
        var mitten: [CGFloat] = []
        var oben: CGFloat = 0
        for hoehe in hoehen {
            mitten.append(oben + hoehe / 2)
            oben += hoehe
        }
        let neueMitte = mitten[von] + versatz
        return mitten.enumerated().filter { $0.offset != von && $0.element < neueMitte }.count
    }

    /// Wie weit eine andere Zeile ausweicht, solange `von` Richtung `ziel`
    /// gezogen wird: um die Hoehe der gezogenen Zeile, damit eine Luecke bleibt.
    static func verschiebung(index: Int, von: Int, ziel: Int, hoehe: CGFloat) -> CGFloat {
        if von < ziel, index > von, index <= ziel { return -hoehe }
        if ziel < von, index >= ziel, index < von { return hoehe }
        return 0
    }
}
