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
/// hier keinen Sinn ergibt, der Kurse-Bildschirm braucht eine andere.
enum KurseLadeZustand: Equatable {
    case bereit
    case laedt
    case geladen
    /// Traegt den tatsaechlichen `APIError`, nicht nur einen Marker: die
    /// Screens (ab Aufgabe 9) muessen `.offline` von einem Serverfehler
    /// unterscheiden koennen. "Offline" darf projektweit nie als
    /// "fehlgeschlagen" erscheinen (designsystem.md SS5 -- ein eigener,
    /// ehrlicher Satz statt eines Fehlschlags), waehrend ein Serverfehler
    /// (.validation, .server, ...) seinen Text woertlich zeigen soll. Mit
    /// einem blossen Marker war beides im View nicht mehr auseinanderzuhalten
    /// -- der urspruengliche `catch`-Zweig unten hat den gefangenen Fehler
    /// verworfen, statt ihn durchzureichen (Review-Fund Aufgabe 9).
    case fehlgeschlagen(APIError)
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

    /// Wann `woche` tatsaechlich vom Server kam. Die Gegenstelle zu
    /// `GespeicherteBuchungen.stand`, nur fuer den Speicher: `woche`
    /// enthaelt Belegungszahlen, und die veralten binnen Minuten (Spec
    /// 5.2). Ohne diesen Zeitpunkt koennte der Wochenplan nicht sagen, wie
    /// alt seine Zahlen sind -- er zeigte eine Zahl von vorhin, als waere
    /// sie aktuell, und genau das verbietet die Spec. Bewusst NICHT auf
    /// Platte: die Zahl selbst kommt dort ohnehin nie hin.
    private(set) var wocheStand: Date?

    /// Wie oft laden(...) tatsaechlich gelaufen ist -- existiert nur fuer
    /// KurseStoreTests.einErfolgreichesBuchenLaedtNeu, das beweisen muss,
    /// dass buchen(...) nach einem Erfolg selbst neu laedt. Keine
    /// Fachlogik greift hierauf zu.
    private(set) var ladeZaehler = 0

    /// Absichtlich nicht `private` in DEBUG-Bauten: KurseStoreTests
    /// programmiert nach der Store-Konstruktion das Ergebnis des jeweils
    /// naechsten courseWeek(...)-Aufrufs auf dem Fake (etwa fuer den
    /// Offline-Testfall) -- laden(...) selbst nimmt keinen CourseWeek als
    /// Parameter entgegen, es gibt also keinen anderen Weg, ihn von aussen
    /// zu erreichen. `loader` ist ein `let` ohne produktiven Aufrufer
    /// ausserhalb der Tests -- die Einschraenkung auf DEBUG haelt das im
    /// Release-Build trotzdem `private` und macht die Absicht im Code
    /// sichtbar, statt sie nur im Kommentar zu behaupten.
    #if DEBUG
    let loader: any KurseLoading
    #else
    private let loader: any KurseLoading
    #endif
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

    /// Steigt bei jedem laden(...)-Aufruf und bei reset(). Eine Antwort,
    /// die zurueckkommt, nachdem die Generation schon weitergezogen ist --
    /// weil ein juengerer laden(...)-Aufruf lief (zweimal kurz
    /// hintereinander "Aktualisieren") oder reset() das Konto gewechselt
    /// hat --, ist ueberholt und wird verworfen, statt einen frischeren
    /// oder kontofremden Zustand zu ueberschreiben.
    private var generation = 0

    init(loader: any KurseLoading, fileStore: KurseFileStore) {
        self.loader = loader
        self.fileStore = fileStore
        eigene = fileStore.load()
    }

