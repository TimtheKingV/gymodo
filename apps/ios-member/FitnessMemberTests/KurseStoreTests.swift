import Foundation
import Testing
@testable import FitnessMember

/// Nach dem Muster von FakeBootstrapLoader (CatalogStoreTests). Ein actor,
/// weil KurseLoading Sendable ist und die Testfaelle das Ergebnis
/// asynchron programmieren, bevor sie den Store aufrufen.
actor FakeKurseLoader: KurseLoading {
    enum WocheResultat { case success(CourseWeek), failure(APIError) }
    enum BuchenResultat { case success(BookOutcome), failure(APIError) }
    enum StornierenResultat { case success(CancelOutcome), failure(APIError) }

    /// Standardmaessig .offline wie bei FakeBootstrapLoader -- jeder Test,
    /// der einen Wochenplan braucht, programmiert ihn ueber lade(_:mit:)
    /// oder setWoche(_:) explizit.
    private var wocheResultat: WocheResultat = .failure(.offline)
    /// Buchen und Stornieren sind, anders als der Wochenplan, standardmaessig
    /// erfolgreich -- die Tests dieser Aufgabe pruefen die Store-Logik
    /// rund um das Neuladen, nicht den Fehlerfall des Buchens selbst.
    private var buchenResultat: BuchenResultat = .success(
        BookOutcome(result: "booked", created: true, bookingId: UUID().uuidString, waitlistPosition: nil, freeSeats: 5))
    private var stornierenResultat: StornierenResultat = .success(CancelOutcome(promoted: false))

    func setWoche(_ resultat: WocheResultat) { wocheResultat = resultat }
    func setBuchen(_ resultat: BuchenResultat) { buchenResultat = resultat }
    func setStornieren(_ resultat: StornierenResultat) { stornierenResultat = resultat }

    /// Fuer den Beweis, dass eine ueberholende Antwort nicht gewinnt:
    /// haelt genau den naechsten courseWeek(...)-Aufruf an, bis
    /// freigeben() gerufen wird -- ein einmaliger Schalter, nicht jeder
    /// folgende Aufruf haengt.
    private var haeltDenNaechstenAufruf = false
    private var wartendeAntwort: CheckedContinuation<Void, Never>?
    private var angekommenSignal: CheckedContinuation<Void, Never>?

    func haltenBisFreigabe() { haeltDenNaechstenAufruf = true }

    /// Wartet, bis der gehaltene Aufruf tatsaechlich an der Haltestelle
    /// angekommen ist -- sonst waere die Reihenfolge im Test selbst nicht
    /// garantiert, sondern nur ein Zufallstreffer.
    func wartenBisAngekommen() async {
        if wartendeAntwort != nil { return }
        await withCheckedContinuation { continuation in angekommenSignal = continuation }
    }

    func freigeben() {
        wartendeAntwort?.resume()
        wartendeAntwort = nil
    }

    func courseWeek(studio: String, from: String, to: String) async throws(APIError) -> CourseWeek {
        if haeltDenNaechstenAufruf {
            haeltDenNaechstenAufruf = false
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                wartendeAntwort = continuation
                angekommenSignal?.resume()
                angekommenSignal = nil
            }
        }
        switch wocheResultat {
        case .success(let woche): return woche
        case .failure(let error): throw error
        }
    }

    /// Jede Kennung, die tatsaechlich rausging -- in der Reihenfolge der
    /// Aufrufe. Der Server kennt eine verbrauchte Kennung dauerhaft
    /// (booking_id_reused, 0038_kurse_nachlese.sql), der Test muss die
    /// Wiederverwendung also am Aufruf pruefen, nicht am Ergebnis.
    private(set) var gesendeteKennungen: [UUID] = []

    func bookCourse(sessionId: String, bookingId: UUID) async throws(APIError) -> BookOutcome {
        gesendeteKennungen.append(bookingId)
        switch buchenResultat {
        case .success(let outcome): return outcome
        case .failure(let error): throw error
        }
    }

    func cancelCourse(sessionId: String) async throws(APIError) -> CancelOutcome {
        switch stornierenResultat {
        case .success(let outcome): return outcome
        case .failure(let error): throw error
        }
    }
}

