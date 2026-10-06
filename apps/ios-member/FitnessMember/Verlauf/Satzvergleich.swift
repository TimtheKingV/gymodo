import Foundation

/// Der Fortschritt im Trainingsdetail (Testnotiz 06.10., #20).
///
/// Jeder Satz wird mit dem Durchschnitt DESSELBEN Satzes (Satz 1 mit Satz
/// 1 usw.) aus den bis zu fuenf vorherigen Trainings dieser Uebung
/// verglichen: wie viel mehr oder weniger Kilogramm, wie viele Wdh. mehr
/// oder weniger. Die Richtung des Pfeils folgt dem Volumen kg x Wdh., nicht
/// dem Gewicht allein -- 10 Wdh. mit 10 kg sind mehr als 5 Wdh. mit 18 kg.
/// Rechts je Uebung der Gesamttrend: die Summe kg x Wdh. aller Saetze
/// gegen den Durchschnitt dieser Summe (so auf Rueckfrage entschieden; ein
/// zusaetzlicher Satz zaehlt damit mit).
///
/// Nur bei Kilogramm und Wiederholungen: an einem Laufband gibt es weder
/// "mehr Gewicht" noch Wiederholungen. Grundlage ist der geladene Verlauf
/// (die juengsten 50 Einheiten, `getSessions`) -- fuer eine selten
/// trainierte Uebung findet sich darin auch mal weniger als fuenf.
///
/// Gerechnet wird ueber die Uebung, nicht ueber das einzelne Geraet: zwei
/// baugleiche Kabelzuege teilen dieselbe Uebung und dieselben Gewichte.
enum Satzvergleich {
    enum Trend: Equatable {
        case hoch
        case runter
        case gleich
    }

    struct Satz: Equatable {
        let deltaKg: Double
        let deltaWdh: Double
        let trend: Trend
    }

    struct Ergebnis: Equatable {
        /// Je Position im Block (0 = erster Satz); nil, wenn keines der
        /// vorherigen Trainings so viele Saetze hatte.
        let saetze: [Int: Satz]
        let gesamt: Trend
        /// Wie viele vorherige Trainings eingeflossen sind (1 bis 5).
        let basis: Int
    }

    static let hoechstensVorherige = 5

    /// nil, wenn es nichts zu vergleichen gibt: andere Einheiten als kg und
    /// Wdh., oder kein frueheres Training mit dieser Uebung.
    static func fuer(block: SessionSummary.Block, in teil: SessionSummary,
                     verlauf: [SessionSummary]) -> Ergebnis? {
        guard block.loadUnit == .kg, block.volumeKind == .reps,
              let beginn = Zeitpunkt.parse(teil.startedAt) else { return nil }

        let vorherige: [[SessionSummary.Block.Set]] = verlauf
            .compactMap { einheit -> (Date, [SessionSummary.Block.Set])? in
                guard einheit.id != teil.id,
                      let start = Zeitpunkt.parse(einheit.startedAt), start < beginn,
                      let gleich = einheit.blocks.first(where: { $0.exerciseId == block.exerciseId }),
                      !gleich.sets.isEmpty
                else { return nil }
                return (start, sortiert(gleich.sets))
            }
            .sorted { $0.0 > $1.0 }
            .prefix(hoechstensVorherige)
            .map(\.1)
        guard !vorherige.isEmpty else { return nil }

        let heute = sortiert(block.sets)
        var saetze: [Int: Satz] = [:]
        for (position, satz) in heute.enumerated() {
            let gegenstuecke = vorherige.compactMap { $0.indices.contains(position) ? $0[position] : nil }
            guard !gegenstuecke.isEmpty else { continue }
            let anzahl = Double(gegenstuecke.count)
            let schnittKg = gegenstuecke.map(\.load).reduce(0, +) / anzahl
            let schnittWdh = gegenstuecke.map { Double($0.volume) }.reduce(0, +) / anzahl
            let schnittVolumen = gegenstuecke.map(volumen).reduce(0, +) / anzahl
            saetze[position] = Satz(
                deltaKg: satz.load - schnittKg,
                deltaWdh: Double(satz.volume) - schnittWdh,
                trend: trend(volumen(satz), gegen: schnittVolumen))
        }

        let summeHeute = heute.map(volumen).reduce(0, +)
        let schnittSumme = vorherige.map { $0.map(volumen).reduce(0, +) }.reduce(0, +) / Double(vorherige.count)
        return Ergebnis(saetze: saetze, gesamt: trend(summeHeute, gegen: schnittSumme),
                        basis: vorherige.count)
    }

    /// "+2,5 kg", "−1,5 kg", "±0 kg" -- wie `Zahlformat.belastungDelta`,
    /// nur mit "±0" fuer keinen Unterschied: "+0,0 kg" lese sich wie ein
    /// Plus, das es nicht gab.
    static func kgText(_ delta: Double) -> String {
        abs(delta) < 0.05 ? "±0 kg" : Zahlformat.belastungDelta(delta, .kg)
    }

    /// "+2 Wdh.", "−1 Wdh.", "±0 Wdh." -- eine Nachkommastelle nur, wenn
    /// der Durchschnitt keine ganze Zahl ist ("+0,4 Wdh.").
    static func wdhText(_ delta: Double) -> String {
        let gerundet = (delta * 10).rounded() / 10
        guard gerundet != 0 else { return "±0 Wdh." }
        let vorzeichen = gerundet < 0 ? "−" : "+"
        let betrag = abs(gerundet)
        let zahl = betrag == betrag.rounded() ? String(Int(betrag)) : Zahlformat.gewicht(betrag)
        return "\(vorzeichen)\(zahl) Wdh."
    }

    private static func sortiert(_ saetze: [SessionSummary.Block.Set]) -> [SessionSummary.Block.Set] {
        saetze.sorted { $0.setIndex < $1.setIndex }
    }

    private static func volumen(_ satz: SessionSummary.Block.Set) -> Double {
        satz.load * Double(satz.volume)
    }

    /// Ein Hauch Toleranz, damit ein Durchschnitt wie 99,999... nicht als
    /// Rueckschritt gegen 100 zaehlt.
    private static func trend(_ wert: Double, gegen schnitt: Double) -> Trend {
        if wert > schnitt + 0.01 { return .hoch }
        if wert < schnitt - 0.01 { return .runter }
        return .gleich
    }
}
