import Foundation
import Observation

/// `APIClient` ist ein `actor` ohne Protokoll-Abstraktion (Aufgabe 5 begruendet
/// das mit YAGNI bei sechs bekannten Endpoints). Fuer `CatalogStore` wird
/// deshalb eine minimale Protokoll-Fassade nur fuer die hier gebrauchten zwei
/// Methoden ergaenzt -- die Deklaration gehoert hierher (nicht ins Testziel),
/// weil spaetere Aufgaben sie ebenfalls erweitern muessen.
protocol BootstrapLoading: Sendable {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet
    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult
    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult
    func leaveStudioMembership(studioId: String) async throws(APIError)
}

extension APIClient: BootstrapLoading {}

/// @MainActor, weil CatalogStore -- wie SessionStore seit Aufgabe 12 -- ueber
/// @Environment direkt in SwiftUI-Views gelesen wird (ab Aufgabe 19); ohne
/// diese Isolation flaggt Swift 6 beim Aufruf von z. B. load() aus einem View
/// heraus einen "sending"-Fehler, weil die Klasse selbst nicht Sendable ist.
@MainActor
@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse?
    private(set) var loadState: CatalogLoadState = .idle
    private(set) var pendingWrites: [PendingSetWrite]
    private(set) var activeStudioId: String?

    /// Was auf Home ueber allem steht, nachdem ein Scan ein Studio
    /// hinzugefuegt oder gewechselt hat (Home.dc.html).
    ///
    /// Nur im Speicher: die Zeile ist die einmalige Folge eines Scans und
    /// soll beim naechsten Start weg sein -- deshalb eine Zeile und keine
    /// Karte mit Schliessen-Kreuz.
    struct Studiohinweis: Equatable {
        let studioName: String
        /// true = neu beigetreten, false = stillschweigend gewechselt.
        let beigetreten: Bool
    }

    /// Kein Wegraeum-Aufruf: der Hinweis lebt nur im Speicher und ist
    /// beim naechsten Start ohnehin weg. Ihn beim Tabwechsel zu loeschen
    /// hiesse, dass ihn verpasst, wer nach dem Scan zuerst ins Training
    /// schaut.
    private(set) var studiohinweis: Studiohinweis?

    /// Schreibvorgaenge, die der Server dauerhaft abgelehnt hat. Sie werden
    /// nicht wiederholt, verschwinden aber auch nicht stillschweigend --
    /// der Geraete-Screen zeigt sie an (designsystem.md SS5: Fehler sagen,
    /// was falsch ist und was gilt).
    ///
    /// Persistiert wie pendingWrites: flushPending() kann waehrend eines
    /// Hintergrund-Reconnects laufen, und wenn die App vor dem naechsten
    /// Screen-Aufruf beendet wird, waere ein rein speicherresidenter Eintrag
    /// so verloren wie der Schreibvorgang, den er dokumentieren soll.
    private(set) var verworfeneWrites: [PendingSetWrite]

    private let loader: any BootstrapLoading
    private let pendingWriteStore: PendingWriteStore
    private let verworfeneWriteStore: PendingWriteStore
    private let defaults: UserDefaults
    private static let activeStudioDefaultsKey = "activeStudioId"

    init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore, defaults: UserDefaults = .standard) {
        self.loader = loader
        self.pendingWriteStore = pendingWriteStore
        // Gleiches Verzeichnis wie pendingWriteStore, eigene Datei -- die
        // beiden Listen haben unterschiedliche Lebenszyklen (siehe
        // PendingWriteStore-Kommentar).
        self.verworfeneWriteStore = PendingWriteStore(directory: pendingWriteStore.directory, filename: "verworfene-writes.json")
        self.defaults = defaults
        pendingWrites = pendingWriteStore.loadAll()
        verworfeneWrites = verworfeneWriteStore.loadAll()
        activeStudioId = defaults.string(forKey: Self.activeStudioDefaultsKey)
    }

    func load() async {
        loadState = .loading
        do {
            let response = try await loader.bootstrap()
            bootstrap = response
            loadState = .loaded(hasStudio: !response.studios.isEmpty)
            if activeStudioId == nil || !response.studios.contains(where: { $0.id == activeStudioId }) {
                // Die Reparatur muss auch persistiert werden, sonst taucht der
                // veraltete Wert beim naechsten Start wieder aus UserDefaults auf.
                if let ersatz = response.studios.first?.id {
                    setActiveStudio(ersatz)
                } else {
                    activeStudioId = nil
                    defaults.removeObject(forKey: Self.activeStudioDefaultsKey)
                }
            }
        } catch {
            loadState = .failed
        }
    }

    /// Nach dem Abmelden muss der gesamte Katalogzustand fallen: sonst sieht
    /// das naechste Konto auf demselben Geraet noch die Studios des vorigen,
    /// weil der Ladezustand nie wieder auf .idle zurueckfaellt.
    ///
    /// Die offenen Schreibvorgaenge werden bewusst mitgeloescht -- sie tragen
    /// Session- und Set-IDs, die zum abgemeldeten Konto gehoeren und nach einem
    /// Kontowechsel serverseitig ohnehin abgelehnt wuerden.
    func reset() {
        bootstrap = nil
        loadState = .idle
        activeStudioId = nil
        defaults.removeObject(forKey: Self.activeStudioDefaultsKey)
        pendingWrites = []
        pendingWriteStore.save([])
        verworfeneWrites = []
        verworfeneWriteStore.save([])
        // Sonst saehe das naechste Konto in derselben laufenden App noch
        // den Scan-Hinweis des vorigen Kontos -- derselbe Grund wie oben.
        studiohinweis = nil
    }

    func enqueue(_ write: PendingSetWrite) {
        pendingWrites.append(write)
        pendingWriteStore.save(pendingWrites)
    }

    func flushPending() async {
        for write in pendingWrites {
            do {
                _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
                entferneAusPendingWrites(write)
            } catch {
                if error.istDauerhaft {
                    // Beide Listen sofort sichern, nicht erst am Schleifenende:
                    // flushPending() laeuft oft auf einen Hintergrund-Reconnect
                    // hin, und ein Kill der App mittendrin darf den Eintrag
                    // weder verlieren noch doppelt verworfen wiederfinden --
                    // beides braucht die Platte auf demselben Stand wie den
                    // Speicher, bevor die Schleife weiterlaeuft.
                    verworfeneWrites.append(write)
                    verworfeneWriteStore.save(verworfeneWrites)
                    entferneAusPendingWrites(write)
                }
                // Voruebergehende Fehler: der Eintrag bleibt fuer den
                // naechsten Versuch in pendingWrites/pendingWriteStore stehen.
            }
        }
    }

    /// Nimmt einen einzelnen Eintrag aus pendingWrites -- Speicher und Platte
    /// zusammen, damit die beiden nie auseinanderlaufen (siehe flushPending).
    private func entferneAusPendingWrites(_ write: PendingSetWrite) {
        pendingWrites.removeAll { $0.id == write.id }
        pendingWriteStore.save(pendingWrites)
    }

    /// Nach dem Anzeigen quittiert der Screen die abgelehnten Vorgaenge.
    func verworfeneQuittieren() {
        verworfeneWrites = []
        verworfeneWriteStore.save([])
    }

    /// Wechseln ist reiner Client-Zustand -- "Tippen wechselt" (MemberStudios.dc.html)
    /// beschreibt keine Server-Aktion, sondern welches Studio lokal angezeigt wird.
    func setActiveStudio(_ id: String) {
        let wechsel = activeStudioId != nil && activeStudioId != id
        activeStudioId = id
        defaults.set(id, forKey: Self.activeStudioDefaultsKey)

        if wechsel, let name = bootstrap?.studios.first(where: { $0.id == id })?.name {
            studiohinweis = Studiohinweis(studioName: name, beigetreten: false)
        }
    }

    func joinStudio(byCode code: String) async throws(APIError) {
        let ergebnis = try await loader.joinStudioByCode(code)
        await load()
        merkeHinweis(fuer: ergebnis)
    }

    func joinStudio(byTag token: String) async throws(APIError) {
        let ergebnis = try await loader.joinStudioByTag(token)
        await load()
        merkeHinweis(fuer: ergebnis)
    }

    private func merkeHinweis(fuer ergebnis: JoinResult) {
        guard let name = bootstrap?.studios.first(where: { $0.id == ergebnis.studioId })?.name
        else { return }
        studiohinweis = Studiohinweis(studioName: name, beigetreten: ergebnis.joined)
    }

    func leaveStudio(_ studioId: String) async throws(APIError) {
        try await loader.leaveStudioMembership(studioId: studioId)
        await load()
    }
}
