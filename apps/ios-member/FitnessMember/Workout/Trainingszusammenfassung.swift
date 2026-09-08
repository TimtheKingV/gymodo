import Foundation

/// Eine Zeile unter "Beim naechsten Mal" -- ohne den Vorschlag, der vom
/// Server kommt.
///
/// Hashable, weil GeraetRoute (der Pfad des Training-Tabs) Hashable sein
/// muss und den Abschluss-Fall mit einer Trainingszusammenfassung im Gepaeck
/// traegt. Beide Typen bestehen nur aus Hashable-Bestandteilen -- eine
/// Konformanzzeile ohne Umbau.
struct Blockzeile: Equatable, Hashable, Identifiable {
    var id: String { "\(machineId):\(exerciseId)" }
    let machineId: String
    let exerciseId: String
    /// nil, wenn die Saetze sich nicht auf ein Gewicht einigen -- dann
    /// lieber keine Zahl als eine falsche.
    let gewichtKg: Double?
    let satzAnzahl: Int
    let problemGemeldet: Bool
}

/// Die Zahlen von TrainingAbschluss.
///
/// Sie kommen aus der lokalen Einheit, nicht vom Server: die App ist die
/// einzige Instanz, die alle Saetze sicher kennt, solange welche in der
/// Schreib-Warteschlange liegen. Ein serverseitig gerechneter Abschluss
/// zeigte nach einem Offline-Training zu wenig -- ausgerechnet dort, wo
/// das Mitglied am ehesten nachsieht, ob alles angekommen ist.
struct Trainingszusammenfassung: Equatable, Hashable {
    let von: Date
    let bis: Date
    let dauerMinuten: Int
    let geraeteAnzahl: Int
    let satzAnzahl: Int
    let bloecke: [Blockzeile]

    /// nil fuer eine Einheit ohne Saetze -- die gibt es zwar nicht, weil
    /// die Session mit dem ersten Satz entsteht, aber ein Abschluss ohne
    /// Inhalt waere eine leere Statistik mit Nullen (SS5).
    init?(_ session: LokaleSession) {
        let alle = session.bloecke.flatMap(\.saetze)
        guard let erster = alle.map(\.performedAt).min(),
              let letzter = alle.map(\.performedAt).max()
        else { return nil }

        von = erster
        bis = letzter
        dauerMinuten = Int(letzter.timeIntervalSince(erster) / 60)
        // Geraete, nicht Bloecke: zwei Uebungen an derselben Maschine sind
        // ein Geraet (so zaehlt es auch der Server in machineCount).
        geraeteAnzahl = Set(session.bloecke.map(\.machineId)).count
        satzAnzahl = alle.count
        bloecke = session.bloecke.map { block in
            let gewichte = Set(block.saetze.map(\.weightKg))
            return Blockzeile(
                machineId: block.machineId,
                exerciseId: block.exerciseId,
                gewichtKg: gewichte.count == 1 ? gewichte.first : nil,
                satzAnzahl: block.saetze.count,
                problemGemeldet: block.saetze.contains(where: \.problemFlag)
            )
        }
    }
}
