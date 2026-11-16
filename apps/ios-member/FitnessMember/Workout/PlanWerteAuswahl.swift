import Foundation

/// Auswahlwerte fuer das Anpassen-Blatt einer Planposition (P4, Testnotiz 10.11. #7).
/// Grenzen wie im Server: Saetze 1-10, Wdh 1-50, Dauer 5-120.
enum PlanWerteAuswahl {
    static let saetzeBereich = 1...10
    static let wdhBereich = 1...50
    static let dauerStufen = [5, 10, 15, 20, 25, 30, 40, 45, 60, 75, 90, 120]

    /// Rest-Stufen plus 150 (Plan-Standard fuer Mehrgelenk) plus der aktuelle Wert.
    static func pausenStufen(aktuell: Int) -> [Int] {
        Array(Set(Einstellungen.resttimerStufen + [150, aktuell])).sorted()
    }

    /// Wdh bis darf nie unter Wdh von liegen.
    static func wdhBisBereich(von: Int) -> ClosedRange<Int> {
        min(max(von, wdhBereich.lowerBound), wdhBereich.upperBound)...wdhBereich.upperBound
    }

    static func dauerStufen(aktuell: Int) -> [Int] {
        Array(Set(dauerStufen + [aktuell])).sorted()
    }
}
