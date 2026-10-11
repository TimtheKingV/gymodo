import Foundation

/// Was von einem eigenen Termin ueberhaupt auf Platte darf -- eine eigene,
/// schmale Struktur statt der vollen `CourseWeekSession`.
///
/// Bewusst NICHT dabei, mit Begruendung:
/// - `bookedCount`, `waitlistCount`, `freeSeats`, `capacity`: Belegungszahlen
///   sind genau die Unwahrheit, die diese Aufgabe verhindern soll -- "6 von
///   20 frei" ohne Netz, fuer den eigenen gebuchten Kurs, waere dieselbe
///   Luege wie ein veralteter Satz-Status. Eine zweite Pruefung in
///   `KurseFileStore.save(_:)` (leere Liste -> keine Datei) faengt nur den
///   Fall "keine eigene Buchung" ab, nicht dieses Feld -- die Schranke muss
///   deshalb im TYP selbst sitzen, nicht nur an einer Aufrufstelle: was
///   nicht gespeichert werden darf, hat hier gar kein Feld, in das es
///   hineingeraten koennte.
/// - `templateId`: reiner Server-interner Verweis, keine Aufrufstelle
///   braucht ihn.
/// - `ownWaitlistPosition`: aendert sich ohne eigenes Zutun -- storniert
///   jemand vor mir auf der Warteliste, ruecke ich nach oder werde
///   uebernommen, und der Server macht das von sich aus. "Warteliste,
///   Platz 3" ohne Netz waere ebenso unwahr wie eine Belegungszahl; ohne
///   Netz gilt nur "du stehst auf der Warteliste" (ownStatus), die Position
///   kommt ausschliesslich aus einem frischen Abruf.
///
/// Dabei: `status`, weil ein abgesagter Kurs, fuer den ich angemeldet war,
/// auch ohne Netz als abgesagt erscheinen muss (KursZustandRechner:
/// abgesagt schlaegt jeden eigenen Status).
struct GespeicherterTermin: Codable, Equatable, Identifiable {
    var id: String { sessionId }

    let sessionId: String
    let name: String
    let description: String?
    /// ISO 8601, UTC -- wie CourseWeekSession.startsAt, ueber
    /// Zeitpunkt.parse zu lesen.
    let startsAt: String
    let localDay: String
    let durationMin: Int
    let room: String?
    let instructorName: String?
    /// "planned" | "cancelled".
    let status: String
    /// "booked" | "waitlisted" -- optional getippt wie in CourseWeekSession
    /// (dort auch nil-faehig), obwohl `KurseStore` hier ausschliesslich
    /// Termine mit einem eigenen Status ablegt.
    let ownStatus: String?
    let ownBookingId: String?
    /// Studio, Frist und Zeitzone je Termin (Testnotiz 11.10., #15): seit
    /// der Plan alle Studios zeigt, gilt fuer jede Buchung die Frist IHRES
    /// Studios. Optional, damit `frist(fuer:)` sauber auf die Werte der
    /// Datei zurueckfaellt.
    let studioId: String?
    let cancellationDeadlineHours: Int?
    let timezone: String?

    /// Der einzige Weg, wie diese Struktur entsteht: aus einem Termin mit
    /// eigenem Status, alles Fremde bleibt beim Erzeugen aussen vor.
    init(_ termin: CourseWeekSession, frist: Int? = nil, zeitzone: String? = nil) {
        sessionId = termin.sessionId
        name = termin.name
        description = termin.description
        startsAt = termin.startsAt
        localDay = termin.localDay
        durationMin = termin.durationMin
        room = termin.room
        instructorName = termin.instructorName
        status = termin.status
        ownStatus = termin.ownStatus
        ownBookingId = termin.ownBookingId
        studioId = termin.studioId
        cancellationDeadlineHours = frist
        timezone = zeitzone
    }
}

/// `stand` wird mitgeschrieben, weil "Meine Kurse" ohne Netz sagen muss,
/// WANN dieser Stand war -- ohne Zeitangabe waere der Cache eine stille
/// Behauptung. `cancellationDeadlineHours` und `timezone` kommen mit, weil
/// die Abmeldefrist-Anzeige (KursZustandRechner.abmeldenBis, KursZeit) sie
/// braucht und beide je Studio verschieden sind -- ohne Netz gaebe es
/// sonst keine Quelle mehr dafuer.
///
/// `studioIds` sagt, WESSEN Buchungen das sind. Ohne sie zeigte "Meine
/// Kurse" nach einem Austritt ohne Netz die Anmeldungen eines Studios, zu
/// dem das Mitglied nicht mehr gehoert -- es koennte an den falschen Ort
/// fahren. Das ist
/// nicht einmal "veraltet", sondern schlicht das falsche Studio, und
/// `stand` kann es nicht abfangen: ein Datum sagt, wie ALT etwas ist,
/// nicht, WOZU es gehoert.
///
/// Auf die Platte, nicht nur in den Speicher: `KurseStore.letzteAbfrage`
/// lebt nur so lange wie die App. Ein Kaltstart mit inzwischen
/// gewechseltem Studio erkennt den Wechsel sonst nicht -- und genau dort
/// steht der Cache allein da. Datenschutzlich kommt nichts Neues dazu:
/// `UserDefaults` traegt `activeStudioId` ohnehin schon (SP1).
struct GespeicherteBuchungen: Codable {
    let stand: Date
    /// Zu welchen Studios diese Buchungen gehoeren -- seit der Plan alle
    /// Studios zeigt, eine Menge statt einer Kennung (Testnotiz 11.10.,
    /// #15). Eine Datei im alten Format (`studioId`) scheitert am Decoder
    /// und gilt als leerer Cache, aus demselben Grund wie unten bei
    /// `load()` beschrieben.
    let studioIds: [String]
    let termine: [GespeicherterTermin]
    /// Frist und Zeitzone des ersten Studios: Rueckfall fuer Termine ohne
    /// eigene Angabe und Grundlage des Wochenstreifens.
    let cancellationDeadlineHours: Int
    let timezone: String

    func frist(fuer termin: GespeicherterTermin) -> Int {
        termin.cancellationDeadlineHours ?? cancellationDeadlineHours
    }

    func zeitzone(fuer termin: GespeicherterTermin) -> String {
        termin.timezone ?? timezone
    }
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

    /// Ein Bestand aus der Zeit VOR `studioId` scheitert am Decoder und
    /// ergibt `nil` -- das Feld ist bewusst nicht optional.
    ///
    /// Wegwerfen ist hier die richtige Entscheidung: der naechste Abruf
    /// fuellt den Cache in Sekunden wieder, und bis dahin sagt "Meine
    /// Kurse" ehrlich, dass die Anmeldungen noch nicht bekannt sind. Die
    /// Datei blind zu behalten hiesse dagegen, Buchungen ohne Zuordnung zu
    /// zeigen -- genau der Fehler, gegen den das Feld eingefuehrt wurde,
    /// nur ohne jede Moeglichkeit, ihn zu erkennen. Ein optionales Feld
    /// mit "nil passt zu jedem Studio" waere dasselbe in Grau.
    ///
    /// Es braucht dafuer keinen eigenen Zweig: `try?` faengt den
    /// Decodierfehler schon. Ein verderbtes File war hier immer ein leerer
    /// Cache, nie ein Absturzgrund.
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
