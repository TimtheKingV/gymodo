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

    /// Wdh bis folgt Wdh von nach oben mit (P4).
    static func wdhBisNachVon(von: Int, bis: Int) -> Int { max(von, bis) }

    struct Ergebnis: Equatable {
        let saetze: Int
        let wdhVon: Int?
        let wdhBis: Int?
        let pauseSek: Int
        let dauerMin: Int?
    }

    /// Was "Uebernehmen" meldet: unberuehrte Felder behalten exakt den Ausgangswert
    /// (auch nil), nur beruehrte nehmen den Anzeigewert (P4).
    static func ergebnis(
        ausgang: EntwurfsPosition, saetze: Int, wdhVon: Int, wdhBis: Int, pauseSek: Int, dauerMin: Int,
        beruehrt: Set<WertFeld>
    ) -> Ergebnis {
        if ausgang.art.istCardio {
            return Ergebnis(
                saetze: ausgang.saetze, wdhVon: nil, wdhBis: nil, pauseSek: ausgang.pauseSek,
                dauerMin: beruehrt.contains(.dauer) ? dauerMin : ausgang.dauerMin)
        }
        let wdh = beruehrt.contains(.wdh)
        return Ergebnis(
            saetze: beruehrt.contains(.saetze) ? saetze : ausgang.saetze,
            wdhVon: wdh ? wdhVon : ausgang.wdhVon,
            wdhBis: wdh ? wdhBis : ausgang.wdhBis,
            pauseSek: beruehrt.contains(.pause) ? pauseSek : ausgang.pauseSek,
            dauerMin: ausgang.dauerMin)
    }
}
