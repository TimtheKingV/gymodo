import Foundation

/// Was von einem Wochenplan ueberhaupt auf Platte darf: die eigenen
/// Termine, nicht der ganze `CourseWeek` mit den Belegungszahlen fremder
/// Termine. Eine Belegungszahl von vorhin ohne Netz als aktuell zu
/// zeigen waere dieselbe Unwahrheit, die beim Satz-Status vermieden wird
/// -- "6 von 20 frei", man faehrt hin, der Kurs ist voll. Die eigene
/// Anmeldung dagegen aendert sich nicht von selbst.
///
/// `stand` wird mitgeschrieben, weil "Meine Kurse" ohne Netz sagen muss,
/// WANN dieser Stand war -- ohne Zeitangabe waere der Cache eine stille
/// Behauptung. `cancellationDeadlineHours` und `timezone` kommen mit, weil
/// die Abmeldefrist-Anzeige (KursZustandRechner.abmeldenBis, KursZeit) sie
/// braucht und beide je Studio verschieden sind -- ohne Netz gaebe es
/// sonst keine Quelle mehr dafuer.
struct GespeicherteBuchungen: Codable {
    let stand: Date
    let termine: [CourseWeekSession]
    let cancellationDeadlineHours: Int
    let timezone: String
}

/// Die eigenen Kursbuchungen auf Platte -- wie SessionFileStore und
/// PendingWriteStore nach demselben Muster: App-Support-Verzeichnis, JSON,
/// atomar, Fehler still (ein fehlendes oder verderbtes File ist kein
/// Absturzgrund, nur ein leerer Cache).
///
/// `save(_:)` nimmt bewusst ein Optional wie SessionFileStore.save(_:) --
/// `nil` raeumt die Datei weg, fuer reset() beim Abmelden. Und selbst bei
/// einem uebergebenen, nicht-nil Wert gilt: ohne eigene Termine landet
/// NICHTS auf der Platte -- ein leerer Stand ohne Buchung ist keine
/// Information, die den Cache wert waere, und diese Regel gehoert hierher,
/// nicht in jede Aufrufstelle einzeln.
final class KurseFileStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("eigene-kurse.json")
    }

    func load() -> GespeicherteBuchungen? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GespeicherteBuchungen.self, from: data)
    }

    func save(_ buchungen: GespeicherteBuchungen?) {
        guard let buchungen, !buchungen.termine.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(buchungen) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
