import Foundation
import Observation

/// Was die drei Kurse-Screens (Aufgabe 9-11) vom Netz brauchen -- eigene
/// schmale Fassade statt einer generischen Abstraktion, dieselbe
/// Begruendung wie bei BootstrapLoading und GeraetLoading: APIClient ist
/// bewusst ein actor ohne Router, und ein Protokoll je Aufrufkontext
/// bleibt testbar, ohne den Client aufzublaehen.
///
/// Die drei Signaturen sind die, die APIClient (Aufgabe 7) tatsaechlich
/// hat -- bookCourse verlangt zwingend eine clientseitig erzeugte
/// bookingId (der Server antwortet sonst mit 422), nicht die schlankere
/// Fassung, die eine fruehere Fassung dieser Aufgabe vorsah.
protocol KurseLoading: Sendable {
    func courseWeek(studio: String, from: String, to: String) async throws(APIError) -> CourseWeek
    func bookCourse(sessionId: String, bookingId: UUID) async throws(APIError) -> BookOutcome
    func cancelCourse(sessionId: String) async throws(APIError) -> CancelOutcome
}

extension APIClient: KurseLoading {}

/// Ladezustand des Wochenplans -- eigener Typ statt CatalogLoadState
/// wiederzuverwenden: dessen `loaded(hasStudio:)` traegt eine Nutzlast, die
/// hier keinen Sinn ergibt, und der Kurse-Bildschirm braucht keine.
enum KurseLadeZustand: Equatable {
    case bereit
    case laedt
    case geladen
    case fehlgeschlagen
}

/// Haelt den Wochenplan, fuehrt Buchung und Stornierung aus -- und
/// persistiert ausschliesslich die eigenen Buchungen (KurseFileStore).
///
/// @MainActor, weil der Store wie CatalogStore und SessionStore ueber
/// @Environment direkt in SwiftUI-Views gelesen wird (ab Aufgabe 9); ohne
/// diese Isolation flaggt Swift 6 beim Aufruf von z. B. laden(...) aus
/// einem View heraus einen "sending"-Fehler, weil die Klasse selbst nicht
/// Sendable ist.
@MainActor
@Observable
final class KurseStore {
    private(set) var woche: CourseWeek?
    private(set) var ladeZustand: KurseLadeZustand = .bereit
    private(set) var eigene: GespeicherteBuchungen?

    /// Wie oft laden(...) tatsaechlich gelaufen ist -- existiert nur fuer
    /// KurseStoreTests.einErfolgreichesBuchenLaedtNeu, das beweisen muss,
    /// dass buchen(...) nach einem Erfolg selbst neu laedt. Keine
    /// Fachlogik greift hierauf zu.
    private(set) var ladeZaehler = 0

    /// Absichtlich nicht `private`: KurseStoreTests programmiert nach der
    /// Store-Konstruktion das Ergebnis des jeweils naechsten
    /// courseWeek(...)-Aufrufs auf dem Fake (etwa fuer den
    /// Offline-Testfall) -- laden(...) selbst nimmt keinen CourseWeek als
    /// Parameter entgegen, es gibt also keinen anderen Weg, ihn von aussen
    /// zu erreichen.
    let loader: any KurseLoading
    private let fileStore: KurseFileStore

    /// Die clientseitig erzeugte Buchungskennung je Termin (sessionId).
    /// Sie lebt so lange wie der Store selbst und wird erst bei einem
    /// ERFOLGREICHEN Buchen wieder entfernt -- solange schlaegt buchen(...)
    /// fehl oder das Geraet verliert das Netz mitten in der Anfrage, muss
    /// ein Wiederholungsversuch dieselbe Kennung schicken, sonst waere er
    /// eine ZWEITE Buchung statt eines Wiederholungsversuchs derselben.
    /// Nach einem Erfolg wird sie geloescht: der Server verbietet eine
    /// wiederverwendete bookingId fuer alles ausser der eigenen offenen
    /// Buchung ("booking_id_reused", courses.ts) -- eine spaetere, fachlich
    /// neue Buchung desselben Termins (nach einer Stornierung) braucht
    /// deshalb eine frische Kennung, keine wiederverwendete.
    ///
    /// Bewusst nur im Speicher, nicht auf Platte: das Fenster, das sie
    /// schuetzt, ist ein Wiederholungsversuch waehrend derselben App-
    /// Sitzung (Netzwechsel, ein Screen, der es erneut versucht). Ein
    /// App-Kill mitten in genau diesem Fenster ist ein selteneres Risiko
    /// als die zusaetzliche Datei und ihr eigenes Fehlerbild dauerhaft
    /// im Store zu tragen -- siehe Bericht.
    private var buchungskennungen: [String: UUID] = [:]

