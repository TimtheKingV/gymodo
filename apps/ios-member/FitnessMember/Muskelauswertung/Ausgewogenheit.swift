import Foundation

/// Wie ein Muskel bzw. eine Gruppe im Vergleich zum Rest dasteht.
enum MuskelStatus: Equatable {
    case nachholbedarf, ok, viel, kaumUebungen, keineAuswertung
}

/// Bewertet die Verteilung des Trainings auf die sechs Gruppen und die
/// Muskeln innerhalb einer Gruppe.
enum Ausgewogenheit {
    /// Muskeln, die Hauptmuskel in hoechstens zwei Kataloguebungen sind
    /// (teils in keiner) -- nie ein Hinweis.
    static let seltene: Set<String> = [
        "erectors", "adductors", "abductors", "rotator_cuff",
        "serratus_anterior", "tibialis", "fibularis"
    ]

    /// Darunter gilt etwas als zu wenig, darueber als viel (Vielfaches des Mittels).
    private static let untereGrenze = 0.5
    private static let obereGrenze = 1.5

    /// 100 = alle Gruppen gleich oft; sinkt mit der Abweichung vom Mittel.
    static func prozent(_ h: Haeufigkeit) -> Int? {
        guard h.istAuswertbar else { return nil }
        let zahlen = MuskelHauptgruppe.angezeigt.map { Double(h.jeGruppe[$0] ?? 0) }
        let mittel = zahlen.reduce(0, +) / Double(zahlen.count)
        guard mittel > 0 else { return nil }
        let abweichung = zahlen.map { abs($0 - mittel) }.reduce(0, +) / Double(zahlen.count) / mittel
        return Int((max(0, 1 - abweichung) * 100).rounded())
    }

    static func status(gruppe: MuskelHauptgruppe, in h: Haeufigkeit) -> MuskelStatus {
        guard h.istAuswertbar else { return .keineAuswertung }
        let zahlen = MuskelHauptgruppe.angezeigt.map { Double(h.jeGruppe[$0] ?? 0) }
        let mittel = zahlen.reduce(0, +) / Double(zahlen.count)
        return bewerte(Double(h.jeGruppe[gruppe] ?? 0), mittel: mittel)
    }

    static func status(muskel: String, gruppe: MuskelHauptgruppe, in h: Haeufigkeit) -> MuskelStatus {
        guard h.istAuswertbar else { return .keineAuswertung }
        if seltene.contains(muskel) { return .kaumUebungen }
        let referenz = gruppe.muskelSchluessel.filter { !seltene.contains($0) }
        guard !referenz.isEmpty else { return .kaumUebungen }
        let summe = referenz.reduce(0) { $0 + (h.jeMuskel[$1] ?? 0) }
        let mittel = Double(summe) / Double(referenz.count)
        return bewerte(Double(h.jeMuskel[muskel] ?? 0), mittel: mittel)
    }

    /// Null Einheiten bei vorhandener Datenreife ist immer Nachholbedarf.
    private static func bewerte(_ wert: Double, mittel: Double) -> MuskelStatus {
        if wert == 0 { return .nachholbedarf }
        if wert < untereGrenze * mittel { return .nachholbedarf }
        if wert > obereGrenze * mittel { return .viel }
        return .ok
    }
}
