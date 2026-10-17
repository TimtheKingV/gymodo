import Foundation

/// Was die Anzeige aus einem Prozentwert macht.
enum FortschrittsWert: Equatable {
    case wert(Int), stabil, keinWert
}

/// Kraftzuwachs je Muskel und Gruppe aus dem Uebungsverlauf der letzten
/// drei Monate, in Prozent der Startlast.
struct MuskelFortschritt: Equatable {
    let jeMuskel: [String: Double]
    let jeGruppe: [MuskelHauptgruppe: Double]

    /// Zwischen erstem und letztem Messpunkt mindestens so viele Tage.
    static let mindestAbstandTage = 14
    /// Start = beste Last der ersten, Ende = beste Last der letzten so vielen
    /// Tage; hoechstens aber die halbe Spanne zwischen erstem und letztem Punkt.
    static let endfensterTage = 30
    /// Innerhalb dieser Prozent gilt ein Muskel als stabil.
    private static let stabilGrenze = 3.0

    static func berechne(fortschritt: [ExerciseProgress], muskeln: [String: [GeraetMuskel]], jetzt: Date) -> MuskelFortschritt {
        let bekannt = Set(MuskelHauptgruppe.angezeigt.flatMap(\.muskelSchluessel))
        var prozente: [String: [Double]] = [:]

        for uebung in fortschritt {
            guard let prozent = prozent(uebung, jetzt: jetzt) else { continue }
            for muskel in muskeln[uebung.id] ?? [] where muskel.role == .primary && bekannt.contains(muskel.key) {
                prozente[muskel.key, default: []].append(prozent)
            }
        }

        let jeMuskel = prozente.mapValues { $0.reduce(0, +) / Double($0.count) }
        var jeGruppe: [MuskelHauptgruppe: Double] = [:]
        for gruppe in MuskelHauptgruppe.angezeigt {
            let werte = gruppe.muskelSchluessel.compactMap { jeMuskel[$0] }
            if !werte.isEmpty { jeGruppe[gruppe] = werte.reduce(0, +) / Double(werte.count) }
        }
        return MuskelFortschritt(jeMuskel: jeMuskel, jeGruppe: jeGruppe)
    }

    static func anzeige(_ prozent: Double?) -> FortschrittsWert {
        guard let prozent, prozent.isFinite else { return .keinWert }
        if abs(prozent) < stabilGrenze { return .stabil }
        return .wert(Int(prozent.rounded()))
    }

    private static func prozent(_ uebung: ExerciseProgress, jetzt: Date) -> Double? {
        let tag: TimeInterval = 86_400
        let punkte: [(Date, Double)] = Fortschrittsfenster.dreiMonate.punkte(uebung.points, jetzt: jetzt)
            .compactMap { punkt in
                Zeitpunkt.parse("\(punkt.tag)T12:00:00Z").map { ($0, punkt.topLoad) }
            }
            .sorted { $0.0 < $1.0 }
        guard let erster = punkte.first, let letzter = punkte.last,
              letzter.0.timeIntervalSince(erster.0) >= Double(mindestAbstandTage) * tag
        else { return nil }

        // Bei Spannen unter 60 Tagen wuerden sich zwei 30-Tage-Fenster
        // ueberlappen; dann ist jedes Fenster die halbe Spanne.
        let spanne = letzter.0.timeIntervalSince(erster.0)
        let fenster = min(Double(endfensterTage) * tag, spanne / 2)
        let startGrenze = erster.0.addingTimeInterval(fenster)
        let endGrenze = jetzt.addingTimeInterval(-fenster)
        guard let start = punkte.filter({ $0.0 <= startGrenze }).map(\.1).max(),
              let ende = punkte.filter({ $0.0 >= endGrenze }).map(\.1).max(),
              start > 0
        else { return nil }
        let ergebnis = (ende - start) / start * 100
        return ergebnis.isFinite ? ergebnis : nil
    }
}
