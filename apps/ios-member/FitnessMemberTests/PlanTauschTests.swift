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
                     machineA0: String = "m1", alternativen: String? = nil) -> Trainingsplan {
        func position(_ key: String, _ baustein: String, _ exerciseId: String, _ machineId: String,
                      _ muskeln: [String], pause: Int = 150, dauer: String = "null",
                      wdh: (String, String) = ("8", "12")) -> String {
            let liste = muskeln.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"key":"\(key)","baustein":"\(baustein)","rolle":"pflicht","exerciseId":"\(exerciseId)",
             "machineId":"\(machineId)","typ":"mehrgelenk","saetze":3,"wdhVon":\(wdh.0),"wdhBis":\(wdh.1),
             "reserveVon":1,"reserveBis":3,"pauseSek":\(pause),"aufwaermsatz":false,"dauerMin":\(dauer),
             "hauptmuskeln":[\(liste)]}
            """
        }
        let alternativenJSON = alternativen ?? """
        {"druecken":[{"exerciseId":"e8","machineId":"m8"},{"exerciseId":"e1","machineId":"m1"},
                     {"exerciseId":"e7","machineId":"m7"},{"exerciseId":"e2","machineId":"m2"},
                     {"exerciseId":"e9","machineId":"m9"},{"exerciseId":"e5","machineId":"m1"}],
         "cardio":[{"exerciseId":"c2","machineId":"m10"}]}
        """
        let json = """
        {"planId":"\(planId)","studioId":"s1","version":\(version),"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":\(alternativenJSON),
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
        let planId, einheitKey, positionKey, exerciseId, machineId: String
    }

    private(set) var aufrufe: [Aufruf] = []
    private var fehler: [APIError]

    init(fehler: [APIError] = []) {
        self.fehler = fehler
    }

    func swapPlanPosition(planId: String, einheitKey: String, positionKey: String, exerciseId: String,
                          machineId: String) async throws(APIError) -> Trainingsplan {
        aufrufe.append(Aufruf(planId: planId, einheitKey: einheitKey, positionKey: positionKey,
                              exerciseId: exerciseId, machineId: machineId))
        if !fehler.isEmpty { throw fehler.removeFirst() }
        return PlanTauschTestdaten.plan(planId: "p2", version: 2, positionA0: exerciseId, machineA0: machineId)
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

    static func heute(_ plan: Trainingsplan = T.plan(), ablauf: TrainingsplanAblaufStore) -> PlanAnzeige.Heute {
        PlanAnzeige.heute(bootstrap: T.bootstrap(plan: plan), studioId: "s1",
                          ablaufPlanId: ablauf.planId, ablaufEinheitKey: ablauf.einheitKey,
                          ablaufZustand: ablauf.zustand, naechsteEinheitKey: ablauf.naechsteEinheitKey,
                          ablaufGebunden: ablauf.gebundeneSessionId != nil, ablaufStudioId: ablauf.studioId)!
    }

    static func auftrag(_ key: String, ablauf: TrainingsplanAblaufStore,
                        plan: Trainingsplan = T.plan()) -> PlanTauschAuftrag {
        let heute = heute(plan, ablauf: ablauf)
        let position = heute.einheit.positionen.first { $0.key == key }!
        return PlanTausch.auftrag(position: position, heute: heute, bootstrap: T.bootstrap(plan: plan))
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
                    ablauf.vorbereiten(plan: plan, studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(60))
                }
            })
    }

    static func vorbereitet() -> TrainingsplanAblaufStore {
        let ablauf = store()
        ablauf.vorbereiten(plan: T.plan(), studioId: "s1", jetzt: jetzt)
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
        #expect(schraeg.machineId == "m7")
    }

    @Test("keine Kandidaten -> kein Knopf Andere Uebung")
    func keineKandidatenKeinKnopf() async {
        let ablauf = Self.vorbereitet()
        let auftrag = Self.auftrag("A1", ablauf: ablauf)
        #expect(auftrag.kandidaten.isEmpty)
        #expect(!auftrag.zeigtAndereUebung)

        // Auch ein Aufruf von aussen oeffnet nie eine leere Liste.
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: TauschClientAttrappe(), umgebung: Umgebung())
        sut.andereUebung()
        #expect(sut.schritt == .vorgabe)

        // Mit Kandidaten gibt es den Knopf.
        #expect(Self.auftrag("A0", ablauf: ablauf).zeigtAndereUebung)
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

        sut.andereUebung()
        #expect(sut.schritt == .kandidaten)
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

        sut.andereUebung()
        sut.dauerhaftSetzen(true)
        // Mit Schalter schreibt "Wählen" nichts, es folgt die Bestaetigung (3.3).
        #expect(!sut.waehlen(schraeg))
        #expect(sut.schritt == .bestaetigen(schraeg))
        #expect(await client.aufrufe.isEmpty)
        #expect(ablauf.zustand?.positionen.first?.status == .offen)

        #expect(await sut.uebernehmen())
        #expect(await client.aufrufe == [.init(planId: "p1", einheitKey: "A", positionKey: "A0",
                                               exerciseId: "e7", machineId: "m7")])
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
        sut.andereUebung()

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
        #expect(sut.schritt == .kandidaten)
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

        sut.andereUebung()
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

        sut.andereUebung()
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
        sut.andereUebung()
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
        _ = ablauf.nachSatz(sessionId: UUID(), studioId: "s1",
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
        _ = ablauf.nachSatz(sessionId: UUID(), studioId: "s1",
                            satz: AblaufSatz(exerciseId: "e4", hauptmuskeln: ["lats"], cardio: false), jetzt: Self.jetzt)
        let optional = Self.auftrag("A1", ablauf: ablauf, plan: T.plan(alternativen: """
            {"ziehen":[{"exerciseId":"e8","machineId":"m8"}]}
            """))
        #expect(optional.status == .optional)
        #expect(!optional.tauschbar)
    }

    // MARK: - Laufende Einheit

    @Test("Tausch waehrend laufender Einheit aendert deren Planversion nicht")
    func laufendeEinheitBehaeltVersion() async throws {
        let ablauf = Self.vorbereitet()
        let session = UUID()
        _ = ablauf.nachSatz(sessionId: session, studioId: "s1",
                            satz: AblaufSatz(exerciseId: "e2", hauptmuskeln: ["lats"], cardio: false), jetzt: Self.jetzt)
        let vorher = ablauf.zustand
        let client = TauschClientAttrappe()
        let umgebung = Umgebung()
        let neu = T.plan(planId: "p2", version: 2, positionA0: "e7", machineA0: "m7")
        umgebung.neuerPlan = neu
        let auftrag = Self.auftrag("A0", ablauf: ablauf)
        let sut = Self.sitzung(auftrag, ablauf: ablauf, client: client, umgebung: umgebung)
        let schraeg = try #require(auftrag.kandidaten.first { $0.exerciseId == "e7" })

        sut.andereUebung()
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
        sut2.andereUebung()
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
}
