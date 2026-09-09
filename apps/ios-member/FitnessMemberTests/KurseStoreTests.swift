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
    private var stornierenResultat: StornierenResultat = .success(CancelOutcome(promotedUserId: nil, promoted: false))

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

    func bookCourse(sessionId: String, bookingId: UUID) async throws(APIError) -> BookOutcome {
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
}
