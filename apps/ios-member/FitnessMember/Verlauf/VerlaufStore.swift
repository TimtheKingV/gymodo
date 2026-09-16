import Foundation
import Observation

/// Was der Home-Tab vom Netz braucht -- eigene schmale Fassade, wie
/// `KurseLoading` und `BootstrapLoading`.
protocol VerlaufLoading: Sendable {
    func sessions(studio: String?) async throws(APIError) -> SessionsResponse
    func progress() async throws(APIError) -> [ExerciseProgress]
    func measurements() async throws(APIError) -> MeasurementsResponse
    /// Aufgabe 10 (Ruling R27): der EINE Schreibweg eines Gewichtseintrags
    /// braucht den Schreibzugriff auf demselben Protokoll wie die drei
    /// Lesezugriffe oben, statt `APIClient` an `gewichtSpeichern`
    /// vorbeizureichen -- `VerlaufStore` haelt ohnehin schon `loader`.
    func putMeasurement(_ body: MesswertWrite) async throws(APIError) -> MesswertAntwort
}

extension APIClient: VerlaufLoading {}

/// Haelt Verlauf, Kopfzeile und Fortschritt -- und den Zeitpunkt, an dem
/// sie zuletzt wirklich vom Server kamen.
///
/// @MainActor wie CatalogStore und KurseStore: der Store wird ueber
/// @Environment direkt in Views gelesen.
@MainActor
@Observable
final class VerlaufStore {
    private(set) var sessions: [SessionSummary] = []
    private(set) var summary: SessionsSummary?
    private(set) var fortschritt: [ExerciseProgress] = []
    /// Aufsteigend nach `measuredOn`, wie vom Server geliefert und wie
    /// `messwertEintragen` sie nachzieht.
    private(set) var messwerte: [Messwert] = []
    private(set) var messwertKopf: MeasurementsResponse.Summary?
    /// Der einmalige "Ziel erreicht"-Moment fuer das Gewicht (Aufgabe 8,
    /// Brief Entscheidung 2). `BootstrapResponse.Member.goals` kennt nur
    /// AKTIVE Ziele -- ein erreichtes Zielgewicht steht dort als `null`,
    /// weil das Ziel dabei abgeschlossen wird. Diese Zeile lebt deshalb
    /// ausschliesslich im Speicher, ausgeloest durch die Antwort von
    /// `putMeasurement` (`goalReached`, Aufgabe 9), und verschwindet beim
    /// naechsten Appstart oder sobald ein neues Zielgewicht gesetzt wird
    /// (Aufgabe 10, `neuesZielgewichtGesetzt`) -- bewusst NICHT Teil von
    /// `GespeicherterVerlauf`. Das ist der Preis dafuer, keinen eigenen
    /// Endpoint "zuletzt erreichte Ziele" zu bauen, statt ihn ungefragt zu
    /// erfinden.
    private(set) var erreichtesZielgewicht: ErreichtesZielgewicht?
    private(set) var stand: Date?
    private(set) var ladeZustand: VerlaufLadeZustand = .bereit

    struct ErreichtesZielgewicht: Equatable, Sendable {
        let weightKg: Double
        let measuredOn: String
    }

    var herkunft: VerlaufHerkunft { VerlaufHerkunft.bilden(ladeZustand: ladeZustand) }

    /// Der Satz ueber dem ganzen Screen, nicht ueber einer einzelnen
    /// Zahl: ohne Netz driften "diese Woche" und "Tage her" mit der Uhr,
    /// waehrend die Liste darunter richtig bleibt. Ein datierter Screen
    /// ist ehrlicher als eine still wandernde Zahl.
    var satzUeberDemInhalt: String? { herkunft.satz(stand: stand) }

    #if DEBUG
    let loader: any VerlaufLoading
    #else
    private let loader: any VerlaufLoading
    #endif
    private let fileStore: VerlaufFileStore

