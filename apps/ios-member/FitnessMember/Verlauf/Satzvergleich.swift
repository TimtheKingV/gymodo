import Foundation

/// Der Fortschritt im Trainingsdetail (Testnotiz 06.10., #20; seit
/// Testnotiz 19.10., #2 ein Feld je Uebung statt einer Zahl je Satz).
///
/// Verglichen wird der Schnitt aller Saetze heute mit dem Schnitt der bis
/// zu fuenf vorherigen Trainings dieser Uebung: wie viel Kilogramm und wie
/// viele Wdh. je Satz mehr oder weniger. Vorher stand das je Satz da (Satz
/// 1 gegen Satz 1 usw.) -- bei immer gleichen 12 kg las sich das als
/// "+3,7 kg", nur weil Satz 1 frueher im Schnitt leichter war.
///
/// Jedes vorherige Training zaehlt gleich, egal wie viele Saetze es hatte:
/// erst der Schnitt je Training, dann der Schnitt dieser Schnitte.
///
/// Der Pfeil folgt dem Volumen kg x Wdh., nicht dem Gewicht allein: die
/// Summe aller Saetze gegen den Durchschnitt dieser Summe (ein
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

    struct Ergebnis: Equatable {
        /// Schnitt je Satz heute minus Schnitt je Satz vorher.
        let deltaKg: Double
        let deltaWdh: Double
        let gesamt: Trend
        /// Wie viele vorherige Trainings eingeflossen sind (1 bis 5).
        let basis: Int
    }

    static let hoechstensVorherige = 5

    /// nil, wenn es nichts zu vergleichen gibt: andere Einheiten als kg und
    /// Wdh., kein frueheres Training mit dieser Uebung oder heute kein
    /// Kraftsatz.
    static func fuer(block: SessionSummary.Block, in teil: SessionSummary,
                     verlauf: [SessionSummary]) -> Ergebnis? {
        guard block.loadUnit == .kg, block.volumeKind == .reps,
              let beginn = Zeitpunkt.parse(teil.startedAt) else { return nil }

        let vorherige: [[Kraftsatz]] = verlauf
            .compactMap { einheit -> (Date, [Kraftsatz])? in
                guard einheit.id != teil.id,
                      let start = Zeitpunkt.parse(einheit.startedAt), start < beginn,
                      let gleich = einheit.blocks.first(where: { $0.exerciseId == block.exerciseId })
                else { return nil }
                let saetze = kraftsaetze(gleich.sets)
                return saetze.isEmpty ? nil : (start, saetze)
            }
            .sorted { $0.0 > $1.0 }
            .prefix(hoechstensVorherige)
            .map(\.1)
        let heute = kraftsaetze(block.sets)
        guard !vorherige.isEmpty, !heute.isEmpty else { return nil }

        let schnittKg = schnitt(vorherige.map { schnitt($0.map(\.load)) })
        let schnittWdh = schnitt(vorherige.map { schnitt($0.map { Double($0.volume) }) })
        let summeHeute = heute.map(volumen).reduce(0, +)
        let schnittSumme = schnitt(vorherige.map { $0.map(volumen).reduce(0, +) })
        return Ergebnis(deltaKg: schnitt(heute.map(\.load)) - schnittKg,
                        deltaWdh: schnitt(heute.map { Double($0.volume) }) - schnittWdh,
                        gesamt: trend(summeHeute, gegen: schnittSumme),
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

    /// Was der Vergleich von einem Satz braucht. Ein Cardio-Satz hat keine
    /// Belastung und keine Wiederholungen und faellt heraus.
    private struct Kraftsatz {
        let load: Double
        let volume: Int
    }

    private static func kraftsaetze(_ saetze: [SessionSummary.Block.Set]) -> [Kraftsatz] {
        saetze.compactMap { satz in
            guard let load = satz.load, let volume = satz.volume else { return nil }
            return Kraftsatz(load: load, volume: volume)
        }
    }

    private static func schnitt(_ werte: [Double]) -> Double {
        werte.isEmpty ? 0 : werte.reduce(0, +) / Double(werte.count)
    }

    private static func volumen(_ satz: Kraftsatz) -> Double {
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