/// @MainActor, weil KurseStore selbst @MainActor ist -- die Suite laeuft
/// deshalb auf demselben Actor wie die getestete Klasse.
@MainActor
struct KurseStoreTests {
    /// Ein frisches Verzeichnis je Test, und ein Store, dessen Loader ueber
    /// `sut.loader` (bewusst nicht `private`, siehe KurseStore) von
    /// lade(_:mit:) erreichbar bleibt -- laden(...) selbst nimmt keinen
    /// CourseWeek entgegen, das Ergebnis muss also vorher auf dem Fake
    /// programmiert werden.
    private func store() -> (sut: KurseStore, verzeichnis: URL) {
        let verzeichnis = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sut = KurseStore(loader: FakeKurseLoader(), fileStore: KurseFileStore(directory: verzeichnis))
        return (sut, verzeichnis)
    }

    /// Programmiert den naechsten courseWeek(...)-Aufruf auf dem Loader des
    /// uebergebenen Stores mit `woche` und laedt dann tatsaechlich.
    private func lade(_ sut: KurseStore, mit woche: CourseWeek) async {
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        await loader.setWoche(.success(woche))
        await sut.laden(studioId: "s1", von: Date(timeIntervalSince1970: 0), bis: Date(timeIntervalSince1970: 0))
    }

    @Test func speichertNurDieEigenenBuchungen() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked", nil, nil, "waitlisted"]))

        let aufPlatte = KurseFileStore(directory: verzeichnis).load()