    /// Steigt bei jedem laden(...) und bei reset(). Eine Antwort, die
    /// zurueckkommt, nachdem die Generation weitergezogen ist, ist
    /// ueberholt und wird verworfen -- sonst ueberschriebe sie einen
    /// frischeren oder kontofremden Zustand.
    private var generation = 0

    init(loader: any VerlaufLoading, fileStore: VerlaufFileStore) {
        self.loader = loader
        self.fileStore = fileStore

        if let gespeichert = fileStore.load() {
            sessions = gespeichert.sessions
            summary = gespeichert.summary
            fortschritt = gespeichert.fortschritt
            stand = gespeichert.stand
            // Optional, weil ein Cache von vor dieser Fassung diese
            // beiden Felder nicht kennt.
            messwerte = gespeichert.messwerte ?? []
            messwertKopf = gespeichert.messwertKopf
        }
    }

    /// Laedt Verlauf, Fortschritt und Messwerte. Scheitert einer der drei
    /// Abrufe, bleibt der bisherige Stand vollstaendig stehen -- er ist
    /// nicht falsch geworden, nur aelter.
    func laden(studioId: String?) async {
        generation += 1
        let eigene = generation
        ladeZustand = .laedt

        do {
            // Nacheinander statt nebenlaeufig: drei kleine Abrufe, und
            // `async let` gaebe den getippten APIError als `any Error`
            // zurueck -- der Unterschied offline/Serverfehler ginge dabei
            // verloren, und genau der traegt den Satz oben.
            let antwort = try await loader.sessions(studio: studioId)
            let punkte = try await loader.progress()
            let messwerteAntwort = try await loader.measurements()
            guard eigene == generation else { return }

            let jetzt = Date()
            sessions = antwort.sessions
            summary = antwort.summary
            fortschritt = punkte
            messwerte = messwerteAntwort.points
            messwertKopf = messwerteAntwort.summary
            stand = jetzt
            ladeZustand = .geladen
            fileStore.save(
                GespeicherterVerlauf(
                    stand: jetzt, sessions: antwort.sessions, summary: antwort.summary,
                    fortschritt: punkte, messwerte: messwerteAntwort.points,
                    messwertKopf: messwerteAntwort.summary))
        } catch {
            guard eigene == generation else { return }
            ladeZustand = .fehlgeschlagen(error)
        }
    }

    /// Nach dem Abmelden: sonst saehe das naechste Konto auf demselben
    /// Geraet den Verlauf und die Koerperdaten des vorigen.
    func reset() {
        generation += 1
        sessions = []
        summary = nil
        fortschritt = []
        messwerte = []
        messwertKopf = nil
        erreichtesZielgewicht = nil
        stand = nil
        ladeZustand = .bereit
        fileStore.save(nil)
    }

    /// Aufgabe 9 ruft dies nach einer `putMeasurement`-Antwort mit
    /// `goalReached == true` auf.
    func zielgewichtErreicht(_ wert: ErreichtesZielgewicht) {
        erreichtesZielgewicht = wert
    }

    /// Aufgabe 10 ruft dies auf, sobald ein neues Zielgewicht gesetzt
    /// wird -- die alte Zeile gehoert zum alten Ziel und darf das neue
    /// nicht ueberdauern.
    func neuesZielgewichtGesetzt() {
        erreichtesZielgewicht = nil
    }

