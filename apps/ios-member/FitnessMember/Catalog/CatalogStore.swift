import Foundation
import Observation

/// `APIClient` ist ein `actor` ohne Protokoll-Abstraktion (Aufgabe 5 begruendet
/// das mit YAGNI bei sechs bekannten Endpoints). Fuer `CatalogStore` wird
/// deshalb eine minimale Protokoll-Fassade nur fuer die hier gebrauchten zwei
/// Methoden ergaenzt -- die Deklaration gehoert hierher (nicht ins Testziel),
/// weil spaetere Aufgaben sie ebenfalls erweitern muessen.
protocol BootstrapLoading: Sendable {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet
    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult
    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult
    func leaveStudioMembership(studioId: String) async throws(APIError)
}

extension BootstrapLoading {
    func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap {
        GeladenerBootstrap(antwort: try await bootstrap(), rohdaten: nil)
    }
}

/// Der Bootstrap samt der Bytes, aus denen er kam -- die Bytes landen im
/// BootstrapFileStore (Offline-Spec 3a). nil bei Fakes ohne Netz.
struct GeladenerBootstrap: Sendable {
    let antwort: BootstrapResponse
    let rohdaten: Data?
}

extension APIClient: BootstrapLoading {}

/// Wo die App gerade arbeitet: in einem Studio oder im Freien Training
/// (ohne Studio, ohne feste Geraete).
enum Ort: Equatable, Sendable, Codable {
    case studio(String)
    case freiesTraining
}