    /// Die Parameter des letzten laden(...)-Aufrufs -- buchen(...) und
    /// stornieren(...) nehmen laut Aufgabenstellung nur die sessionId
    /// entgegen und muessen trotzdem neu laden, damit der Screen danach
    /// nicht weiter "Anmelden" zeigt. `nil`, solange noch nie geladen
    /// wurde; dann bleibt ein Nachladen einfach aus.
    private var letzteAbfrage: (studioId: String, von: Date, bis: Date)?

    init(loader: any KurseLoading, fileStore: KurseFileStore) {
        self.loader = loader
        self.fileStore = fileStore
        eigene = fileStore.load()
    }

    /// Laedt den Wochenplan eines Studios fuer das gegebene Fenster.
    ///
    /// Bei Erfolg werden die eigenen Buchungen aus der Antwort gebildet
    /// und persistiert. Bei Fehler bleibt `eigene` UNANGETASTET -- der
    /// zuletzt gespeicherte Stand ist genau das, was den Screen dann
    /// traegt, waehrend `woche` (die fremden Belegungszahlen) nil bleibt.
    func laden(studioId: String, von: Date, bis: Date) async {
        ladeZaehler += 1
        ladeZustand = .laedt
        letzteAbfrage = (studioId, von, bis)
        let formatter = ISO8601DateFormatter()
        do {
            let neueWoche = try await loader.courseWeek(
                studio: studioId, from: formatter.string(from: von), to: formatter.string(from: bis))
            woche = neueWoche
            let meineTermine = KursZustandRechner.meineKurse(aus: neueWoche)
            let neu = GespeicherteBuchungen(
                stand: Date(), termine: meineTermine,
                cancellationDeadlineHours: neueWoche.cancellationDeadlineHours,
                timezone: neueWoche.timezone)
            eigene = meineTermine.isEmpty ? nil : neu
            fileStore.save(eigene)
            ladeZustand = .geladen
        } catch {
            woche = nil
            ladeZustand = .fehlgeschlagen
        }
    }

    /// Bucht einen Termin und laedt danach neu -- sonst zeigte der Screen
    /// nach dem Anmelden weiter "Anmelden" (M1-Fund, KurseStoreTests).
    ///
    /// Faengt den Fehler bewusst NICHT: der Servertext ist die
    /// Fehlermeldung, die der Screen zeigt (SS5: sagt, was falsch ist und
    /// was gilt), und nur der Server weiss, ob der Platz weg ist oder die
    /// Frist vorbei. Schlaegt bookCourse fehl, bricht diese Methode hier
    /// ab -- die Zeile darunter, die die Kennung als verbraucht markiert,
    /// laeuft dann nicht, und genau das ist gewollt: ein Wiederholungsversuch
    /// soll dieselbe Kennung wiederverwenden.
    func buchen(sessionId: String) async throws(APIError) {
        let kennung = buchungskennungen[sessionId] ?? UUID()
        buchungskennungen[sessionId] = kennung
        _ = try await loader.bookCourse(sessionId: sessionId, bookingId: kennung)
        buchungskennungen[sessionId] = nil
        if let letzteAbfrage {
            await laden(studioId: letzteAbfrage.studioId, von: letzteAbfrage.von, bis: letzteAbfrage.bis)
        }
    }

    /// Storniert einen Termin und laedt danach neu -- aus demselben Grund
    /// wie buchen(...). Faengt den Fehler ebenfalls nicht.
    func stornieren(sessionId: String) async throws(APIError) {
        _ = try await loader.cancelCourse(sessionId: sessionId)
        if let letzteAbfrage {
            await laden(studioId: letzteAbfrage.studioId, von: letzteAbfrage.von, bis: letzteAbfrage.bis)
        }
    }

    /// Nach dem Abmelden gehoeren die Buchungen dem vorigen Konto -- weder
    /// im Speicher noch auf der Platte darf davon etwas stehen bleiben.
    func reset() {
        woche = nil
        ladeZustand = .bereit
        eigene = nil
        buchungskennungen = [:]
        letzteAbfrage = nil
        fileStore.save(nil)
    }
}
