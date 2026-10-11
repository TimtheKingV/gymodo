import Foundation
@testable import Sensorik

struct Quoten: Equatable {
    let saetze: Int
    let tage: Int
    let exakt: Double
    let plusMinusEins: Double
    let ruecknahmen: Double
}

/// Guetemass und Tor aus Sensor-Spec B 5.5.
enum Guetebericht {
    static let mindestSaetze = 20
    static let mindestTage = 3
    static let exaktMin = 0.90
    static let plusMinusEinsMin = 0.98
    static let ruecknahmenMax = 0.10

    static func quoten(_ ergebnisse: [AufnahmeErgebnis]) -> Quoten {
        guard !ergebnisse.isEmpty else { return Quoten(saetze: 0, tage: 0, exakt: 0, plusMinusEins: 0, ruecknahmen: 0) }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let tage = Set(ergebnisse.map { kalender.startOfDay(for: $0.startedAt) }).count
        let zurueckgenommen = ergebnisse.filter { $0.unsicher != nil }
        let gezaehlt = ergebnisse.filter { $0.unsicher == nil }
        let n = Double(gezaehlt.count)
        return Quoten(
            saetze: ergebnisse.count,
            tage: tage,
            exakt: n == 0 ? 0 : Double(gezaehlt.filter { $0.gezaehlt == $0.repsWahr }.count) / n,
            plusMinusEins: n == 0 ? 0 : Double(gezaehlt.filter { abs($0.gezaehlt - $0.repsWahr) <= 1 }.count) / n,
            ruecknahmen: Double(zurueckgenommen.count) / Double(ergebnisse.count))
    }

    /// Nur echte Saetze, die der Zaehler in dieser Profilversion nie gesehen
    /// hat: fuerZaehler und nach eingefrorenAm aufgenommen.
    static func torset(_ ergebnisse: [AufnahmeErgebnis], art: Befestigungsart) -> [AufnahmeErgebnis] {
        guard let eingefroren = ZaehlerProfil.fuer(art).eingefrorenAm else { return [] }
        return ergebnisse.filter { $0.art == art && $0.fuerZaehler && $0.startedAt > eingefroren }
    }

    static func torErreicht(_ q: Quoten) -> Bool {
        q.saetze >= mindestSaetze && q.tage >= mindestTage
            && q.exakt >= exaktMin && q.plusMinusEins >= plusMinusEinsMin && q.ruecknahmen <= ruecknahmenMax
    }

    static func markdown(_ ergebnisse: [AufnahmeErgebnis]) -> String {
        func pct(_ x: Double) -> String { String(format: "%.0f %%", locale: Locale(identifier: "en_US_POSIX"), x * 100) }
        func zeile(_ titel: String, _ q: Quoten) -> String {
            "| \(titel) | \(q.saetze) | \(q.tage) | \(pct(q.exakt)) | \(pct(q.plusMinusEins)) | \(pct(q.ruecknahmen)) |"
        }
        var text = """
            # Gütebericht Wiederholungszähler

            Erzeugt von `GueteberichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
            Tor je Art (Sensor-Spec B 5.5): ≥ \(mindestSaetze) Sätze aus ≥ \(mindestTage) Tagen, exakt ≥ 90 %, ±1 ≥ 98 %, Rücknahmen ≤ 10 %.

            | Art · Set | Sätze | Tage | exakt | ±1 | Rücknahmen |
            |---|---|---|---|---|---|

            """
        for art in Befestigungsart.allCases {
            let entwicklung = ergebnisse.filter { $0.art == art }
            guard !entwicklung.isEmpty else { continue }
            let profil = ZaehlerProfil.fuer(art)
            text += zeile("\(art.rawValue) (\(profil.algo)) · Entwicklung", quoten(entwicklung)) + "\n"
            let tor = torset(ergebnisse, art: art)
            let q = quoten(tor)
            let status = profil.eingefrorenAm == nil ? "nicht eingefroren"
                : (torErreicht(q) ? "Tor erreicht" : "Tor offen")
            text += zeile("\(art.rawValue) · Torset (\(status))", q) + "\n"
        }
        text += "\n## Je Satz\n\n| Aufnahme | Art | wahr | gezählt | Rücknahme |\n|---|---|---|---|---|\n"
        for e in ergebnisse {
            text += "| \(e.ordner) | \(e.art.rawValue) | \(e.repsWahr) | \(e.gezaehlt) | \(e.unsicher?.rawValue ?? "–") |\n"
        }
        return text
    }
}