        // Vier Termine kamen, zwei gehoeren dem Mitglied.
        #expect(aufPlatte?.termine.count == 2)
        #expect(aufPlatte?.termine.allSatisfy { $0.ownStatus != nil } == true)
    }

    @Test func speichertKeineBelegungszahlenFremderTermine() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil, nil]))

        let aufPlatte = KurseFileStore(directory: verzeichnis).load()

        // Ohne eigene Buchung liegt nichts auf Platte -- eine
        // Belegungszahl von vorhin ist keine Information, die wir offline
        // zeigen duerfen.
        #expect(aufPlatte?.termine.isEmpty ?? true)
    }

    @Test func eigeneBuchungenUeberstehenEinenNeustart() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = KurseStore(loader: FakeKurseLoader(),
                                    fileStore: KurseFileStore(directory: verzeichnis))
        await lade(ersterLauf, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        let zweiterLauf = KurseStore(loader: FakeKurseLoader(),
                                     fileStore: KurseFileStore(directory: verzeichnis))

        #expect(zweiterLauf.eigene?.termine.count == 1)
    }

    @Test func ohneNetzBleibenDieEigenenBuchungenStehenUndDerPlanFehlt() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = KurseStore(loader: FakeKurseLoader(),
                                    fileStore: KurseFileStore(directory: verzeichnis))
        await lade(ersterLauf, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        let loader = FakeKurseLoader()
        await loader.setWoche(.failure(.offline))
        let zweiterLauf = KurseStore(loader: loader,
                                     fileStore: KurseFileStore(directory: verzeichnis))
        await zweiterLauf.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(zweiterLauf.woche == nil)          // kein Wochenplan
        #expect(zweiterLauf.eigene?.termine.count == 1)  // aber meine Kurse
    }

    // Review-Fund zu Aufgabe 9: laden(...) hat den gefangenen APIError
    // verworfen und nur einen bedeutungslosen ".fehlgeschlagen"-Marker
    // gesetzt -- der View konnte dann Offline nicht mehr von einem
    // Serverfehler unterscheiden. Die beiden folgenden Tests beweisen, dass
    // der TATSAECHLICHE Fehler jetzt ankommt, nicht nur seine Existenz.
    @Test func einServerfehlerWirdMitSeinemTextDurchgereicht() async {
        let (sut, _) = store()
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        await loader.setWoche(.failure(.validation(message: "Zeitraum ungueltig")))

        await sut.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(sut.ladeZustand == .fehlgeschlagen(.validation(message: "Zeitraum ungueltig")))
    }

    @Test func offlineBleibtVonEinemServerfehlerUnterscheidbar() async {
        let (sut, _) = store()
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        await loader.setWoche(.failure(.offline))

        await sut.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(sut.ladeZustand == .fehlgeschlagen(.offline))
        // Und ausdruecklich NICHT gleich einem Serverfehler -- das ist der
        // eigentliche Zweck der Nutzlast.
        #expect(sut.ladeZustand != .fehlgeschlagen(.server(message: "irrelevant")))
    }

    @Test func einErfolgreichesBuchenLaedtNeu() async {
        // Sonst zeigte der Screen nach dem Anmelden weiter "Anmelden".
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil]))

        try? await sut.buchen(sessionId: "k0")

        #expect(sut.ladeZaehler == 2)
    }

    @Test func resetRaeumtSpeicherUndPlatte() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        sut.reset()

        // Nach dem Abmelden gehoeren die Buchungen dem vorigen Konto.
        #expect(sut.eigene == nil)
        #expect(KurseFileStore(directory: verzeichnis).load()?.termine.isEmpty ?? true)
        // Seit ein Fehlversuch den Plan stehen laesst, ist reset() der
        // einzige Ort, der ihn UND seine Altersangabe raeumt -- sonst
        // saehe das naechste Konto den Plan des vorigen.
        #expect(sut.woche == nil)
        #expect(sut.wocheStand == nil)
        #expect(sut.ladeZustand == .bereit)
    }

    /// Ein Wochenplan gehoert zu genau EINEM Studio. Scheitert der Abruf
    /// nach einem Wechsel, stuende sonst der Plan des vorigen Studios
    /// unter dem Namen des neuen: falsche Zeitzone, falsche Zuschreibung
    /// -- und "Anmelden" buchte im alten Studio.
    @Test func einStudiowechselWirftDenPlanDesVorigenStudiosWeg() async {
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked", nil]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        #expect(sut.woche != nil)

        await loader.setWoche(.failure(.offline))
        await sut.laden(studioId: "s2", von: Date(), bis: Date())

        #expect(sut.woche == nil)
        #expect(sut.wocheStand == nil)
        #expect(sut.ladeZustand == .fehlgeschlagen(.offline))
    }

    /// Die Gegenprobe zum Wechsel: DASSELBE Studio laesst den Plan stehen
    /// -- das ist der Fall, den "veraltet, aber nicht falsch" abdeckt.
    @Test func einFehlversuchImSELBENStudioLaesstDenPlanStehen() async {
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }

        await loader.setWoche(.failure(.offline))
        await sut.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(sut.woche != nil)
    }

    /// Der Weg, um den es geht: unter Studio A gebucht, Studio gewechselt,
    /// ohne Netz geladen. "Meine Kurse" darf nichts von A zeigen -- das
    /// Mitglied fuehre sonst an den falschen Ort. Anders als beim
    /// Wochenplan haengt das an der mitgespeicherten Kennung, nicht an
    /// letzteAbfrage.
    @Test func einStudiowechselWirftAuchDieEigenenBuchungenWeg() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        #expect(sut.eigene?.termine.isEmpty == false)

        await loader.setWoche(.failure(.offline))
        await sut.laden(studioId: "s2", von: Date(), bis: Date())

        #expect(sut.eigene == nil)
        // Auch von der Platte -- sonst kaeme der falsche Stand beim
        // naechsten Start zurueck.
        #expect(KurseFileStore(directory: verzeichnis).load() == nil)
    }

    /// Und derselbe Weg ueber einen KALTSTART: die Datei kommt von der
    /// Platte, `letzteAbfrage` ist leer. Genau der Fall, den eine reine
    /// Speicherpruefung nicht erkennen koennte.
    @Test func nachEinemNeustartMitAnderemStudioBleibtNichtsVomVorigen() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = KurseStore(loader: FakeKurseLoader(),
                                    fileStore: KurseFileStore(directory: verzeichnis))
        await lade(ersterLauf, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        let loader = FakeKurseLoader()
        await loader.setWoche(.failure(.offline))
        let zweiterLauf = KurseStore(loader: loader,
                                     fileStore: KurseFileStore(directory: verzeichnis))
        // Von der Platte ist der Stand zunaechst da ...
        #expect(zweiterLauf.eigene?.termine.count == 1)

        // ... und faellt beim ersten Laden fuer ein anderes Studio weg.
        await zweiterLauf.laden(studioId: "s2", von: Date(), bis: Date())

        #expect(zweiterLauf.eigene == nil)
    }

    /// Die Gegenprobe: DASSELBE Studio behaelt seinen Cache, auch wenn
    /// der Abruf scheitert. Das ist der Fall, fuer den der Cache da ist.
    @Test func einFehlversuchImSELBENStudioLaesstDieEigenenBuchungenStehen() async {
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }

        await loader.setWoche(.failure(.offline))
        await sut.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(sut.eigene?.termine.count == 1)
    }

    /// Ein Bestand aus der Zeit vor `studioId` laesst sich nicht mehr
    /// decodieren und gilt als leerer Cache -- kein Absturz, kein stiller
    /// Weiterbetrieb mit Buchungen ohne Zuordnung.
    @Test func eineDateiOhneStudiokennungGiltAlsLeererCache() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: verzeichnis, withIntermediateDirectories: true)
        // Das alte Format, woertlich: alles ausser studioId.
        let alt = """
        {"stand":0,"termine":[],"cancellationDeadlineHours":2,"timezone":"Europe/Berlin"}
        """
        try? Data(alt.utf8).write(to: verzeichnis.appendingPathComponent("eigene-kurse.json"))

        #expect(KurseFileStore(directory: verzeichnis).load() == nil)
    }

    // Die Grenze auf Feldebene: ein Test gegen die getippte Struktur
    // wuerde ein spaeter wiederhinzugefuegtes Feld nicht bemerken, ein
    // Test gegen die tatsaechlich geschriebenen Schluessel schon.
    @Test func speichertKeineBelegungszahlenAlsFelderAufPlatte() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        let daten = try? Data(contentsOf: verzeichnis.appendingPathComponent("eigene-kurse.json"))
        let rohtext = daten.map { String(decoding: $0, as: UTF8.self) } ?? ""

        for verbotenerSchluessel in ["bookedCount", "waitlistCount", "freeSeats", "ownWaitlistPosition"] {
            #expect(!rohtext.contains(verbotenerSchluessel), "\(verbotenerSchluessel) darf nicht auf Platte stehen")
        }
        // Die Gegenrichtung: `studioId` MUSS dastehen. Ohne sie liesse
        // sich nach einem Studiowechsel nicht mehr erkennen, wem dieser
        // Stand gehoert -- und dieser Test ist die einzige Stelle, die die
        // tatsaechlich geschriebenen Schluessel prueft.
        #expect(rohtext.contains("\"studioId\":\"s1\""),
                "studioId muss mit auf die Platte, sonst gehoert der Cache keinem Studio")
    }

    @Test func eineUeberholendeAntwortGewinntNicht() async {
        // Bedienbild: zweimal kurz hintereinander "Aktualisieren" tippen.
        // Die AELTERE Anfrage haengt (Netzwechsel, Zeitueberschreitung)
        // und kommt NACH der juengeren zurueck -- sie darf den
        // frischeren Zustand nicht ueberschreiben.
        let (sut, _) = store()
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }

        await loader.setWoche(.success(KursTestdaten.woche(ownStatus: ["booked"])))
        await loader.haltenBisFreigabe()
        let ersterAufruf = Task {
            await sut.laden(studioId: "s1", von: Date(timeIntervalSince1970: 0), bis: Date(timeIntervalSince1970: 0))
        }
        await loader.wartenBisAngekommen()

        // Der zweite, juengere Aufruf laeuft vollstaendig durch, WAEHREND
        // der erste noch haengt.
        await loader.setWoche(.success(KursTestdaten.woche(ownStatus: [nil])))
        await sut.laden(studioId: "s1", von: Date(timeIntervalSince1970: 100), bis: Date(timeIntervalSince1970: 100))

        // Erst jetzt darf die AELTERE Antwort zurueckkommen.
        await loader.freigeben()
        await ersterAufruf.value

        // Die juengere Antwort (keine eigene Buchung) muss stehen bleiben.
        #expect(sut.eigene == nil)
    }

    @Test func decodingFehlgeschlagenBeimBuchenGiltAlsErfolg() async {
        // .decodingFailed wird ausschliesslich im 2xx-Zweig geworfen
        // (APIClient.execute) -- der Server hat die Buchung also
        // angenommen, nur die Antwort war unlesbar. Das dem Mitglied als
        // Fehlschlag zu melden waere der schlimmere der beiden Faelle aus
        // APIError.
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        await loader.setBuchen(.failure(.decodingFailed))

        do {
            try await sut.buchen(sessionId: "k0")
        } catch {
            Issue.record("buchen(...) hat trotz .decodingFailed geworfen: \(error)")
        }

        // Wie nach einem echten Erfolg wurde neu geladen.
        #expect(sut.ladeZaehler == 2)
    }

    @Test func decodingFehlgeschlagenBeimStornierenGiltAlsErfolg() async {
        // Dieselbe Begruendung wie beim Buchen: .decodingFailed wird
        // ausschliesslich im 2xx-Zweig geworfen (APIClient.execute) -- die
        // Stornierung ist beim Server angekommen, nur die Antwort war
        // unlesbar. Das dem Mitglied als Fehlschlag zu melden hiesse, es
        // glaubt weiter angemeldet zu sein.
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        await loader.setStornieren(.failure(.decodingFailed))

        do {
            try await sut.stornieren(sessionId: "k0")
        } catch {
            Issue.record("stornieren(...) hat trotz .decodingFailed geworfen: \(error)")
        }

        // Wie nach einem echten Erfolg wurde neu geladen.
        #expect(sut.ladeZaehler == 2)
    }

    // Der Weg, auf dem die Buchungskennung kippt (Schlussdurchsicht M4):
    // eine Buchungsantwort geht verloren, das Mitglied storniert spaeter
    // und meldet sich erneut an. Bliebe die Kennung stehen, schickte die
    // erneute Anmeldung dieselbe UUID, der Server antwortete dauerhaft
    // booking_id_reused, und das Mitglied laese "Bitte mit einer neuen
    // Kennung erneut versuchen" -- eine Anweisung, die es nicht befolgen
    // kann.
    /// Seit der Schlusswelle wirft ein Fehlversuch den Plan nicht mehr
    /// weg: Name, Uhrzeit und Raum eines Termins aendern sich nicht, nur
    /// die Belegung -- und die blendet der Screen ueber KurseHerkunft
    /// aus. Frueher wich der ganze Wochenplan der Offline-Karte.
    @Test func einFehlversuchLaesstDenGeladenenPlanStehen() async {
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked", nil]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }
        let standVorher = sut.wocheStand

        await loader.setWoche(.failure(.offline))
        await sut.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(sut.woche != nil)
        #expect(sut.ladeZustand == .fehlgeschlagen(.offline))
        // Der Stand bleibt der des letzten ERFOLGREICHEN Abrufs -- er ist
        // die Altersangabe zu genau diesen Daten.
        #expect(sut.wocheStand == standVorher)
    }

    @Test func nachEinemStornierenBekommtDieNaechsteAnmeldungEineFrischeKennung() async {
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }

        // 1. Anmelden -- die Antwort geht unterwegs verloren. APIClient
        //    bildet jeden Transportfehler auf .offline ab; die Buchung
        //    kann beim Server trotzdem angekommen sein.
        await loader.setBuchen(.failure(.offline))
        try? await sut.buchen(sessionId: "k0")

        // 2. Abmelden. Das gelingt.
        await loader.setStornieren(.success(CancelOutcome(promoted: false)))
        try? await sut.stornieren(sessionId: "k0")

        // 3. Erneut anmelden -- fachlich eine NEUE Buchung.
        await loader.setBuchen(.success(
            BookOutcome(result: "booked", created: true, bookingId: UUID().uuidString,
                        waitlistPosition: nil, freeSeats: 5)))
        try? await sut.buchen(sessionId: "k0")

        let kennungen = await loader.gesendeteKennungen
        #expect(kennungen.count == 2)
        #expect(kennungen.first != kennungen.last,
                "Die erneute Anmeldung schickt dieselbe, verbrauchte Kennung")
    }

    @Test func einWiederholungsversuchOhneStornierenBehaeltDieKennung() async {
        // Die Gegenprobe: OHNE Stornierung ist die Wiederverwendung
        // ausdruecklich gewollt -- sie ist die Zusicherung, dass ein
        // Wiederholer keine zweite Anmeldung erzeugt.
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil]))
        guard let loader = sut.loader as? FakeKurseLoader else {
            Issue.record("sut.loader ist kein FakeKurseLoader")
            return
        }

        await loader.setBuchen(.failure(.offline))
        try? await sut.buchen(sessionId: "k0")
        try? await sut.buchen(sessionId: "k0")

        let kennungen = await loader.gesendeteKennungen
        #expect(kennungen.count == 2)
        #expect(kennungen.first == kennungen.last)
    }
}