/// @MainActor, weil CatalogStore -- wie SessionStore seit Aufgabe 12 -- ueber
/// @Environment direkt in SwiftUI-Views gelesen wird (ab Aufgabe 19); ohne
/// diese Isolation flaggt Swift 6 beim Aufruf von z. B. load() aus einem View
/// heraus einen "sending"-Fehler, weil die Klasse selbst nicht Sendable ist.
@MainActor
@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse? {
        didSet { bootstrapStand += 1 }
    }
    /// Zaehlt jede Zuweisung an `bootstrap` -- ein billiger Schluessel fuer
    /// Views, die daraus teuer ableiten (Geraetesuche, Offline-Spec 1b), statt
    /// den ganzen Bootstrap bei jedem Durchlauf auf Gleichheit zu pruefen.
    private(set) var bootstrapStand = 0
    private(set) var loadState: CatalogLoadState = .idle
    private(set) var pendingWrites: [PendingSetWrite]
    /// Der gewaehlte Ort. Ohne gespeicherte Wahl `.freiesTraining` als
    /// Platzhalter bis zum ersten `load()` -- `hatGewaehlt` unterscheidet das
    /// von einer echten Wahl, damit der erste Start das erste Studio nimmt.
    private(set) var ort: Ort
    private var hatGewaehlt: Bool

    /// Bleibt fuer alle Leser, die nur das Studio brauchen (Home, Kurse,
    /// Training ...); im Freien Training gibt es keins.
    var activeStudioId: String? {
        if case .studio(let id) = ort { id } else { nil }
    }

    /// Der Fehler des letzten gescheiterten Ladevorgangs, oder nil, solange
    /// der letzte gelungen ist.
    ///
    /// `loadState == .failed` sagt nur DASS, nicht WAS -- und bis zum
    /// 18. September sagte es nicht einmal das nach aussen weiter: der
    /// Fehler wurde hier gefangen und fiel dann ersatzlos weg. Ein
    /// Bildschirm, der den Ausfall benennen soll, braucht ihn aber. Kein
    /// eigener Zustandsfall an CatalogLoadState, weil der Fehler auch
    /// dann noch gilt, wenn `loadState` beim Neuladen ueber einem
    /// bestehenden Bootstrap auf `.loaded` stehen bleibt (siehe `load()`).
    private(set) var letzterLadefehler: APIError?

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

        /// Home und der Training-Tab (nach einem Aushang-Scan) sagen dasselbe.
        var text: String {
            beigetreten ? "Du gehörst jetzt zu \(studioName)." : "\(studioName) ist jetzt aktiv."
        }
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
    private let bootstrapFileStore: BootstrapFileStore?
    private let defaults: UserDefaults
    private let wiederholungsAbstand: Duration
    private var flushLaeuft = false
    /// Ein flushPending()-Aufruf kam, waehrend ein Flush lief.
    private var nochmal = false
    private var wiederholung: Task<Void, Never>?
    private let besitzerDatei: URL

    /// Wem die Warteschlange gehoert. Auf Platte neben ihr, weil sie ein
    /// Abmelden ueberlebt (Offline-Spec 4c): erst ein anderes Konto loescht sie.
    @ObservationIgnored
    private var warteschlangenBesitzer: String? {
        get { (try? String(contentsOf: besitzerDatei, encoding: .utf8)).flatMap { $0.isEmpty ? nil : $0 } }
        set {
            if let newValue { try? Data(newValue.utf8).write(to: besitzerDatei, options: .atomic) }
            else { try? FileManager.default.removeItem(at: besitzerDatei) }
        }
    }
    /// Wer angemeldet ist -- Schluessel fuer den Bootstrap-Cache und Besitzer
    /// der Warteschlange (Offline-Spec 3a, 4c).
    private(set) var userId: String?
    private static let ortDefaultsKey = "aktiverOrt"
    /// Nur noch zum einmaligen Uebernehmen alter Installationen gelesen.
    private static let alterStudioDefaultsKey = "activeStudioId"

    init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore,
         bootstrapFileStore: BootstrapFileStore? = nil, defaults: UserDefaults = .standard,
         wiederholungsAbstand: Duration = .seconds(30)) {
        self.loader = loader
        self.bootstrapFileStore = bootstrapFileStore
        self.pendingWriteStore = pendingWriteStore
        // Gleiches Verzeichnis wie pendingWriteStore, eigene Datei -- die
        // beiden Listen haben unterschiedliche Lebenszyklen (siehe
        // PendingWriteStore-Kommentar).
        self.verworfeneWriteStore = PendingWriteStore(directory: pendingWriteStore.directory, filename: "verworfene-writes.json")
        self.defaults = defaults
        self.wiederholungsAbstand = wiederholungsAbstand
        self.besitzerDatei = pendingWriteStore.directory.appendingPathComponent("warteschlange-besitzer.txt")
        pendingWrites = pendingWriteStore.loadAll()
        verworfeneWrites = verworfeneWriteStore.loadAll()
        if let data = defaults.data(forKey: Self.ortDefaultsKey),
           let gespeichert = try? JSONDecoder().decode(Ort.self, from: data) {
            ort = gespeichert
            hatGewaehlt = true
        } else if let alt = defaults.string(forKey: Self.alterStudioDefaultsKey) {
            // Migration: vor dem Freien Training gab es nur das Studio.
            ort = .studio(alt)
            hatGewaehlt = true
            defaults.removeObject(forKey: Self.alterStudioDefaultsKey)
            Self.speichere(ort, in: defaults)
        } else {
            ort = .freiesTraining
            hatGewaehlt = false
        }
    }

    private static func speichere(_ ort: Ort, in defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(ort) {
            defaults.set(data, forKey: ortDefaultsKey)
        }
    }

    /// Die Wurzel meldet hier, wer angemeldet ist -- vor dem ersten load().
    /// Ohne Bootstrap im Speicher kommt der gespeicherte sofort: die App
    /// startet im Keller nicht auf "NICHT GELADEN" (Offline-Spec 3a).
    /// Gibt zurueck, ob der Cache genutzt wurde -- dann laedt die Wurzel
    /// trotzdem frisch nach.
    @discardableResult
    func anmelden(userId: String) -> Bool {
        if let besitzer = warteschlangenBesitzer, besitzer != userId {
            // Saetze eines anderen Kontos -- mit diesem Token abgelehnt.
            pendingWrites = []
            pendingWriteStore.save([])
            verworfeneWrites = []
            verworfeneWriteStore.save([])
        }
        warteschlangenBesitzer = userId
        self.userId = userId
        guard bootstrap == nil, let gespeichert = bootstrapFileStore?.load(userId: userId) else { return false }
        bootstrap = gespeichert
        loadState = .loaded
        repariereOrt(studios: gespeichert.studios)
        return true
    }

    /// `.loading` nur beim ersten Laden: RootView zeigt dafuer den
    /// Ladebildschirm und baut danach `MainTabView` neu -- Tab zurueck auf
    /// Home, gepushte Screens weg. Seit Profilfelder, Ziele und die
    /// Nachholkarte nach jedem Schreiben neu laden, bleibt ein vorhandener
    /// Bootstrap waehrend des Neuladens stehen. Scheitert es, gilt der
    /// alte weiter: die Daten sind nur aelter, und ein Mitglied mit Studio
    /// soll nicht ploetzlich "Kein Studio" sehen (wie `VerlaufStore.laden`).
    func load() async {
        if bootstrap == nil { loadState = .loading }
        // `do throws(APIError)` statt `do`: der Typ im catch ist sonst nur
        // abgeleitet, und `letzterLadefehler` haengt daran. Derselbe Griff
        // wie in ProfilRootView, dort mit derselben Begruendung.
        // Wer fragt: eine Antwort, die nach Abmelden/Kontowechsel eintrifft,
        // gehoert einem anderen User und wird verworfen.
        let anfragendeUserId = userId
        do throws(APIError) {
            let geladen = try await loader.bootstrapMitRohdaten()
            guard userId == anfragendeUserId else { return }
            let response = geladen.antwort
            if let rohdaten = geladen.rohdaten, let userId {
                bootstrapFileStore?.save(rohdaten, userId: userId)
            }
            letzterLadefehler = nil
            bootstrap = response
            loadState = .loaded
            repariereOrt(studios: response.studios)
        } catch {
            guard userId == anfragendeUserId else { return }
            letzterLadefehler = error
            if bootstrap == nil { loadState = .failed }
        }
    }

    /// Ein Studio, das es nicht mehr gibt, faellt aufs erste Studio zurueck, ohne
    /// Studio auf das Freie Training; das Freie Training bleibt immer stehen.
    /// Ohne gespeicherte Wahl (erster Start) wird nichts festgeschrieben, wenn
    /// es kein Studio gibt -- sonst klebte der Platzhalter, sobald eins dazukommt.
    private func repariereOrt(studios: [BootstrapResponse.Studio]) {
        switch ort {
        case .freiesTraining:
            if !hatGewaehlt, let erstes = studios.first?.id { setOrt(.studio(erstes)) }
        case .studio(let id):
            if studios.contains(where: { $0.id == id }) { return }
            // Die Reparatur muss auch persistiert werden, sonst taucht der
            // veraltete Wert beim naechsten Start wieder aus UserDefaults auf.
            if let ersatz = studios.first?.id {
                setOrt(.studio(ersatz))
            } else {
                setOrt(.freiesTraining)
            }
        }
    }

    /// Nach dem Abmelden muss der gesamte Katalogzustand fallen: sonst sieht
    /// das naechste Konto auf demselben Geraet noch die Studios des vorigen,
    /// weil der Ladezustand nie wieder auf .idle zurueckfaellt.
    ///
    /// Die offenen Schreibvorgaenge bleiben -- sie gehoeren dem Konto (Besitzer)
    /// und gehen nach erneutem Anmelden desselben Kontos raus; ein anderes
    /// Konto loescht sie in `anmelden` (Offline-Spec 4c).
    func reset() {
        bootstrapFileStore?.loeschen()
        userId = nil
        bootstrap = nil
        loadState = .idle
        letzterLadefehler = nil
        ort = .freiesTraining
        hatGewaehlt = false
        defaults.removeObject(forKey: Self.ortDefaultsKey)
        defaults.removeObject(forKey: Self.alterStudioDefaultsKey)
        wiederholung?.cancel()
        wiederholung = nil
        // Sonst saehe das naechste Konto in derselben laufenden App noch
        // den Scan-Hinweis des vorigen Kontos -- derselbe Grund wie oben.
        studiohinweis = nil
    }

    func enqueue(_ write: PendingSetWrite) {
        pendingWrites.append(write)
        pendingWriteStore.save(pendingWrites)
    }

    func flushPending() async {
        // Nach dem Abmelden oder vor dem Anmelden: nicht mit fremdem Token senden.
        if let besitzer = warteschlangenBesitzer, besitzer != userId { return }
        // Laeuft schon ein Flush, nimmt er den neuen Satz in einem weiteren
        // Durchgang mit -- sonst wartete der Satz, den TrainingRootView
        // gerade eingereiht hat, bis zur 30-s-Wiederholung (Offline-Spec 4c).
        guard !flushLaeuft else { nochmal = true; return }
        flushLaeuft = true
        defer {
            flushLaeuft = false
            nochmal = false
            wiederholungPlanen()
        }
        while true {
            nochmal = false
            guard await flushDurchgang(), nochmal else { break }
        }
    }

    /// Ein Durchgang ueber eine frische Kopie von pendingWrites. false heisst:
    /// der ganze Flush hoert auf. Das gilt bei `.offline` -- ein
    /// Transportfehler trifft alle offenen Saetze, die sonst jeder einzeln in
    /// ihren 10-s-Timeout liefen; Wiederholung und Reconnect uebernehmen
    /// (Offline-Spec 2) -- und wenn der Besitzer nicht mehr passt.
    private func flushDurchgang() async -> Bool {
        for write in pendingWrites {
            // Erneut pruefen: schreibvorgaengeVerwerfen() kann waehrend eines
            // await hier dazwischengekommen sein -- die Schleife laeuft ueber
            // eine Kopie von pendingWrites, sonst sendet sie eine gerade
            // verworfene oder geloeschte Einheit doch noch an den Server.
            guard pendingWrites.contains(where: { $0.id == write.id }) else { continue }
            // Auch der Besitzer kann sich waehrend eines await geaendert haben
            // (Abmelden, Kontowechsel): dann nicht mit dem Token des anderen
            // Kontos weitersenden.
            if let besitzer = warteschlangenBesitzer, besitzer != userId { return false }
            do {
                _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
                entferneAusPendingWrites(write)
            } catch {
                if error == .offline { return false }
                // 401 ist hier voruebergehend: offline ohne gueltigen Token
                // (Offline-Spec 4c).
                if error.istDauerhaft && !error.istAnmeldefehler {
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
        return true
    }

    /// Bei halbem Netz meldet der Monitor "online", und der naechste Wechsel
    /// kommt vielleicht nie -- deshalb ein eigener Versuch nach
    /// `wiederholungsAbstand`, solange etwas offen ist (Offline-Spec 2).
    /// Hoechstens ein schlafender Task: ein laufender wird nicht ersetzt.
    private func wiederholungPlanen() {
        // Abgemeldet (Besitzer da, userId nil): kein Versuch ohne Token.
        let abgemeldet = userId == nil && warteschlangenBesitzer != nil
        guard !pendingWrites.isEmpty, !abgemeldet else {
            wiederholung?.cancel()
            wiederholung = nil
            return
        }
        guard wiederholung == nil else { return }
        wiederholung = Task { [weak self, wiederholungsAbstand] in
            try? await Task.sleep(for: wiederholungsAbstand)
            guard !Task.isCancelled, let self else { return }
            self.wiederholung = nil
            await self.flushPending()
        }
    }

    /// Nimmt einen einzelnen Eintrag aus pendingWrites -- Speicher und Platte
    /// zusammen, damit die beiden nie auseinanderlaufen (siehe flushPending).
    private func entferneAusPendingWrites(_ write: PendingSetWrite) {
        pendingWrites.removeAll { $0.id == write.id }
        pendingWriteStore.save(pendingWrites)
    }

    /// Die offenen Schreibvorgaenge einer verworfenen oder geloeschten Einheit
    /// (Sammelstelle Punkt 19): blieben sie liegen, legte der naechste
    /// Reconnect die Einheit beim Server wieder an. Speicher und Platte
    /// zusammen, wie ueberall hier.
    func schreibvorgaengeVerwerfen(sessionId: UUID) {
        pendingWrites.removeAll { $0.sessionId == sessionId }
        pendingWriteStore.save(pendingWrites)
    }

    /// Wie viele Saetze dieser Einheit den Server noch nicht erreicht haben --
    /// EinheitVerwerfen.weg entscheidet daran, ob ein DELETE noetig ist.
    func offeneSchreibvorgaenge(sessionId: UUID) -> Int {
        pendingWrites.filter { $0.sessionId == sessionId }.count
    }

    /// Nach dem Anzeigen quittiert der Screen die abgelehnten Vorgaenge.
    func verworfeneQuittieren() {
        verworfeneWrites = []
        verworfeneWriteStore.save([])
    }

    /// Wechseln ist reiner Client-Zustand -- "Tippen wechselt" (MemberStudios.dc.html)
    /// beschreibt keine Server-Aktion, sondern welcher Ort lokal gilt.
    ///
    /// `wechselMelden: false` wechselt ohne "ist jetzt aktiv" -- etwa nach
    /// einem Beitritt, dessen eigener Hinweis stehen bleiben soll.
    func setOrt(_ neu: Ort, wechselMelden: Bool = true) {
        let alt = ort
        ort = neu
        hatGewaehlt = true
        Self.speichere(neu, in: defaults)

        // "X ist jetzt aktiv" stimmt nach jedem Wechsel nicht mehr; "Du
        // gehoerst jetzt zu X" bleibt wahr, egal wo man trainiert.
        if alt != neu, studiohinweis?.beigetreten == false { studiohinweis = nil }
        if wechselMelden, case .studio(let alteId) = alt, case .studio(let id) = neu, alteId != id,
           let name = bootstrap?.studios.first(where: { $0.id == id })?.name {
            studiohinweis = Studiohinweis(studioName: name, beigetreten: false)
        }
    }

    /// Ein Beitritt macht zum Mitglied, wechselt aber nicht selbst den Ort:
    /// laeuft anderswo eine Einheit, muss erst "Training in X beenden?"
    /// kommen (Plan, Entscheidung 1 und 2). Den Wechsel macht der Aufrufer
    /// ueber `ortNachBeitritt`, nachdem Ortswechsel.pruefen ihn erlaubt.
    /// Die machineId reicht der Scanpfad weiter.
    @discardableResult
    func joinStudio(byCode code: String) async throws(APIError) -> JoinResult {
        let ergebnis = try await loader.joinStudioByCode(code)
        await nachBeitrittLaden(ergebnis)
        return ergebnis
    }

    @discardableResult
    func joinStudio(byTag token: String) async throws(APIError) -> JoinResult {
        let ergebnis = try await loader.joinStudioByTag(token)
        await nachBeitrittLaden(ergebnis)
        return ergebnis
    }

    private func nachBeitrittLaden(_ ergebnis: JoinResult) async {
        // Ohne gespeicherte Wahl naehme load() das erste Studio -- das waere
        // genau der stille Wechsel, den der Aufrufer erst pruefen soll.
        if !hatGewaehlt { setOrt(ort, wechselMelden: false) }
        await load()
        // Nur der Beitritt selbst: "ist jetzt aktiv" gilt erst nach dem Wechsel.
        if ergebnis.joined { merkeHinweis(fuer: ergebnis) }
    }

    /// Der Wechsel nach einem Beitritt, sobald er erlaubt ist (sofort oder
    /// nach "Training beenden"). Der Hinweis nennt den Beitritt, sonst den
    /// Wechsel.
    func ortNachBeitritt(_ ergebnis: JoinResult) {
        setOrt(.studio(ergebnis.studioId), wechselMelden: false)
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
