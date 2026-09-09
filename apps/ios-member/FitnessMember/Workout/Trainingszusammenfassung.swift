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

/// Die Kopfzeile von TrainingAbschluss: welcher Tag, und der Zeitraum.
///
/// "HEUTE" stand dort fest verdrahtet. Eine Einheit, die um 23:40 beginnt
/// und um 00:20 endet, bekam damit "HEUTE · 23:40 – 00:20" -- eine falsche
/// Aussage ueber das eigene Training, auf genau dem Screen, auf dem das
/// Mitglied nachsieht, ob alles angekommen ist. Selten, aber nicht nie:
/// die Einheit laeuft bis zu vier Stunden (WorkoutSessionStore.sessionPause),
/// und der Abschluss-Screen kann beliebig lange offen stehen bleiben.
///
/// Die Uhrzeiten kommen als Funktion herein, statt hier ein zweites Mal
/// formatiert zu werden: `Zahlformat.uhrzeit` bleibt die einzige Stelle,
/// die eine Uhrzeit formatiert (geraetelokal -- die Einheit lief auf
/// diesem Geraet, anders als ein Kurstermin, der dem Studio gehoert).
/// Nebeneffekt: die Ableitung ist ohne Geraetezeitzone testbar.
enum Trainingszeitraum {
    static func kopfzeile(
        von: Date, bis: Date, jetzt: Date, kalender: Calendar,
        uhrzeit: (Date) -> String
    ) -> String {
        let tag = tagesbezeichnung(von, jetzt: jetzt, kalender: kalender)
        guard !kalender.isDate(von, inSameDayAs: bis) else {
            return "\(tag) · \(uhrzeit(von)) – \(uhrzeit(bis))"
        }
        // Ueber Mitternacht: ohne den zweiten Tag liest sich
        // "23:40 – 00:20" wie 41 Minuten am selben Tag, und der Screen
        // behauptete eine Dauer, die es nicht gab.
        let tagDanach = tagesbezeichnung(bis, jetzt: jetzt, kalender: kalender)
        return "\(tag) · \(uhrzeit(von)) – \(tagDanach) \(uhrzeit(bis))"
    }

    /// "HEUTE", "GESTERN", sonst das Datum ("7. SEPT."). Vergleicht gegen
    /// den uebergebenen `jetzt`, nicht gegen `Calendar.isDateInToday`:
    /// der liest die echte Uhr und waere nicht pruefbar.
    static func tagesbezeichnung(_ zeitpunkt: Date, jetzt: Date, kalender: Calendar) -> String {
        if kalender.isDate(zeitpunkt, inSameDayAs: jetzt) { return "HEUTE" }
        if let gestern = kalender.date(byAdding: .day, value: -1, to: jetzt),
           kalender.isDate(zeitpunkt, inSameDayAs: gestern) {
            return "GESTERN"
        }
        let formatter = DateFormatter()
        formatter.locale = kalender.locale ?? Locale(identifier: "de_DE")
        formatter.timeZone = kalender.timeZone
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: zeitpunkt).uppercased()
    }
}