    /// Ruling R27: DER eine Schreibweg eines Gewichtseintrags -- Home
    /// (`HomeRootView.eintragenSpeichern`), der Gewichtsverlauf
    /// (`GewichtsverlaufView.gewichtSpeichern`) und das Profil (Aufgabe 9
    /// bzw. 10) riefen dieselben vier Zeilen bisher an zwei bzw. drei
    /// Stellen auf. Eine dritte Kopie waere genau die Invariante, die als
    /// naechstes auseinanderlaeuft (derselbe Befund wie im Kommentar zu
    /// `Rastwerte.amAnschlag`).
    ///
    /// `katalogNeuLaden` bleibt eine Closure statt eines gespeicherten
    /// `CatalogStore`: `VerlaufStore` kennt sonst keinen zweiten Store,
    /// und nur `goalReached` braucht ihn ueberhaupt (das Zielgewicht ist
    /// serverseitig abgeschlossen und steht danach nicht mehr unter den
    /// aktiven Zielen).
    func gewichtSpeichern(_ body: MesswertWrite, katalogNeuLaden: () async -> Void) async -> String? {
        do throws(APIError) {
            let antwort = try await loader.putMeasurement(body)
            messwertEintragen(antwort)
            if antwort.goalReached {
                zielgewichtErreicht(.init(weightKg: antwort.weightKg, measuredOn: antwort.measuredOn))
                await katalogNeuLaden()
            }
            return nil
        } catch {
            guard error != .offline else {
                return "Keine Verbindung. Das Gewicht wurde nicht gespeichert."
            }
            return error.servertext
        }
    }

    /// Zieht den lokalen Stand sofort nach, statt auf den naechsten
    /// Abruf zu warten -- die Gewichtskarte auf Home soll nach
    /// "Eintragen" sofort den neuen Wert zeigen. Ersetzt einen
    /// bestehenden Punkt desselben Tages statt ihn zu verdoppeln, wie
    /// der Upsert im Server.
    func messwertEintragen(_ antwort: MesswertAntwort) {
        let punkt = Messwert(measuredOn: antwort.measuredOn, weightKg: antwort.weightKg)
        messwerte.removeAll { $0.measuredOn == punkt.measuredOn }
        messwerte.append(punkt)
        messwerte.sort { $0.measuredOn < $1.measuredOn }
        messwertKopfNachziehen()
        cacheSchreiben()
    }

    /// Dieselbe Nachziehung wie messwertEintragen, fuer den Wisch-zum-
    /// Loeschen im Gewichtsverlauf.
    func messwertEntfernen(measuredOn: String) {
        messwerte.removeAll { $0.measuredOn == measuredOn }
        messwertKopfNachziehen()
        cacheSchreiben()
    }

    /// Nach dem Loeschen einer Einheit (Sammelstelle Punkt 19): die Liste
    /// sofort ohne sie, die Kopfzeile erst mit dem naechsten Abruf --
    /// Gesamtzahl, Woche und Serie rechnet der Server, und eine lokal
    /// heruntergezaehlte Serie waere eine zweite Regel neben serie.ts.
    func einheitEntfernen(id: String) {
        sessions.removeAll { $0.id == id }
        cacheSchreiben()
    }

    /// Spiegelt dieselbe Rechnung wie `getMeasurements` im Server
    /// (first/latest/changeKg aus den Punkten) -- keine zweite Regel,
    /// nur die Ueberbrueckung bis zum naechsten Abruf.
    private func messwertKopfNachziehen() {
        let erster = messwerte.first
        let letzter = messwerte.last
        messwertKopf = MeasurementsResponse.Summary(
            first: erster, latest: letzter,
            changeKg: erster.flatMap { e in
                letzter.map { l in ((l.weightKg - e.weightKg) * 10).rounded() / 10 }
            })
    }

    /// Nur, wenn schon einmal vollstaendig geladen wurde -- ohne
    /// `summary`/`stand` gibt es noch keinen vollstaendigen
    /// `GespeicherterVerlauf` zu schreiben, und die In-Memory-Werte oben
    /// reichen der Home-Karte bis zum naechsten Abruf.
    private func cacheSchreiben() {
        guard let summary, let stand else { return }
        fileStore.save(
            GespeicherterVerlauf(
                stand: stand, sessions: sessions, summary: summary, fortschritt: fortschritt,
                messwerte: messwerte, messwertKopf: messwertKopf))
    }
}
