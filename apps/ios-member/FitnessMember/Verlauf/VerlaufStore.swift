import Foundation
import Observation

/// Was der Home-Tab vom Netz braucht -- eigene schmale Fassade, wie
/// `KurseLoading` und `BootstrapLoading`.
protocol VerlaufLoading: Sendable {
    func sessions(studio: String?) async throws(APIError) -> SessionsResponse
    func progress() async throws(APIError) -> [ExerciseProgress]
    func measurements() async throws(APIError) -> MeasurementsResponse
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
    private(set) var stand: Date?
    private(set) var ladeZustand: VerlaufLadeZustand = .bereit

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
        stand = nil
        ladeZustand = .bereit
        fileStore.save(nil)
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
        cacheMitMesswertenSchreiben()
    }

    /// Dieselbe Nachziehung wie messwertEintragen, fuer den Wisch-zum-
    /// Loeschen im Gewichtsverlauf.
    func messwertEntfernen(measuredOn: String) {
        messwerte.removeAll { $0.measuredOn == measuredOn }
        messwertKopfNachziehen()
        cacheMitMesswertenSchreiben()
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
    private func cacheMitMesswertenSchreiben() {
        guard let summary, let stand else { return }
        fileStore.save(
            GespeicherterVerlauf(
                stand: stand, sessions: sessions, summary: summary, fortschritt: fortschritt,
                messwerte: messwerte, messwertKopf: messwertKopf))
    }
}