    /// Laedt den Wochenplan eines Studios fuer das gegebene Fenster.
    ///
    /// Bei Erfolg werden die eigenen Buchungen aus der Antwort gebildet
    /// und persistiert. Bei Fehler bleiben `eigene` UND `woche`
    /// unangetastet -- der zuletzt geladene Stand traegt den Screen
    /// weiter, und `ladeZustand`/`wocheStand` sagen ihm, wie alt er ist
    /// (KurseHerkunft). Die Belegungszahlen blendet der Screen dann aus.
    func laden(studioId: String, von: Date, bis: Date) async {
        // Ein Wochenplan gehoert zu genau EINEM Studio. Wechselt es, ist
        // der alte Plan nicht "veraltet", sondern FALSCH -- falsche
        // Zeitzone, falsche Zuschreibung, und "Anmelden" buchte im alten
        // Studio. Das ist ein anderer Fall als "von vorhin", und
        // KurseHerkunft kann ihn nicht abfangen: sie datiert Daten, sie
        // erkennt keine vertauschten.
        //
        // Deshalb hier, vor dem Abruf, und an genau EINER Stelle -- der
        // Store ist der einzige Ort, der die vorige Studiokennung kennt.
        // Scheitert der neue Abruf, steht der Screen ohne Plan da (Karte
        // "Kein Empfang") statt mit dem des vorigen Studios. Auch das
        // `.laedt`-Fenster ist damit sauber: sonst stuenden dort die
        // Zahlen von Studio A unter dem Namen von Studio B.
        if let letzteAbfrage, letzteAbfrage.studioId != studioId {
            woche = nil
            wocheStand = nil
        }
        // Und dasselbe fuer die eigenen Buchungen -- nur haengt das nicht
        // an `letzteAbfrage`, sondern an der mitgespeicherten Kennung:
        // `letzteAbfrage` lebt nur so lange wie die App, `eigene` kommt
        // beim Kaltstart von der Platte. Ohne diese Pruefung zeigte
        // "Meine Kurse" nach einem Wechsel ohne Netz die Anmeldungen des
        // vorigen Studios -- und das Mitglied fuehre an den falschen Ort.
        //
        // Die Datei geht gleich mit weg. Sie gehoert einem Studio, das
        // hier nicht mehr gilt; sie fuer eine spaetere Rueckkehr
        // aufzuheben hiesse, zwei Staende zu fuehren, von denen der Screen
        // immer nur einen zeigen kann.
        if let vorhandene = eigene, vorhandene.studioId != studioId {
            eigene = nil
            fileStore.save(nil)
        }
        generation += 1
        let eigeneGeneration = generation
        ladeZaehler += 1
        ladeZustand = .laedt
        letzteAbfrage = (studioId, von, bis)
        let formatter = ISO8601DateFormatter()
        do {
            let neueWoche = try await loader.courseWeek(
                studio: studioId, from: formatter.string(from: von), to: formatter.string(from: bis))
            // Ueberholt, waehrend die Anfrage unterwegs war -- ein
            // juengerer Aufruf oder ein reset() ist inzwischen dran.
            // Diese Antwort darf den aktuelleren Zustand nicht mehr
            // ueberschreiben.
            guard eigeneGeneration == generation else { return }
            woche = neueWoche
            wocheStand = Date()
            // Nur die schmale, eigene Sicht darf auf Platte -- niemals die
            // volle CourseWeekSession mit den Belegungszahlen fremder
            // Termine (siehe GespeicherterTermin).
            let meineTermine = KursZustandRechner.meineKurse(aus: neueWoche).map(GespeicherterTermin.init)
            let neu = GespeicherteBuchungen(
                stand: Date(), studioId: studioId, termine: meineTermine,
                cancellationDeadlineHours: neueWoche.cancellationDeadlineHours,
                timezone: neueWoche.timezone)
            eigene = meineTermine.isEmpty ? nil : neu
            fileStore.save(eigene)
            ladeZustand = .geladen
        } catch {
            guard eigeneGeneration == generation else { return }
            // `woche` BLEIBT stehen. Frueher wurde sie hier genullt, und
            // der Wochenplan wich beim ersten Fehlversuch komplett der
            // Offline-Karte -- auch dann, wenn er einen vollstaendigen
            // Plan im Speicher hatte. Weggeworfen wurde damit auch, was
            // weiter stimmt: Name, Uhrzeit und Raum eines Termins aendern
            // sich nicht. Was nicht mehr stimmt, ist die Belegung, und die
            // blendet der Screen ueber KurseHerkunft.zeigtBelegung aus.
            //
            // Die Cache-Grenze bleibt davon unberuehrt: `woche` lag immer
            // schon fuer die Dauer der Sitzung im Speicher, auf die Platte
            // kommt weiterhin ausschliesslich GespeicherterTermin.
            //
            // `wocheStand` bleibt ebenfalls stehen -- er ist jetzt die
            // Altersangabe zu genau diesen Daten, nicht mehr bloss eine
            // Frischemarke.
            //
            // `error` ist hier bereits als APIError getippt (typed throws
            // von loader.courseWeek) -- durchreichen statt verwerfen, sonst
            // kann der View Offline nicht mehr von einem Serverfehler
            // unterscheiden (siehe KurseLadeZustand.fehlgeschlagen).
            ladeZustand = .fehlgeschlagen(error)
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
    ///
    /// EINE Ausnahme: `.decodingFailed`. APIClient wirft ihn ausschliesslich
    /// im 2xx-Zweig (APIClient.execute) -- der Server hat die Buchung also
    /// bereits angelegt, nur die Antwort liess sich nicht lesen. Das dem
    /// Mitglied als Fehlschlag zu melden waere der schlimmere der beiden
    /// Faelle aus APIError (eine gelungene Buchung als gescheitert
    /// auszugeben), deshalb wird NUR dieser eine Fall wie ein Erfolg
    /// behandelt: die Kennung gilt als verbraucht, es wird neu geladen.
    /// Nicht "aufraeumen" -- das ist Absicht, keine vergessene Fehlerpruefung.
    func buchen(sessionId: String) async throws(APIError) {
        let kennung = buchungskennungen[sessionId] ?? UUID()
        buchungskennungen[sessionId] = kennung
        do {
            _ = try await loader.bookCourse(sessionId: sessionId, bookingId: kennung)
        } catch APIError.decodingFailed {
            // Angekommen, nur unlesbar -- siehe Kommentar oben. Alle
            // anderen Fehler fliegen aus dem catch-Zweig unveraendert
            // weiter, weil sie hier nicht behandelt werden.
        }
        buchungskennungen[sessionId] = nil
        if let letzteAbfrage {
            await laden(studioId: letzteAbfrage.studioId, von: letzteAbfrage.von, bis: letzteAbfrage.bis)
        }
    }

    /// Storniert einen Termin und laedt danach neu -- aus demselben Grund
    /// wie buchen(...). Faengt den Fehler ebenfalls nicht.
    ///
    /// Dieselbe EINE Ausnahme wie bei buchen(...), mit derselben
    /// Begruendung: `.decodingFailed` wird ausschliesslich im 2xx-Zweig
    /// geworfen (APIClient.execute) -- die Stornierung ist beim Server
    /// also angekommen, nur die Antwort liess sich nicht lesen. Das dem
    /// Mitglied als Fehlschlag zu melden hiesse, es glaubt weiter
    /// angemeldet zu sein -- es erscheint nicht, oder storniert ein
    /// zweites Mal. Und der Platz, den jemand auf der Warteliste dadurch
    /// bekommen hat, ist da, ob der Screen es zugibt oder nicht. Deshalb
    /// wird NUR dieser eine Fall wie ein Erfolg behandelt: es wird neu
    /// geladen.
    ///
    /// Was hier sehr wohl aufgeraeumt wird, ist die Buchungskennung: eine
    /// Stornierung beendet die Buchung, zu der die Kennung gehoert, und
    /// eine spaetere Anmeldung ist fachlich eine NEUE Buchung. Bliebe die
    /// alte Kennung stehen, schickte die naechste Anmeldung dieselbe UUID,
    /// und der Server antwortete dauerhaft mit `booking_id_reused` -- der
    /// Kurs waere bis zum Neustart der App unbuchbar. Der Weg dorthin ist
    /// kurz: geht die Antwort auf ein Buchen verloren (Zeitueberschreitung,
    /// APIClient bildet sie auf .offline ab), verlaesst buchen(...) die
    /// Methode, bevor es die Kennung als verbraucht markiert -- gewollt,
    /// damit ein Wiederholer dieselbe Kennung schickt. Ueberlebt sie dann
    /// aber auch noch ein Stornieren, ist sie verbraucht, ohne dass es
    /// jemand weiss.
    ///
    /// Vor dem Netzaufruf, nicht danach: schlaegt cancelCourse fehl, ist
    /// die Buchung entweder noch da (dann erzeugt das naechste Buchen
    /// zwar eine frische Kennung, aber der Server antwortet ohnehin
    /// "schon gebucht") oder doch storniert (dann ist genau das richtig).
    /// Eine verworfene Kennung kostet nichts; eine verbrauchte, die
    /// stehen bleibt, kostet den Kurs.
    func stornieren(sessionId: String) async throws(APIError) {
        buchungskennungen[sessionId] = nil
        do {
            _ = try await loader.cancelCourse(sessionId: sessionId)
        } catch APIError.decodingFailed {
            // Angekommen, nur unlesbar -- siehe Kommentar oben. Alle
            // anderen Fehler fliegen aus dem catch-Zweig unveraendert
            // weiter, weil sie hier nicht behandelt werden.
        }
        if let letzteAbfrage {
            await laden(studioId: letzteAbfrage.studioId, von: letzteAbfrage.von, bis: letzteAbfrage.bis)
        }
    }

    /// Nach dem Abmelden gehoeren die Buchungen dem vorigen Konto -- weder
    /// im Speicher noch auf der Platte darf davon etwas stehen bleiben.
    func reset() {
        // Verwirft eine noch laufende Anfrage des VORIGEN Kontos: kommt
        // sie jetzt noch zurueck, ist ihre Generation nicht mehr die
        // aktuelle und laden(...) verwirft sie selbst (siehe dort).
        generation += 1
        woche = nil
        wocheStand = nil
        ladeZustand = .bereit
        eigene = nil
        buchungskennungen = [:]
        letzteAbfrage = nil
        fileStore.save(nil)
    }
}
