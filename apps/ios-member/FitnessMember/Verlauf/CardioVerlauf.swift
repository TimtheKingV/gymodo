import Foundation

/// Die letzten Einheiten einer Cardio-Uebung, aus dem lokalen Verlauf
/// (Testnotiz 14.10., 18:45 #7). Der Fortschritts-Endpunkt kennt nur
/// Belastung und Umfang -- ein Cardio-Satz hat keins von beiden, also gibt
/// es dort keine Kurve, und eine Liste der Werte ersetzt sie.
struct CardioVerlauf: Equatable {
    struct Einheit: Equatable {
        let start: Date
        /// Der letzte Satz der Einheit an dieser Uebung.
        let werte: CardioWerte
    }

    let machineLabel: String
    let exerciseName: String
    /// Neueste zuerst, hoechstens `anzahl`.
    let einheiten: [Einheit]

    static let anzahl = 10

    /// nil, wenn die Uebung im Verlauf keinen Cardio-Satz hat -- oder auch
    /// Kraftsaetze: dann bleibt es beim Diagramm.
    static func fuer(exerciseId: String, sessions: [SessionSummary]) -> CardioVerlauf? {
        let bloecke = sessions.flatMap { einheit in
            einheit.blocks.filter { $0.exerciseId == exerciseId }.map { (einheit, $0) }
        }
        let saetze = bloecke.flatMap(\.1.sets)
        guard saetze.contains(where: { $0.cardio != nil }),
              !saetze.contains(where: { $0.cardio == nil }),
              let neuester = bloecke.max(by: { $0.0.startedAt < $1.0.startedAt })?.1
        else { return nil }

        let einheiten = bloecke.compactMap { einheit, block -> Einheit? in
            guard let start = Zeitpunkt.parse(einheit.startedAt),
                  let werte = block.sets.max(by: { $0.setIndex < $1.setIndex })?.cardio
            else { return nil }
            return Einheit(start: start, werte: werte)
        }
        .sorted { $0.start > $1.start }
        .prefix(anzahl)

        return CardioVerlauf(machineLabel: neuester.machineLabel, exerciseName: neuester.exerciseName,
                             einheiten: Array(einheiten))
    }
}
