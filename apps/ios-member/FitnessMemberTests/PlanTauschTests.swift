import Foundation
import Testing
@testable import FitnessMember

/// Testdaten ohne Actor-Bindung: die Attrappe des Clients (ein actor) baut
/// daraus ihre Antwort.
enum PlanTauschTestdaten {
    /// Einheit A: Brustpresse (A0, druecken, m1), Rudern (A1, ziehen, m2),
    /// Fahrrad (A2, cardio, m4). Einheit B: Schraegbank (B0, druecken).
    /// Kandidaten fuer "druecken" in Serverreihenfolge: e8, e1 (A0 selbst),
    /// e7, e2 (steht schon in A1), e9, e5; "ziehen" hat keine.
    static func plan(planId: String = "p1", version: Int = 1, positionA0: String = "e1",
                     machineA0: String = "m1", alternativen: String? = nil,
                     merkliste: String = #"{"nichtVorhanden":{},"gefaelltNicht":[]}"#) -> Trainingsplan {
        func position(_ key: String, _ baustein: String, _ exerciseId: String, _ machineId: String,
                      _ muskeln: [String], pause: Int = 150, dauer: String = "null",
                      wdh: (String, String) = ("8", "12")) -> String {
            let liste = muskeln.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"key":"\(key)","baustein":"\(baustein)","rolle":"pflicht","exerciseId":"\(exerciseId)",
             "modelId":"em-\(machineId)","typ":"mehrgelenk","saetze":3,"wdhVon":\(wdh.0),"wdhBis":\(wdh.1),
             "reserveVon":1,"reserveBis":3,"pauseSek":\(pause),"aufwaermsatz":false,"dauerMin":\(dauer),
             "hauptmuskeln":[\(liste)]}
            """
        }
        let alternativenJSON = alternativen ?? """
        {"druecken":[{"exerciseId":"e8","modelId":"em-m8"},{"exerciseId":"e1","modelId":"em-m1"},
                     {"exerciseId":"e7","modelId":"em-m7"},{"exerciseId":"e2","modelId":"em-m2"},
                     {"exerciseId":"e9","modelId":"em-m9"},{"exerciseId":"e5","modelId":"em-m1"}],
         "cardio":[{"exerciseId":"c2","modelId":"em-m10"}]}
        """
        let json = """
        {"planId":"\(planId)","studioId":"s1","version":\(version),"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":\(alternativenJSON),"merkliste":\(merkliste),
         "einheiten":[
           {"key":"A","geschaetzteMinuten":45,"positionen":[
             \(position("A0", "druecken", positionA0, machineA0, ["chest"])),
             \(position("A1", "ziehen", "e2", "m2", ["lats"], pause: 90)),
             \(position("A2", "cardio", "c1", "m4", [], pause: 0, dauer: "20", wdh: ("null", "null")))]},
           {"key":"B","geschaetzteMinuten":40,"positionen":[
             \(position("B0", "druecken", "e5", "m1", ["chest"]))]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    static func maschine(_ id: String, label: String, status: String = "active",
                         _ uebungen: [(id: String, name: String, muskeln: String)]) -> BootstrapResponse.Machine {
        let liste = uebungen.map { u in
            #"{"id":"\#(u.id)","name":"\#(u.name)","volumeKind":"reps","targetMin":8,"targetMax":12,"muscles":\#(u.muskeln)}"#
        }.joined(separator: ",")
        return GeraetTestdaten.dekodiere("""
        {"id":"\(id)","studioId":"s1","label":"\(label)","locationNote":null,"status":"\(status)",
         "tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em-\(id)","name":"Modell \(id)","manufacturer":null,"category":"kraft","photoPath":null,
           "loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,"settingDefinitions":[]},
         "exercises":[\(liste)]}
        """)
    }

    static let brust = #"[{"key":"chest","name":"Brust","role":"primary"}]"#

    static func bootstrap(plan: Trainingsplan = plan(), m1Status: String = "active") -> BootstrapResponse {
        BootstrapResponse(
            member: .init(displayName: nil, plans: [plan]),
            studios: [.init(id: "s1", name: "Nord", timezone: "Europe/Berlin")],
            machines: [
                maschine("m1", label: "Gerät 12", status: m1Status,
                         [("e1", "Brustpresse", brust), ("e5", "Schrägbank", brust)]),
                maschine("m2", label: "Gerät 3", [("e2", "Rudern", #"[{"key":"lats","name":"Latissimus","role":"primary"}]"#)]),
                maschine("m4", label: "Fahrrad 1", [("c1", "Fahrrad", "[]")]),
                maschine("m7", label: "Gerät 14", [("e7", "Schrägbankpresse", #"""
                    [{"key":"chest","name":"Brust","role":"primary"},
                     {"key":"deltoid_front","name":"Schulter vorn","role":"primary"},
                     {"key":"triceps","name":"Trizeps","role":"secondary"}]
                    """#)]),
                maschine("m8", label: "Gerät 9", [("e8", "Schulterdrücken", #"[{"key":"deltoid_front","name":"Schulter vorn","role":"primary"}]"#)]),
                maschine("m9", label: "Kabelturm 2", [("e9", "Brustpresse am Kabel", brust)]),
                maschine("m10", label: "Laufband 1", [("c2", "Laufband", "[]")]),
            ],
            calibrations: [], lastSets: [])
    }
}

/// Fake statt APIClient: der Debug-Build zeigt auf Prod, kein Test darf
/// echte Endpunkte rufen.
actor TauschClientAttrappe: PlanTauschend {
    struct Aufruf: Equatable {
        let planId, einheitKey, positionKey, exerciseId, modelId: String
        var grund: String? = nil
        var ortId: String? = nil
    }

    private(set) var aufrufe: [Aufruf] = []
    private var fehler: [APIError]

    init(fehler: [APIError] = []) {
        self.fehler = fehler
    }

    func swapPlanPosition(planId: String, einheitKey: String, positionKey: String, exerciseId: String,
                          modelId: String, grund: String?, ortId: String?) async throws(APIError) -> Trainingsplan {
        aufrufe.append(Aufruf(planId: planId, einheitKey: einheitKey, positionKey: positionKey,
                              exerciseId: exerciseId, modelId: modelId, grund: grund, ortId: ortId))
        if !fehler.isEmpty { throw fehler.removeFirst() }
        return PlanTauschTestdaten.plan(planId: "p2", version: 2, positionA0: exerciseId, machineA0: String(modelId.dropFirst(3)))
    }
}

/// Haelt swapPlanPosition an, bis der Test freigibt: so laesst sich pruefen,
/// was waehrend eines laufenden "Übernehmen" geht und was nicht.
actor HaltenderTauschClient: PlanTauschend {
    private(set) var aufrufe = 0
    private var freigabe: CheckedContinuation<Void, Never>?

    var wartet: Bool { freigabe != nil }

    func swapPlanPosition(planId: String, einheitKey: String, positionKey: String, exerciseId: String,
                          modelId: String, grund: String?, ortId: String?) async throws(APIError) -> Trainingsplan {
        aufrufe += 1
        await withCheckedContinuation { freigabe = $0 }
        return PlanTauschTestdaten.plan(planId: "p2", version: 2, positionA0: exerciseId, machineA0: String(modelId.dropFirst(3)))
    }

    func freigeben() {
        freigabe?.resume()
        freigabe = nil
    }
}

/// Position-Sheet und Tausch (Trainingsplan Etappe 3, Task 12, Entwuerfe
/// 3.1-3.3): welche Kandidaten erscheinen, was "nur heute" und "dauerhaft"
/// bewirken, und dass eine laufende Einheit ihre Planversion behaelt.
@MainActor
@Suite("PlanTausch")
struct PlanTauschTests {
    static let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
    typealias T = PlanTauschTestdaten

    static func store() -> TrainingsplanAblaufStore {
        TrainingsplanAblaufStore(fileStore: PlanAblaufFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }

    static func heute(_ plan: Trainingsplan = T.plan(), ablauf: TrainingsplanAblaufStore,
                      ausgelassen: Set<String> = []) -> PlanAnzeige.Heute {
        PlanAnzeige.heute(bootstrap: T.bootstrap(plan: plan),
                          ablaufPlanId: ablauf.planId, ablaufEinheitKey: ablauf.einheitKey,
                          ablaufZustand: ablauf.zustand, naechsteEinheitKey: ablauf.naechsteEinheitKey,
                          ablaufGebunden: ablauf.gebundeneSessionId != nil, ausgelassen: ausgelassen)!
    }

    static func auftrag(_ key: String, ablauf: TrainingsplanAblaufStore,
                        plan: Trainingsplan = T.plan(), bloecke: [LokalerBlock] = [],
                        ausgelassen: Set<String> = []) -> PlanTauschAuftrag {
        let heute = heute(plan, ablauf: ablauf, ausgelassen: ausgelassen)
        let position = heute.einheit.positionen.first { $0.key == key }!
        return PlanTausch.auftrag(position: position, heute: heute, bootstrap: T.bootstrap(plan: plan),
                                  bloecke: bloecke)
    }

    static func block(_ machineId: String, _ exerciseId: String, saetze: Int) -> LokalerBlock {
        LokalerBlock(machineId: machineId, exerciseId: exerciseId, saetze: (1...saetze).map { i in
            LokalerSatz(id: UUID(), setIndex: i, load: 50, volume: 10, problemFlag: false, problemReason: nil,
                        performedAt: jetzt.addingTimeInterval(Double(i) * 60))
        })
    }

    /// A0 (e1) nach `saetze` Saetzen: der erste Satz setzt den Status auf erledigt.
    static func nachSaetzen(_ saetze: Int) -> (TrainingsplanAblaufStore, [LokalerBlock]) {
        let ablauf = vorbereitet()
        _ = ablauf.nachSatz(sessionId: UUID(),
                            satz: AblaufSatz(exerciseId: "e1", hauptmuskeln: ["chest"], cardio: false), jetzt: jetzt)
        return (ablauf, saetze > 0 ? [block("m1", "e1", saetze: saetze)] : [])
    }

    /// Bootstrap neu laden heisst hier: der Ablauf sieht die Antwort des
    /// Servers (neue aktive Version) -- wie RootView nach `katalog.load()`.
    final class Umgebung {
        var online = true
        var neuGeladen = 0
        var neuerPlan: Trainingsplan?
        var aktuellePlanId: String? = "p1"
    }

    static func sitzung(_ auftrag: PlanTauschAuftrag, ablauf: TrainingsplanAblaufStore,
                        client: TauschClientAttrappe, umgebung: Umgebung) -> PlanTauschSitzung {
        PlanTauschSitzung(
            auftrag: auftrag, client: client, ablauf: ablauf,
            istOnline: { umgebung.online },
            aktuellePlanId: { umgebung.aktuellePlanId },
            neuLaden: {
                umgebung.neuGeladen += 1
                if let plan = umgebung.neuerPlan {
                    umgebung.aktuellePlanId = plan.planId
                    ablauf.vorbereiten(plan: plan, jetzt: Self.jetzt.addingTimeInterval(60))
                }
            })
    }

    static func vorbereitet() -> TrainingsplanAblaufStore {
        let ablauf = store()
        ablauf.vorbereiten(plan: T.plan(), jetzt: jetzt)
        return ablauf
    }

    // MARK: - Kandidaten

    @Test("Kandidaten enthalten nur den Baustein, ohne aktuelle Uebung und ohne schon geplante")
    func kandidatenNurDesBausteins() {
        let ablauf = Self.vorbereitet()
        // A1 heute auf e9 getauscht: e9 steht damit auch schon in der Einheit.
        ablauf.tauschen(positionKey: "A1", ersatz: (exerciseId: "e9", hauptmuskeln: ["chest"]))

        let kandidaten = Self.auftrag("A0", ablauf: ablauf).kandidaten
        #expect(kandidaten.map(\.exerciseId) == ["e8", "e7", "e5"])
        // Cardio-Kandidaten gehoeren zu einem anderen Baustein.
        #expect(!kandidaten.contains { $0.exerciseId == "c2" })
    }

    @Test("Reihenfolge des Servers bleibt")
    func reihenfolgeDesServers() throws {
        let position = T.plan().einheiten[0].positionen[0]
        let kandidaten = PlanTausch.kandidaten(position: position, alternativen: T.plan().alternativen,
                                               belegt: [], uebungen: T.bootstrap())
        #expect(kandidaten.map(\.exerciseId) == ["e8", "e7", "e2", "e9", "e5"])

        let schraeg = try #require(kandidaten.first { $0.exerciseId == "e7" })
        #expect(schraeg.name == "Schrägbankpresse")
        #expect(schraeg.geraet == "Gerät 14")
        // Nur die Hauptmuskeln, in der Reihenfolge des Katalogs.
        #expect(schraeg.muskeln == "Brust, Schulter vorn")
        #expect(schraeg.hauptmuskeln == ["chest", "deltoid_front"])
        #expect(schraeg.untertitel == "Gerät 14 · Brust, Schulter vorn")
        #expect(schraeg.vorschaubildModell == "em-m7")
        #expect(schraeg.modelId == "em-m7")
    }

    @Test("Andere Uebung waehlen steht an jeder tauschbaren Position, auch ohne Kandidaten")
    func andereUebungAnJederTauschbarenPosition() {
        let ablauf = Self.vorbereitet()
        let ohneKandidaten = Self.auftrag("A1", ablauf: ablauf)
        #expect(ohneKandidaten.kandidaten.isEmpty)
        #expect(ohneKandidaten.tauschbar)
        #expect(ohneKandidaten.zeigtAndereUebung)
        #expect(Self.auftrag("A0", ablauf: ablauf).zeigtAndereUebung)
    }

    @Test("Start mit Ersatz: die Sitzung steht gleich bei der Grund-Frage, mit und ohne Ersatz")
    func startMitErsatz() throws {
        let ablauf = Self.vorbereitet()
        let basis = Self.auftrag("A0", ablauf: ablauf)
        let schraeg = try #require(basis.kandidaten.first { $0.exerciseId == "e7" })

        var mit = basis
        mit.ersatzStart = .ersatz(schraeg)
        let a = Self.sitzung(mit, ablauf: ablauf, client: TauschClientAttrappe(), umgebung: Umgebung())
        #expect(a.schritt == .entfernen)
        #expect(a.ersatz == schraeg)
        #expect(a.optionen.count == 3)

        var ohne = basis
        ohne.ersatzStart = .ohneErsatz
        let b = Self.sitzung(ohne, ablauf: ablauf, client: TauschClientAttrappe(), umgebung: Umgebung())
        #expect(b.schritt == .entfernen)
        #expect(b.ersatz == nil)
        #expect(b.optionen.count == 2)

        #expect(Self.sitzung(basis, ablauf: ablauf, client: TauschClientAttrappe(), umgebung: Umgebung()).schritt == .vorgabe)
    }

    // MARK: - Nur heute

    @Test("nur heute: Zustand getauscht, kein Netzwerkaufruf")
    func nurHeute() async throws {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        umgebung.online = false
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)

        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })
        // Offline geht "nur heute" trotzdem.
        #expect(sut.waehlen(schraeg))

        let a0 = try #require(ablauf.zustand?.positionen.first)
        #expect(a0.status == .getauscht)
        #expect(a0.ersatzExerciseId == "e7")
        #expect(a0.hauptmuskeln == ["chest", "deltoid_front"])
        #expect(await client.aufrufe.isEmpty)
        #expect(umgebung.neuGeladen == 0)
    }

    // MARK: - Dauerhaft

    @Test("dauerhaft: Aufruf mit Plan-, Einheits-, Positionsschluessel, danach Bootstrap neu")
    func dauerhaft() async throws {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })

        sut.dauerhaftSetzen(true)
        // Mit Schalter schreibt "Wählen" nichts, es folgt die Bestaetigung (3.3).
        #expect(!sut.waehlen(schraeg))
        #expect(sut.schritt == .bestaetigen(schraeg))
        #expect(await client.aufrufe.isEmpty)
        #expect(ablauf.zustand?.positionen.first?.status == .offen)

        #expect(await sut.uebernehmen())
        #expect(await client.aufrufe == [.init(planId: "p1", einheitKey: "A", positionKey: "A0",
                                               exerciseId: "e7", modelId: "em-m7")])
        #expect(umgebung.neuGeladen == 1)
        #expect(sut.fehler == nil)
    }

    @Test("dauerhaft offline gesperrt")
    func dauerhaftOffline() async throws {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        umgebung.online = false
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)

        #expect(!sut.dauerhaftMoeglich)
        sut.dauerhaftSetzen(true)
        #expect(!sut.dauerhaft)

        // War der Schalter schon an, als die Verbindung wegfiel: "Wählen"
        // tauscht dann nicht still nur fuer heute, und "Übernehmen" schickt nichts.
        umgebung.online = true
        sut.dauerhaftSetzen(true)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })
        #expect(!sut.waehlen(schraeg))
        umgebung.online = false
        #expect(!(await sut.uebernehmen()))
        #expect(sut.fehler == .offline)
        #expect(await client.aufrufe.isEmpty)
        #expect(ablauf.zustand?.positionen.first?.status == .offen)
        // Ausschalten geht auch offline.
        sut.dauerhaftSetzen(false)
        #expect(!sut.dauerhaft)
    }

    /// Waehrend "Übernehmen" schreibt, ist der Schalter gesperrt (Sheet) und
    /// dauerhaftSetzen wirkungslos: sonst schloesse das Sheet nach Erfolg mit
    /// einem Tausch, den der Schalter scheinbar abgesagt hatte, oder ein
    /// Fehler landete in der Liste, die keinen zeigt.
    @Test("Schalter aus waehrend Uebernehmen schreibt: Schritt bleibt, Tausch wie bestaetigt")
    func schalterWaehrendUebernehmen() async throws {
        let ablauf = Self.vorbereitet()
        let client = HaltenderTauschClient()
        let umgebung = Umgebung()
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = PlanTauschSitzung(
            auftrag: auftrag, client: client, ablauf: ablauf,
            istOnline: { umgebung.online }, aktuellePlanId: { umgebung.aktuellePlanId },
            neuLaden: { umgebung.neuGeladen += 1 })
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })
        sut.dauerhaftSetzen(true)
        _ = sut.waehlen(schraeg)

        let laeuft = Task { await sut.uebernehmen() }
        while !(await client.wartet) { await Task.yield() }
        #expect(sut.schreibtGerade)

        sut.dauerhaftSetzen(false)
        #expect(sut.dauerhaft)
        #expect(sut.schritt == .bestaetigen(schraeg))

        await client.freigeben()
        #expect(await laeuft.value)
        #expect(await client.aufrufe == 1)
        #expect(umgebung.neuGeladen == 1)
        #expect(sut.fehler == nil)
        let a0 = try #require(ablauf.zustand?.positionen.first)
        #expect(a0.status == .getauscht)
        #expect(a0.ersatzExerciseId == "e7")
    }

    @Test("dauerhaft vor dem Start: neue Version sofort, Tausch nur heute anderer Positionen bleibt")
    func dauerhaftVorDemStart() async throws {
        let ablauf = Self.vorbereitet()
        // Ein Tausch nur heute an A1 (ziehen) vorher; er darf nicht verloren gehen.
        ablauf.tauschen(positionKey: "A1", ersatz: (exerciseId: "e3", hauptmuskeln: ["lats"]))
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        umgebung.neuerPlan = T.plan(planId: "p2", version: 2, positionA0: "e7", machineA0: "m7")
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })

        sut.dauerhaftSetzen(true)
        _ = sut.waehlen(schraeg)
        #expect(await sut.uebernehmen())

        #expect(ablauf.planId == "p2")
        let positionen = try #require(ablauf.zustand?.positionen)
        #expect(positionen.map(\.key) == ["A0", "A1", "A2"])
        // A0 ist jetzt geplant, nicht doppelt als Tausch.
        #expect(positionen[0].exerciseId == "e7")
        #expect(positionen[0].status == .offen)
        #expect(positionen[0].ersatzExerciseId == nil)
        #expect(positionen[1].status == .getauscht)
        #expect(positionen[1].ersatzExerciseId == "e3")
        // Die Karte zeigt die neue Uebung sofort.
        let zeile = PlanAnzeige.zeilen(plan: umgebung.neuerPlan!, einheitKey: "A", zustand: ablauf.zustand,
                                       bloecke: [], bootstrap: T.bootstrap(plan: umgebung.neuerPlan!))[0]
        #expect(zeile.name == "Schrägbankpresse")
    }

    @Test("dauerhaft vor dem Start: scheitert das Neuladen, steht die Uebung trotzdem heute da")
    func dauerhaftOhneNeuladen() async throws {
        let ablauf = Self.vorbereitet()
        let umgebung = Umgebung()  // neuLaden bringt keine neue Version
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: TauschClientAttrappe(), umgebung: umgebung)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })

        sut.dauerhaftSetzen(true)
        _ = sut.waehlen(schraeg)
        #expect(await sut.uebernehmen())
        #expect(ablauf.zustand?.positionen.first?.ersatzExerciseId == "e7")
        #expect(ablauf.zustand?.positionen.first?.status == .getauscht)
    }

    @Test("Fehler: Sheet bleibt offen, 409 laedt neu, Wiederholen nimmt den neuen Plan")
    func fehlerBleibtOffen() async throws {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe(fehler: [.validation(message: "x"), .conflict(message: "y")])
        let umgebung = Umgebung()
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })
        sut.dauerhaftSetzen(true)
        _ = sut.waehlen(schraeg)

        // 422: kein Erfolg, Bestaetigung bleibt, kein Neuladen.
        #expect(!(await sut.uebernehmen()))
        #expect(sut.fehler == .validation(message: "x"))
        #expect(sut.schritt == .bestaetigen(schraeg))
        #expect(umgebung.neuGeladen == 0)
        #expect(ablauf.zustand?.positionen.first?.status == .offen)

        // 409: der Plan hat sich geaendert -- Bootstrap neu.
        umgebung.aktuellePlanId = nil
        umgebung.neuerPlan = T.plan(planId: "p5", version: 5)
        #expect(!(await sut.uebernehmen()))
        #expect(sut.fehler == .conflict(message: "y"))
        #expect(umgebung.neuGeladen == 1)
        #expect(sut.schritt == .bestaetigen(schraeg))

        // Wiederholen geht an die jetzt aktive Version.
        umgebung.neuerPlan = nil
        #expect(await sut.uebernehmen())
        #expect(await client.aufrufe.map(\.planId) == ["p1", "p1", "p5"])
        #expect(sut.fehler == nil)
    }

    // MARK: - Was tauschbar ist

    @Test("erledigte Position ist nicht tauschbar")
    func erledigtNichtTauschbar() async throws {
        let ablauf = Self.vorbereitet()
        _ = ablauf.nachSatz(sessionId: UUID(),
                            satz: AblaufSatz(exerciseId: "e1", hauptmuskeln: ["chest"], cardio: false), jetzt: Self.jetzt)
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        #expect(auftrag.status == .erledigt)
        #expect(!auftrag.tauschbar)
        #expect(!auftrag.zeigtAndereUebung)

        let client = TauschClientAttrappe()
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: Umgebung())
        let kandidat = try #require(PlanTausch.kandidaten(
            position: T.plan().einheiten[0].positionen[0], alternativen: T.plan().alternativen,
            belegt: [], uebungen: T.bootstrap()).first)
        #expect(!sut.waehlen(kandidat))
        #expect(ablauf.zustand?.positionen.first?.status == .erledigt)

        // Cardio bietet keinen Tausch an (der Ablauf tauscht Cardio nie),
        // obwohl der Server Kandidaten fuer "cardio" nennt.
        let cardio = Self.auftrag("A2", ablauf: ablauf)
        #expect(!cardio.tauschbar)
        #expect(!cardio.zeigtAndereUebung)
    }

    @Test("optionale Position ist nicht tauschbar, eine heute getauschte schon")
    func optionalUndGetauscht() {
        let ablauf = Self.vorbereitet()
        ablauf.tauschen(positionKey: "A0", ersatz: (exerciseId: "e8", hauptmuskeln: ["deltoid_front"]))
        let getauscht = Self.auftrag("A0", ablauf: ablauf)
        #expect(getauscht.status == .getauscht)
        #expect(getauscht.tauschbar)
        #expect(getauscht.ersatzName == "Schulterdrücken")
        // Der heutige Ersatz steht nicht noch einmal zur Wahl.
        #expect(getauscht.kandidaten.map(\.exerciseId) == ["e7", "e9", "e5"])

        // Ein ungeplanter Latzug macht A1 (ziehen, Latissimus) optional.
        _ = ablauf.nachSatz(sessionId: UUID(),
                            satz: AblaufSatz(exerciseId: "e4", hauptmuskeln: ["lats"], cardio: false), jetzt: Self.jetzt)
        let optional = Self.auftrag("A1", ablauf: ablauf, plan: T.plan(alternativen: """
            {"ziehen":[{"exerciseId":"e8","modelId":"em-m8"}]}
            """))
        #expect(optional.status == .optional)
        #expect(!optional.tauschbar)
    }

    // MARK: - Weiter und Rueckkehr

    @Test("Nach zwei Saetzen steht Weiter mit Satz 3, obwohl die Position erledigt ist")
    func weiterTitelNachZweiSaetzen() {
        let (ablauf, bloecke) = Self.nachSaetzen(2)
        let auftrag = Self.auftrag("A0", ablauf: ablauf, bloecke: bloecke)
        #expect(auftrag.status == .erledigt)
        #expect(auftrag.satzGemacht == 2)
        #expect(auftrag.satzGeplant == 3)
        #expect(auftrag.weiterTitel == "Weiter mit Satz 3")
    }

    @Test("Ohne Saetze steht Übung starten")
    func weiterTitelOhneSaetze() {
        let ablauf = Self.vorbereitet()
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        #expect(auftrag.satzGemacht == 0)
        #expect(auftrag.weiterTitel == "Übung starten")
        // Cardio zaehlt nie Saetze.
        let cardio = Self.auftrag("A2", ablauf: ablauf, bloecke: [Self.block("m4", "c1", saetze: 2)])
        #expect(cardio.weiterTitel == "Übung starten")
    }

    @Test("Eine erledigte Position bleibt startbar: Weiter statt Sperre")
    func erledigtePositionBleibtStartbar() {
        let (ablauf, bloecke) = Self.nachSaetzen(1)
        let auftrag = Self.auftrag("A0", ablauf: ablauf, bloecke: bloecke)
        #expect(auftrag.status == .erledigt)
        #expect(auftrag.weiterTitel == "Weiter mit Satz 2")
        #expect(!auftrag.istAusgelassen)
    }

    @Test("Der Ersatz zaehlt, nicht die geplante Uebung")
    func satzGemachtZaehltDenErsatz() {
        let ablauf = Self.vorbereitet()
        ablauf.tauschen(positionKey: "A0", ersatz: (exerciseId: "e8", hauptmuskeln: ["deltoid_front"]))
        let bloecke = [Self.block("m1", "e1", saetze: 3), Self.block("m8", "e8", saetze: 1)]
        let auftrag = Self.auftrag("A0", ablauf: ablauf, bloecke: bloecke)
        #expect(auftrag.satzGemacht == 1)
        #expect(auftrag.weiterTitel == "Weiter mit Satz 2")
    }

    @Test("Saetze derselben Uebung an zwei Geraeten zaehlen zusammen")
    func satzGemachtZaehltBeideGeraete() {
        let ablauf = Self.vorbereitet()
        let bloecke = [Self.block("m1", "e1", saetze: 1), Self.block("m5", "e1", saetze: 2)]
        let auftrag = Self.auftrag("A0", ablauf: ablauf, bloecke: bloecke)
        #expect(auftrag.satzGemacht == 3)
        #expect(auftrag.weiterTitel == "Weiter mit Satz 4")
    }

    @Test("Eine ausgelassene Position zeigt Doch machen")
    func ausgelassenePositionZeigtDochMachen() {
        let ablauf = Self.vorbereitet()
        #expect(!Self.auftrag("A0", ablauf: ablauf).istAusgelassen)
        #expect(Self.auftrag("A0", ablauf: ablauf, ausgelassen: ["A0"]).istAusgelassen)
        #expect(!Self.auftrag("A1", ablauf: ablauf, ausgelassen: ["A0"]).istAusgelassen)
    }

    @Test("Der Auftrag nennt die Uebung, die ein Start meint: Ersatz vor Plan")
    func auftragNenntDieStartUebung() {
        let ablauf = Self.vorbereitet()
        #expect(Self.auftrag("A0", ablauf: ablauf).uebungId == "e1")
        ablauf.tauschen(positionKey: "A0", ersatz: (exerciseId: "e8", hauptmuskeln: ["deltoid_front"]))
        #expect(Self.auftrag("A0", ablauf: ablauf).uebungId == "e8")
    }

    // MARK: - Laufende Einheit

    @Test("Tausch waehrend laufender Einheit aendert deren Planversion nicht")
    func laufendeEinheitBehaeltVersion() async throws {
        let ablauf = Self.vorbereitet()
        let session = UUID()
        _ = ablauf.nachSatz(sessionId: session,
                            satz: AblaufSatz(exerciseId: "e2", hauptmuskeln: ["lats"], cardio: false), jetzt: Self.jetzt)
        let vorher = ablauf.zustand
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        let neu = T.plan(planId: "p2", version: 2, positionA0: "e7", machineA0: "m7")
        umgebung.neuerPlan = neu
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })

        sut.dauerhaftSetzen(true)
        _ = sut.waehlen(schraeg)
        #expect(await sut.uebernehmen())

        #expect(await client.aufrufe.count == 1)
        #expect(ablauf.planId == "p1")
        #expect(ablauf.gebundeneSessionId == session)
        #expect(ablauf.zustand == vorher)

        // Die Karte bleibt beim Stand der laufenden Einheit, obwohl der
        // Bootstrap schon die neue planId nennt.
        let heute = Self.heute(neu, ablauf: ablauf)
        #expect(heute.zustand == vorher)
        #expect(PlanAnzeige.fortschritt(plan: neu, einheitKey: "A", zustand: heute.zustand) == "1 von 3")

        // "Nur heute" geht in der laufenden Einheit weiter.
        let sut2 = Self.sitzung(Self.auftrag("A0", ablauf: ablauf, plan: neu), ablauf: ablauf,
                                client: client, umgebung: umgebung)
        let schulter = try #require(sut2.auftrag.kandidaten.first { $0.exerciseId == "e8" })
        #expect(sut2.waehlen(schulter))
        #expect(ablauf.zustand?.positionen.first?.ersatzExerciseId == "e8")
        #expect(ablauf.planId == "p1")
    }

    // MARK: - Texte (3.1-3.3)

    @Test("Vorgabe-Tags wie im Entwurf 3.1, Cardio mit Dauer")
    func vorgabeTags() {
        let plan = T.plan()
        #expect(PlanTausch.vorgabeTags(plan.einheiten[0].positionen[0])
                == ["3 Sätze", "8–12 Wdh.", "Pause 2:30", "Reserve 1–3"])
        #expect(PlanTausch.vorgabeTags(plan.einheiten[0].positionen[1])
                == ["3 Sätze", "8–12 Wdh.", "Pause 1:30", "Reserve 1–3"])
        #expect(PlanTausch.vorgabeTags(plan.einheiten[0].positionen[2]) == ["20 Min"])
    }

    @Test("Vorgesehen am nur mit aktivem Geraet der geplanten Uebung")
    func vorgesehenAm() {
        let ablauf = Self.vorbereitet()
        #expect(Self.auftrag("A0", ablauf: ablauf).vorgesehen
                == "Vorgesehen am Gerät „Gerät 12“. Jedes andere Gerät mit dieser Übung zählt auch.")

        // Stillgelegt: kein Satz, statt etwas zu erfinden.
        let heute = Self.heute(ablauf: ablauf)
        let stillgelegt = PlanTausch.auftrag(position: heute.einheit.positionen[0], heute: heute,
                                             bootstrap: T.bootstrap(m1Status: "inactive"))
        #expect(stillgelegt.vorgesehen == nil)

        // Heute getauscht: das geplante Geraet ist nicht, was heute dran ist.
        ablauf.tauschen(positionKey: "A0", ersatz: (exerciseId: "e8", hauptmuskeln: ["deltoid_front"]))
        #expect(Self.auftrag("A0", ablauf: ablauf).vorgesehen == nil)
    }

    @Test("Schaltertexte nennen die Einheit")
    func schaltertexte() {
        #expect(PlanTausch.dauerhaftHinweis(einheitKey: "A")
                == "Gilt für alle künftigen Einheiten A. Heute ändert sich nichts anderes.")
        #expect(PlanTausch.bestaetigungsHinweis(einheitKey: "A", uebung: "Schrägbankpresse")
                == "Ab der nächsten Einheit A steht hier: Schrägbankpresse.")
        #expect(PlanTausch.dauerhaftHinweis(einheitKey: "OK_A")
                == "Gilt für alle künftigen Einheiten „Oberkörper A“. Heute ändert sich nichts anderes.")
    }

    // MARK: - Entfernen mit Grund (Task 8)

    static let merkliste = #"{"nichtVorhanden":{"s1":["e8"],"s2":["e7"]},"gefaelltNicht":["e9"]}"#

    @Test("Kandidaten ohne die aktuelle Uebung")
    func kandidatenOhneAktuelle() {
        let plan = T.plan()
        let kandidaten = PlanTausch.kandidaten(position: plan.einheiten[0].positionen[0], plan: plan, ort: "s1",
                                               belegt: [], uebungen: T.bootstrap())
        #expect(!kandidaten.contains { $0.exerciseId == "e1" })
    }

    @Test("Kandidaten ohne nichtVorhanden des aktiven Ortes")
    func kandidatenOhneNichtVorhanden() {
        let plan = T.plan(merkliste: Self.merkliste)
        let position = plan.einheiten[0].positionen[0]
        let kandidaten = PlanTausch.kandidaten(position: position, plan: plan, ort: "s1", belegt: [], uebungen: T.bootstrap())
        #expect(!kandidaten.contains { $0.exerciseId == "e8" })
        #expect(kandidaten.contains { $0.exerciseId == "e7" })
    }

    @Test("nichtVorhanden eines anderen Ortes bleibt sichtbar")
    func anderesOrtBleibtSichtbar() {
        let plan = T.plan(merkliste: Self.merkliste)
        let position = plan.einheiten[0].positionen[0]
        // s1 sperrt e8, s2 sperrt e7: am Ort s2 steht e8 wieder da, e7 nicht.
        let anS2 = PlanTausch.kandidaten(position: position, plan: plan, ort: "s2", belegt: [], uebungen: T.bootstrap())
        #expect(anS2.contains { $0.exerciseId == "e8" })
        #expect(!anS2.contains { $0.exerciseId == "e7" })
        // Ein Ort ohne Eintrag sperrt nichts.
        let anS3 = PlanTausch.kandidaten(position: position, plan: plan, ort: "s3", belegt: [], uebungen: T.bootstrap())
        #expect(anS3.map(\.exerciseId) == ["e8", "e7", "e2", "e9", "e5"])
    }

    @Test("Freies Training nutzt die Katalog-Studio-ID als Ort")
    func freiesTrainingOrt() {
        var bootstrap = T.bootstrap()
        bootstrap.catalog = try! JSONDecoder().decode(
            BootstrapResponse.Catalog.self, from: Data(#"{"studioId":"kat1","equipmentTypes":[]}"#.utf8))
        #expect(PlanTausch.ort(aktivesStudio: nil, bootstrap: bootstrap) == "kat1")
        #expect(PlanTausch.ort(aktivesStudio: "s1", bootstrap: bootstrap) == "s1")
        #expect(PlanTausch.ort(aktivesStudio: nil, bootstrap: T.bootstrap()) == nil)

        // Die Sperre am Katalog-Ort gilt im Freien Training.
        let plan = T.plan(merkliste: #"{"nichtVorhanden":{"kat1":["e8"]},"gefaelltNicht":[]}"#)
        let heute = PlanAnzeige.Heute(plan: plan, einheit: plan.einheiten[0], zustand: nil, ausgelassen: [])
        let auftrag = PlanTausch.auftrag(position: plan.einheiten[0].positionen[0], heute: heute,
                                         bootstrap: bootstrap, ort: PlanTausch.ort(aktivesStudio: nil, bootstrap: bootstrap))
        #expect(!auftrag.kandidaten.contains { $0.exerciseId == "e8" })
        #expect(auftrag.ort == "kat1")
    }

    @Test("gefaelltNicht steht am Ende und wird nicht herausgefiltert")
    func gefaelltNichtAmEnde() {
        // Der Server sortiert e9 (gefaelltNicht) hinten; die App behaelt seine Reihenfolge.
        let plan = T.plan(
            alternativen: #"{"druecken":[{"exerciseId":"e8","modelId":"em-m8"},{"exerciseId":"e7","modelId":"em-m7"},{"exerciseId":"e9","modelId":"em-m9"}]}"#,
            merkliste: Self.merkliste)
        let kandidaten = PlanTausch.kandidaten(position: plan.einheiten[0].positionen[0], plan: plan, ort: "s2",
                                               belegt: [], uebungen: T.bootstrap())
        #expect(kandidaten.map(\.exerciseId) == ["e8", "e9"])
    }

    /// Ein Ersatz von der vollen Auswahl: steht in keiner Kandidatenliste des Plans.
    static let fremd = TauschKandidat(exerciseId: "e77", modelId: "em-m77", name: "Fremdpresse", geraet: nil,
                                      muskeln: nil, hauptmuskeln: ["chest"], vorschaubildModell: nil)

    static func mitOrt(_ ablauf: TrainingsplanAblaufStore) -> PlanTauschAuftrag {
        let heute = Self.heute(ablauf: ablauf)
        return PlanTausch.auftrag(position: heute.einheit.positionen[0], heute: heute,
                                  bootstrap: T.bootstrap(), ort: "s1")
    }

    @Test("Heute auslassen und Belegt verhalten sich gleich: nur lokal, kein Client, Merkliste unberuehrt")
    func heuteAuslassenUndBelegtVerhaltenSichGleich() async throws {
        for option in [PlanTausch.EntfernOption.heuteAuslassen, .belegt] {
            let ablauf = Self.vorbereitet()
            let client = TauschClientAttrappe()
            let umgebung = Umgebung()
            let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: client, umgebung: umgebung)

            sut.ersatzGewaehlt(Self.fremd)
            #expect(sut.schritt == .entfernen)
            // Vorbelegt: Heute auslassen.
            #expect(sut.gewaehlteOption == .heuteAuslassen)
            sut.optionAuswaehlen(option)
            #expect(sut.gewaehlteOption == option)
            #expect(sut.optionBestaetigen())

            let a0 = try #require(ablauf.zustand?.positionen.first)
            #expect(a0.status == .getauscht)
            #expect(a0.ersatzExerciseId == "e77")
            #expect(a0.hauptmuskeln == ["chest"])
            #expect(sut.grund == nil)
            #expect(!sut.dauerhaft)
            #expect(await client.aufrufe.isEmpty)
            #expect(umgebung.neuGeladen == 0)
        }
    }

    @Test("Ohne Ersatz nur zwei Optionen")
    func ohneErsatzNurZweiOptionen() {
        let ablauf = Self.vorbereitet()
        let auftrag = Self.mitOrt(ablauf)
        #expect(auftrag.entfernOptionen(mitErsatz: false) == [.heuteAuslassen, .belegt])
        #expect(auftrag.entfernOptionen(mitErsatz: true) == [.heuteAuslassen, .belegt, .gefaelltNicht])

        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: TauschClientAttrappe(), umgebung: Umgebung())
        sut.ersatzGewaehlt(nil)
        #expect(sut.schritt == .entfernen)
        #expect(sut.optionen == [.heuteAuslassen, .belegt])
    }

    @Test("Gefaellt mir nicht ohne Ersatz wird nicht angeboten und tut nichts")
    func gefaelltNichtOhneErsatzNichtAngeboten() async {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe()
        let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: client, umgebung: Umgebung())
        sut.ersatzGewaehlt(nil)

        sut.optionAuswaehlen(.gefaelltNicht)
        #expect(sut.gewaehlteOption == .heuteAuslassen)
        #expect(!sut.grundWaehlen(.gefaelltNicht))
        #expect(sut.schritt == .entfernen)
        #expect(sut.grund == nil)
        #expect(await client.aufrufe.isEmpty)
    }

    @Test("Gefaellt mir nicht offline ist gesperrt")
    func gefaelltNichtOfflineGesperrt() async {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        umgebung.online = false
        let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: client, umgebung: umgebung)
        sut.ersatzGewaehlt(Self.fremd)

        #expect(!sut.optionMoeglich(.gefaelltNicht))
        #expect(sut.optionMoeglich(.belegt))
        sut.optionAuswaehlen(.gefaelltNicht)
        #expect(sut.gewaehlteOption == .heuteAuslassen)
        #expect(!sut.grundWaehlen(.gefaelltNicht))
        #expect(sut.schritt == .entfernen)
        #expect(ablauf.zustand?.positionen.first?.status == .offen)
        #expect(await client.aufrufe.isEmpty)
    }

    @Test("Gefaellt mir nicht mit Ersatz ausserhalb des Bausteins: Fehler bleibt, Nur heute als Rueckfall")
    func gefaelltNichtMitErsatzAusserhalbBausteinMeldetFehlerUndBietetNurHeute() async throws {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe(fehler: [.validation(message: "x")])
        let umgebung = Umgebung()
        let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: client, umgebung: umgebung)
        sut.ersatzGewaehlt(Self.fremd)

        sut.optionAuswaehlen(.gefaelltNicht)
        // Weiter zur Bestaetigung, nichts geschrieben.
        #expect(!sut.optionBestaetigen())
        #expect(sut.schritt == .bestaetigen(Self.fremd))
        #expect(sut.grund == .gefaelltNicht)
        #expect(await client.aufrufe.isEmpty)

        #expect(!(await sut.uebernehmen()))
        #expect(sut.fehler == .validation(message: "x"))
        #expect(sut.schritt == .bestaetigen(Self.fremd))
        #expect(await client.aufrufe == [.init(planId: "p1", einheitKey: "A", positionKey: "A0", exerciseId: "e77",
                                               modelId: "em-m77", grund: "gefaellt_nicht", ortId: "s1")])
        #expect(ablauf.zustand?.positionen.first?.status == .offen)

        // Rueckfall: nur heute, ohne weiteren Aufruf.
        #expect(sut.nurHeuteTauschen())
        let a0 = try #require(ablauf.zustand?.positionen.first)
        #expect(a0.status == .getauscht)
        #expect(a0.ersatzExerciseId == "e77")
        #expect(await client.aufrufe.count == 1)
    }

    @Test("Abbrechen aus der Bestaetigung eines Grundes fuehrt zurueck zur Frage")
    func abbrechenFuehrtZurFrage() {
        let ablauf = Self.vorbereitet()
        let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: TauschClientAttrappe(), umgebung: Umgebung())
        sut.ersatzGewaehlt(Self.fremd)
        #expect(!sut.grundWaehlen(.gefaelltNicht))
        sut.abbrechen()
        #expect(sut.schritt == .entfernen)
        #expect(sut.grund == nil)
    }

    @Test("Abbrechen, dann offline: die Wahl faellt auf Heute auslassen zurueck")
    func abbrechenDannOffline() async {
        let ablauf = Self.vorbereitet()
        let umgebung = Umgebung()
        let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: TauschClientAttrappe(), umgebung: umgebung)
        sut.ersatzGewaehlt(Self.fremd)
        sut.optionAuswaehlen(.gefaelltNicht)
        #expect(!sut.optionBestaetigen())
        umgebung.online = false
        #expect(!(await sut.uebernehmen()))
        sut.abbrechen()
        #expect(sut.gewaehlteOption == .heuteAuslassen)
        #expect(sut.optionBestaetigen())
        #expect(ablauf.zustand?.positionen.first?.ersatzExerciseId == "e77")

        // Faellt die Verbindung bei offener Frage weg, gilt dasselbe.
        let ablauf2 = Self.vorbereitet()
        let umgebung2 = Umgebung()
        let sut2 = Self.sitzung(Self.mitOrt(ablauf2), ablauf: ablauf2, client: TauschClientAttrappe(), umgebung: umgebung2)
        sut2.ersatzGewaehlt(Self.fremd)
        sut2.optionAuswaehlen(.gefaelltNicht)
        umgebung2.online = false
        #expect(sut2.gewaehlteOption == .heuteAuslassen)
        #expect(sut2.optionBestaetigen())
    }

    @Test("Ersatz nur bei tauschbarer Position; sonst kein Auslassen durch die Hintertuer")
    func ersatzGewaehltBrauchtTauschbar() {
        let (ablauf, _) = Self.nachSaetzen(1)  // A0 erledigt
        let sut = Self.sitzung(Self.auftrag("A0", ablauf: ablauf), ablauf: ablauf,
                               client: TauschClientAttrappe(), umgebung: Umgebung())
        sut.ersatzGewaehlt(nil)
        #expect(sut.schritt == .vorgabe)
        #expect(!sut.grundWaehlen(.heuteAuslassen))
        #expect(ablauf.ausgelassen.isEmpty)
    }

    @Test("Ohne Ersatz auslassen setzt ausgelassen, ohne Client")
    func ohneErsatzAuslassenSetztAusgelassen() async {
        for option in [PlanTausch.EntfernOption.heuteAuslassen, .belegt] {
            let ablauf = Self.vorbereitet()
            let client = TauschClientAttrappe()
            let sut = Self.sitzung(Self.mitOrt(ablauf), ablauf: ablauf, client: client, umgebung: Umgebung())
            sut.ersatzGewaehlt(nil)

            #expect(sut.grundWaehlen(option))
            #expect(ablauf.ausgelassen.contains("A0"))
            #expect(ablauf.zustand?.positionen.first?.status == .offen)
            #expect(await client.aufrufe.isEmpty)
        }
    }

    @Test("Gefaellt mir nicht sendet den Grund mit dem Ort; der alte Weg ohne Grund keinen")
    func gefaelltNichtUndOhneGrund() async throws {
        let ablauf = Self.vorbereitet()
        let client = TauschClientAttrappe()
        let auftrag = Self.mitOrt(ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: Umgebung())
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })
        sut.ersatzGewaehlt(schraeg)
        #expect(!sut.grundWaehlen(.gefaelltNicht))
        #expect(await sut.uebernehmen())

        // Der alte Weg (Schalter) schickt weder Grund noch Ort.
        let sut2 = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: Umgebung())
        sut2.dauerhaftSetzen(true)
        _ = sut2.waehlen(schraeg)
        #expect(await sut2.uebernehmen())
        let aufrufe = await client.aufrufe
        #expect(aufrufe.map(\.grund) == ["gefaellt_nicht", nil])
        #expect(aufrufe.map(\.ortId) == ["s1", nil])
    }

    @Test("Der alte Weg waehlt auch einen Ersatz ausserhalb der Kandidaten")
    func waehlenNimmtFremdenErsatz() {
        let ablauf = Self.vorbereitet()
        let sut = Self.sitzung(Self.auftrag("A0", ablauf: ablauf), ablauf: ablauf,
                               client: TauschClientAttrappe(), umgebung: Umgebung())
        #expect(sut.waehlen(Self.fremd))
        #expect(ablauf.zustand?.positionen.first?.ersatzExerciseId == "e77")
    }

    @Test("Texte der drei Optionen")
    func grundTexte() {
        #expect(PlanTausch.EntfernOption.heuteAuslassen.titel == "Heute auslassen")
        #expect(PlanTausch.EntfernOption.belegt.titel == "Belegt")
        #expect(PlanTausch.EntfernOption.gefaelltNicht.titel == "Übung gefällt mir nicht")
        #expect(PlanTausch.EntfernOption.heuteAuslassen.serverGrund == nil)
        #expect(PlanTausch.EntfernOption.belegt.serverGrund == nil)
        #expect(PlanTausch.EntfernOption.gefaelltNicht.serverGrund == "gefaellt_nicht")
    }
}

/// Realistische Form: ein Studio-Geraet hat sein EIGENES equipment_models-
/// Zeile (`sm-…`) und verweist ueber `catalogModelId` auf den Katalogtyp
/// (`em-…`); Planposition und Alternativen nennen den Katalogtyp.
@MainActor
@Suite("PlanTauschStudio")
struct PlanTauschStudioTests {
    typealias T = PlanTauschTestdaten

    static func uebung(_ id: String, _ name: String, _ muskeln: String) -> String {
        #"{"id":"\#(id)","name":"\#(name)","volumeKind":"reps","targetMin":8,"targetMax":12,"muscles":\#(muskeln)}"#
    }

    static let schulter = #"[{"key":"deltoid_front","name":"Schulter vorn","role":"primary"}]"#

    static func geraet(_ id: String, katalog: String, label: String, uebung: String) -> BootstrapResponse.Machine {
        GeraetTestdaten.dekodiere("""
        {"id":"\(id)","studioId":"s1","label":"\(label)","locationNote":null,"status":"active",
         "tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"sm-\(id)","name":"Modell \(id)","manufacturer":null,"category":"kraft","photoPath":null,
           "loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,"settingDefinitions":[],
           "catalogModelId":"\(katalog)"},
         "exercises":[\(uebung)]}
        """)
    }

    static func typ(_ id: String, uebung: String) -> BootstrapResponse.Catalog.EquipmentType {
        GeraetTestdaten.dekodiere("""
        {"id":"\(id)","name":"Typ \(id)","manufacturer":null,"photoPath":null,"category":"kraft",
         "loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,"settingDefinitions":[],
         "exercises":[\(uebung)]}
        """)
    }

    /// Mit Studio-Geraeten (e8 an Typ em-m8, e7 an em-m7, e1 an em-m1), Katalog daneben.
    static func bootstrapImStudio() -> BootstrapResponse {
        let plan = T.plan()
        var b = BootstrapResponse(
            member: .init(displayName: nil, plans: [plan]),
            studios: [.init(id: "s1", name: "Nord", timezone: "Europe/Berlin")],
            machines: [
            geraet("m1", katalog: "em-m1", label: "Gerät 12", uebung: uebung("e1", "Brustpresse", T.brust)),
            geraet("m7", katalog: "em-m7", label: "Gerät 14", uebung: uebung("e7", "Schrägbankpresse", T.brust)),
            geraet("m8", katalog: "em-m8", label: "Gerät 9", uebung: uebung("e8", "Schulterdrücken", schulter)),
            ], calibrations: [], lastSets: [])
        b.catalog = nil
        return b
    }

    /// Freies Training: keine Geraete, nur der Katalog.
    static func bootstrapFrei() -> BootstrapResponse {
        let plan = T.plan()
        var b = BootstrapResponse(
            member: .init(displayName: nil, plans: [plan]),
            studios: [.init(id: "s1", name: "Nord", timezone: "Europe/Berlin")],
            machines: [], calibrations: [], lastSets: [])
        let katalog = BootstrapResponse.Catalog(studioId: "kat1", equipmentTypes: [
            typ("em-m1", uebung: uebung("e1", "Brustpresse", T.brust)),
            typ("em-m7", uebung: uebung("e7", "Schrägbankpresse", T.brust)),
            typ("em-m8", uebung: uebung("e8", "Schulterdrücken", schulter)),
        ])
        b.catalog = katalog
        return b
    }

    static func auftrag(_ bootstrap: BootstrapResponse, ort: String?) -> PlanTauschAuftrag {
        let plan = T.plan()
        let heute = PlanAnzeige.Heute(plan: plan, einheit: plan.einheiten[0], zustand: nil, ausgelassen: [])
        return PlanTausch.auftrag(position: plan.einheiten[0].positionen[0], heute: heute,
                                  bootstrap: bootstrap, ort: ort)
    }

    @Test("Studio: Kandidaten tragen Geraet und Muskeln ueber catalogModelId")
    func kandidatenImStudio() throws {
        let kandidaten = Self.auftrag(Self.bootstrapImStudio(), ort: "s1").kandidaten
        let schulter = try #require(kandidaten.first { $0.exerciseId == "e8" })
        #expect(schulter.geraet == "Gerät 9")
        #expect(schulter.hauptmuskeln == ["deltoid_front"])
        #expect(schulter.muskeln == "Schulter vorn")
        let schraeg = try #require(kandidaten.first { $0.exerciseId == "e7" })
        #expect(schraeg.geraet == "Gerät 14")
        #expect(schraeg.hauptmuskeln == ["chest"])
    }

    @Test("Studio: Vorgesehen am Geraet findet das Geraet ueber catalogModelId")
    func vorgesehenImStudio() {
        let plan = T.plan()
        let text = PlanTausch.vorgesehen(position: plan.einheiten[0].positionen[0], bootstrap: Self.bootstrapImStudio())
        #expect(text?.contains("Gerät 12") == true)
    }

    @Test("Studio: Belegt-Tausch schreibt die Hauptmuskeln der neuen Uebung in den Lauf")
    func belegtBehaeltMuskeln() throws {
        let ablauf = PlanTauschTests.vorbereitet()
        let auftrag = Self.auftrag(Self.bootstrapImStudio(), ort: "s1")
        let sut = PlanTauschTests.sitzung(auftrag, ablauf: ablauf, client: TauschClientAttrappe(),
                                          umgebung: .init())
        let schulter = try #require(auftrag.kandidaten.first { $0.exerciseId == "e8" })
        sut.ersatzGewaehlt(schulter)
        #expect(sut.grundWaehlen(.belegt))
        let position = try #require(ablauf.zustand?.positionen.first { $0.key == "A0" })
        #expect(position.hauptmuskeln == ["deltoid_front"])
    }

    @Test("Freies Training: ohne Geraete Muskeln und Bezeichnung aus dem Katalogtyp")
    func freiesTrainingKatalogFallback() throws {
        let kandidaten = Self.auftrag(Self.bootstrapFrei(), ort: "kat1").kandidaten
        let schulter = try #require(kandidaten.first { $0.exerciseId == "e8" })
        #expect(schulter.hauptmuskeln == ["deltoid_front"])
        #expect(schulter.muskeln == "Schulter vorn")
        #expect(schulter.geraet == "Typ em-m8")
        #expect(schulter.name == "Schulterdrücken")
    }

    // MARK: - Kandidat aus Station und Uebung

    @Test("kandidat: Studiogeraet liefert Katalogmodell, Name, Geraet und Hauptmuskeln")
    func kandidatAusStudiogeraet() throws {
        let bootstrap = Self.bootstrapImStudio()
        let station = try #require(bootstrap.station(schluessel: "geraet:m8", studioId: "s1"))
        let kandidat = try #require(PlanTausch.kandidat(station: station, uebungId: "e8", bootstrap: bootstrap))
        #expect(kandidat.exerciseId == "e8")
        #expect(kandidat.modelId == "em-m8")
        #expect(kandidat.name == "Schulterdrücken")
        #expect(kandidat.geraet == "Gerät 9")
        #expect(kandidat.hauptmuskeln == ["deltoid_front"])
        #expect(kandidat.muskeln == "Schulter vorn")
        #expect(kandidat.vorschaubildModell == "em-m8")
    }

    @Test("kandidat: Katalogtyp liefert seine eigene ID als Modell")
    func kandidatAusKatalogtyp() throws {
        let bootstrap = Self.bootstrapFrei()
        let station = try #require(bootstrap.station(schluessel: "typ:em-m7", studioId: "kat1"))
        let kandidat = try #require(PlanTausch.kandidat(station: station, uebungId: "e7", bootstrap: bootstrap))
        #expect(kandidat.modelId == "em-m7")
        #expect(kandidat.hauptmuskeln == ["chest"])
        #expect(kandidat.name == "Schrägbankpresse")
    }

    @Test("kandidat: Uebung, die die Station nicht kennt, liefert nil")
    func kandidatUnbekannteUebung() throws {
        let bootstrap = Self.bootstrapImStudio()
        let station = try #require(bootstrap.station(schluessel: "geraet:m8", studioId: "s1"))
        #expect(PlanTausch.kandidat(station: station, uebungId: "e1", bootstrap: bootstrap) == nil)
    }
}
