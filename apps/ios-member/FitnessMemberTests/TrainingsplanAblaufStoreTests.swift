import Foundation
import Testing
@testable import FitnessMember

/// Der Ablauf der heutigen Planeinheit auf dem Geraet (Trainingsplan Etappe 3,
/// Task 9): welche Einheit dran ist, wie Saetze sie abhaken und was davon mit
/// dem Satz-PUT mitgeht.
@MainActor
struct TrainingsplanAblaufStoreTests {
    static let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionA = UUID()
    let sessionB = UUID()

    /// Zwei Einheiten: A mit Brust (e1), Ruecken (e2) und Cardio; B mit Beinen (e3).
    static func plan(planId: String = "p1", studioId: String = "s1", version: Int = 1,
                     naechste: String? = "A", positionA0: String = "e1",
                     zuletzt: String? = nil, erledigt: Int = 0) -> Trainingsplan {
        func position(_ key: String, _ baustein: String, _ exerciseId: String, _ muskeln: [String]) -> String {
            let liste = muskeln.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"key":"\(key)","baustein":"\(baustein)","rolle":"pflicht","exerciseId":"\(exerciseId)",
             "modelId":"m-\(exerciseId)","typ":"mehrgelenk","saetze":3,"wdhVon":8,"wdhBis":12,
             "reserveVon":1,"reserveBis":3,"pauseSek":120,"aufwaermsatz":false,"dauerMin":null,
             "hauptmuskeln":[\(liste)]}
            """
        }
        let naechsteJSON = naechste.map { "\"\($0)\"" } ?? "null"
        let zuletztJSON = zuletzt.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"planId":"\(planId)","studioId":"\(studioId)","version":\(version),"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":\(naechsteJSON),"zuletztEinheitKey":\(zuletztJSON),
         "einheitenErledigt":\(erledigt),"anfaengerUebergang":false,"alternativen":{},
         "einheiten":[
           {"key":"A","geschaetzteMinuten":45,"positionen":[
             \(position("A0", "brust", positionA0, ["chest"])),
             \(position("A1", "ruecken", "e2", ["lats"])),
             \(position("A2", "cardio", "c1", []))]},
           {"key":"B","geschaetzteMinuten":40,"positionen":[
             \(position("B0", "beine_knie", "e3", ["quads"]))]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    static func verzeichnis() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    static func store(_ verzeichnis: URL = verzeichnis()) -> TrainingsplanAblaufStore {
        TrainingsplanAblaufStore(fileStore: PlanAblaufFileStore(directory: verzeichnis))
    }

    static let brust = AblaufSatz(exerciseId: "e1", hauptmuskeln: ["chest"], cardio: false)

    @Test func vorbereitenWaehltDieNaechsteEinheitAusDemBootstrap() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(naechste: "B"), jetzt: Self.jetzt)

        #expect(sut.planId == "p1")
        #expect(sut.einheitKey == "B")
        #expect(sut.zustand?.positionen.map(\.key) == ["B0"])
        #expect(sut.gebundeneSessionId == nil)
    }

    @Test func dieCardioPositionIstAlsCardioMarkiert() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)

        #expect(sut.zustand?.positionen.map(\.cardio) == [false, false, true])
        #expect(sut.zustand?.positionen.allSatisfy { $0.status == .offen && $0.ersatzExerciseId == nil } == true)
    }

    /// Der Server hat die Einheit gezaehlt: er nennt sie als zuletzt, und sein
    /// Zaehler ist hoeher als beim Beenden.
    static let gezaehltA = plan(naechste: "B", zuletzt: "A", erledigt: 1)

    @Test func lokalZuletztHatVorrangBisDerServerDieEinheitGezaehltHat() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet(jetzt: Self.jetzt)

        // Der Server weiss noch nichts vom Ende: er nennt weiter A.
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        // Noch ein Satz in der Warteschlange: der Bootstrap kann veraltet sein,
        // auch wenn er die Einheit schon zu kennen scheint.
        sut.nachBootstrap(offeneSchreibvorgaenge: 1, plaene: [Self.gezaehltA], jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        // Leere Warteschlange und der Server hat sie gezaehlt: jetzt gilt
        // wieder der Server (hier ein spaeterer Bootstrap, der A nennt).
        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.gezaehltA], jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
    }

    /// completeSession kann noch unterwegs sein (Ortswechsel meldet im
    /// Hintergrund) oder mit 5xx gescheitert: ein frischer Bootstrap bei
    /// leerer Warteschlange kennt die Einheit dann noch nicht.
    @Test func lokalZuletztBleibtWennDerServerDieEinheitNochNichtGezaehltHat() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet(jetzt: Self.jetzt)

        let spaeter = Self.jetzt.addingTimeInterval(10 * 60)
        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.plan(naechste: "A")], jetzt: spaeter)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: spaeter)
        #expect(sut.einheitKey == "B")
    }

    /// Dieselbe Einheit war schon vorher die zuletzt gezaehlte (z. B. ein Plan
    /// mit nur einer Einheit): erst ein hoeherer Zaehler zeigt die neue.
    @Test func lokalZuletztBleibtBeiGleichemZuletztOhneHoeherenZaehler() {
        let sut = Self.store()
        // Der Server nennt A als naechste UND als zuletzt -- die Testdaten
        // erzwingen A, damit die lokale Zaehlung dieselbe Einheit betrifft.
        sut.vorbereiten(plan: Self.plan(naechste: "A", zuletzt: "A", erledigt: 3), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet(jetzt: Self.jetzt)

        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.plan(naechste: "A", zuletzt: "A", erledigt: 3)],
                          jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(naechste: "A", zuletzt: "A", erledigt: 3), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.plan(naechste: "B", zuletzt: "A", erledigt: 4)],
                          jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(naechste: "A", zuletzt: "A", erledigt: 4), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
    }

    /// Nach vier Stunden hat der Server die Einheit auch ohne completeSession
    /// abgeschlossen (Auto-Abschluss): die lokale Zaehlung darf nicht ewig
    /// gelten, falls er sie nie meldet.
    @Test func lokalZuletztFaelltNachVierStundenWeg() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet(jetzt: Self.jetzt)

        let knapp = Self.jetzt.addingTimeInterval(WorkoutSessionStore.sessionPause - 60)
        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.plan(naechste: "A")], jetzt: knapp)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: knapp)
        #expect(sut.einheitKey == "B")

        // Mit offenen Saetzen bleibt sie auch nach vier Stunden.
        let danach = Self.jetzt.addingTimeInterval(WorkoutSessionStore.sessionPause + 60)
        sut.nachBootstrap(offeneSchreibvorgaenge: 1, plaene: [Self.plan(naechste: "A")], jetzt: danach)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: danach)
        #expect(sut.einheitKey == "B")

        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.plan(naechste: "A")], jetzt: danach)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: danach)
        #expect(sut.einheitKey == "A")
    }

    /// Eine plan-ablauf.json von vor `beendetAm` muss weiter lesbar sein. Ohne
    /// Zeitpunkt gilt die Zaehlung als alt: sie wirkt bis zum naechsten
    /// frischen Bootstrap, haelt sich aber nicht ewig.
    @Test func alteDateiOhneBeendetAmBleibtLesbar() throws {
        let verzeichnis = Self.verzeichnis()
        try FileManager.default.createDirectory(at: verzeichnis, withIntermediateDirectories: true)
        let alt = #"{"lokalZuletzt":{"studioId":"s1","einheitKey":"A"}}"#
        try Data(alt.utf8).write(to: verzeichnis.appendingPathComponent("plan-ablauf.json"))

        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        sut.nachBootstrap(offeneSchreibvorgaenge: 0, plaene: [Self.plan(naechste: "A")], jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
    }

    @Test func nachSatzHaektAbUndErhoehtStand() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)

        let erste = try #require(sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt))
        #expect(erste.planId == "p1")
        #expect(erste.einheitKey == "A")
        #expect(erste.stand == 1)
        #expect(erste.positionen == [
            .init(key: "A0", status: .erledigt, exerciseId: nil),
            .init(key: "A1", status: .offen, exerciseId: nil),
            .init(key: "A2", status: .offen, exerciseId: nil),
        ])
        #expect(sut.gebundeneSessionId == sessionA)

        // Auch ein Satz, der nichts aendert, ist eine neue Momentaufnahme.
        let zweite = try #require(sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt))
        #expect(zweite.stand == 2)

        let cardio = try #require(sut.nachSatz(
            sessionId: sessionA,
            satz: AblaufSatz(exerciseId: "x9", hauptmuskeln: [], cardio: true), jetzt: Self.jetzt))
        #expect(cardio.stand == 3)
        #expect(cardio.positionen.map(\.status) == [.erledigt, .offen, .erledigt])
    }

    @Test func ohnePlanIstDieMomentaufnahmeNil() {
        let ohnePlan = Self.store()
        ohnePlan.vorbereiten(plan: nil, jetzt: Self.jetzt)
        #expect(ohnePlan.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt) == nil)
        #expect(ohnePlan.zustand == nil)
        #expect(ohnePlan.gebundeneSessionId == nil)
    }

    @Test func derPlanGiltOhneStudioAuchImFreienTraining() throws {
        let sut = Self.store()
        // Der Plan hat keine Studio-ID mehr als Bedingung: auch ein Plan ohne studioId zaehlt.
        let json = """
        {"id":"p9","version":1,"regelVersion":"1.2.0","struktur":"gk_ab","einheiten":[{"key":"A","positionen":[
          {"key":"A0","baustein":"brust","rolle":"pflicht","exerciseId":"e1","modelId":"m-e1","typ":"mehrgelenk",
           "saetze":3,"wdhVon":8,"wdhBis":12,"reserveVon":1,"reserveBis":3,"pauseSek":120,"aufwaermsatz":false,
           "dauerMin":null,"hauptmuskeln":["chest"]}]}]}
        """
        let plan = try JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
        sut.vorbereiten(plan: plan, jetzt: Self.jetzt)
        let satz = try #require(sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt))
        #expect(satz.planId == "p9")
        #expect(satz.positionen.first?.status == .erledigt)
    }

    /// Eine plan-ablauf.json von vor dem Katalogplan nennt `studioId` in
    /// Vorlage, Ablauf und lokaler Zaehlung. Das Feld wird ignoriert.
    @Test func liestEineAlteDateiMitStudioId() throws {
        let verzeichnis = Self.verzeichnis()
        let vorher = Self.store(verzeichnis)
        vorher.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = vorher.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        try Self.studioIdEinfuegen(verzeichnis)

        let sut = Self.store(verzeichnis)
        #expect(sut.planId == "p1")
        #expect(sut.einheitKey == "A")
        #expect(sut.gebundeneSessionId == sessionA)
        #expect(sut.stand == 1)
        #expect(sut.zustand?.positionen.first?.status == .erledigt)
    }

    @Test func verwirftDenAblaufEinesAnderenPlans() throws {
        let verzeichnis = Self.verzeichnis()
        let vorher = Self.store(verzeichnis)
        vorher.vorbereiten(plan: Self.plan(planId: "p-alt", studioId: "s-alt"), jetzt: Self.jetzt)
        try Self.studioIdEinfuegen(verzeichnis)

        let sut = Self.store(verzeichnis)
        #expect(sut.planId == "p-alt")
        sut.vorbereiten(plan: Self.plan(planId: "p1"), jetzt: Self.jetzt.addingTimeInterval(60))
        #expect(sut.planId == "p1")
        #expect(sut.zustand?.positionen.allSatisfy { $0.status == .offen } == true)
    }

    /// Macht aus einer frisch geschriebenen Datei die Form von vorher:
    /// `studioId` in Vorlage, Ablauf und lokaler Zaehlung.
    private static func studioIdEinfuegen(_ verzeichnis: URL) throws {
        let url = verzeichnis.appendingPathComponent("plan-ablauf.json")
        var datei = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for teil in ["vorlage", "lauf"] {
            var inhalt = try #require(datei[teil] as? [String: Any])
            inhalt["studioId"] = "s1"
            datei[teil] = inhalt
        }
        datei["lokalZuletzt"] = ["studioId": "s1", "einheitKey": "B"]
        try JSONSerialization.data(withJSONObject: datei).write(to: url)
    }

    @Test func zustandUeberlebtNeustart() throws {
        let verzeichnis = Self.verzeichnis()
        let vorher = Self.store(verzeichnis)
        vorher.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = vorher.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)

        let nachher = Self.store(verzeichnis)
        #expect(nachher.zustand == vorher.zustand)
        #expect(nachher.gebundeneSessionId == sessionA)
        #expect(nachher.einheitKey == "A")
        // Der Stand zaehlt nach dem Neustart weiter, nicht von vorn: sonst
        // ignorierte der Server jede weitere Momentaufnahme.
        let weiter = try #require(nachher.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt))
        #expect(weiter.stand == 2)
    }

    @Test func lokalZuletztUeberlebtNeustart() {
        let verzeichnis = Self.verzeichnis()
        let vorher = Self.store(verzeichnis)
        vorher.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = vorher.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        vorher.einheitBeendet()

        let nachher = Self.store(verzeichnis)
        nachher.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(nachher.einheitKey == "B")
    }

    @Test func gebundeneSessionBehaeltIhrePlanversionAuchWennEinNeuerPlanImBootstrapSteht() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        let vorher = sut.zustand

        // Dauerhafter Tausch mitten in der Einheit: Version 2 tauscht A0 gegen e7.
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"), jetzt: Self.jetzt)
        #expect(sut.planId == "p1")
        #expect(sut.zustand == vorher)

        let weiter = try #require(sut.nachSatz(
            sessionId: sessionA,
            satz: AblaufSatz(exerciseId: "e2", hauptmuskeln: ["lats"], cardio: false), jetzt: Self.jetzt))
        #expect(weiter.planId == "p1")
        #expect(weiter.einheitKey == "A")
        #expect(weiter.positionen.map(\.status) == [.erledigt, .erledigt, .offen])

        // Erst die naechste Einheit folgt der neuen Version.
        sut.einheitBeendet()
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"), jetzt: Self.jetzt)
        #expect(sut.planId == "p2")
        #expect(sut.einheitKey == "B")
    }

    @Test func eineNeuePlanversionErsetztDenZustandVorDemErstenSatz() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"), jetzt: Self.jetzt)

        #expect(sut.planId == "p2")
        #expect(sut.zustand?.positionen.first?.exerciseId == "e7")
    }

    @Test func einZustandOhneSatzVerfaelltNachZwoelfStunden() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        sut.tauschen(positionKey: "A0", ersatz: (exerciseId: "e7", hauptmuskeln: ["chest"]))

        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt.addingTimeInterval(11 * 3600))
        #expect(sut.zustand?.positionen.first?.status == .getauscht)

        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt.addingTimeInterval(13 * 3600))
        #expect(sut.zustand?.positionen.first?.status == .offen)
    }

    /// Eine nie beendete Einheit endet nach vier Stunden ohne Satz von selbst
    /// (Review Focus 5) -- sie zaehlt dann wie eine beendete.
    @Test func eineGebundeneEinheitOhneSatzSeitVierStundenGiltAlsBeendet() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)

        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt.addingTimeInterval(3 * 3600))
        #expect(sut.gebundeneSessionId == sessionA)

        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt.addingTimeInterval(5 * 3600))
        #expect(sut.gebundeneSessionId == nil)
        #expect(sut.einheitKey == "B")
    }

    @Test func einheitBeendetZaehltNurMitErledigterOderOptionalerPosition() {
        // Nur ungeplante Uebung ohne passende Muskeln: nichts erledigt, nichts optional.
        let ohne = Self.store()
        ohne.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = ohne.nachSatz(sessionId: sessionA,
                          satz: AblaufSatz(exerciseId: "x1", hauptmuskeln: ["calves"], cardio: false), jetzt: Self.jetzt)
        ohne.einheitBeendet()
        #expect(ohne.zustand == nil)
        ohne.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(ohne.einheitKey == "A")

        // Ungeplante Uebung mit passendem Muskel: Position wird optional, die Einheit zaehlt.
        let optional = Self.store()
        optional.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = optional.nachSatz(sessionId: sessionA,
                              satz: AblaufSatz(exerciseId: "x2", hauptmuskeln: ["chest"], cardio: false), jetzt: Self.jetzt)
        optional.einheitBeendet()
        optional.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(optional.einheitKey == "B")

        // Beenden ohne einen einzigen Satz zaehlt nie.
        let leer = Self.store()
        leer.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        leer.einheitBeendet()
        leer.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(leer.einheitKey == "A")
    }

    @Test func verwerfenZaehltNicht() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        // "Training verwerfen" auf dem Abschluss-Screen: die Einheit gab es nie.
        sut.einheitVerworfen(sessionId: sessionA)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
        #expect(sut.gebundeneSessionId == nil)
    }

    @Test func verwerfenEinerAnderenEinheitAendertNichts() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        sut.einheitVerworfen(sessionId: sessionB)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")
    }

    @Test func fortsetzenHoltDenAblaufDerBeendetenEinheitZurueck() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()
        sut.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        sut.einheitWiederaufgenommen(sessionId: sessionA)
        #expect(sut.einheitKey == "A")
        #expect(sut.gebundeneSessionId == sessionA)
        let weiter = try #require(sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt))
        #expect(weiter.stand == 2)
    }

    @Test func eineNeueSessionBeendetDieAlteGebundeneUndBeginntDieNaechsteEinheit() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)

        let neu = try #require(sut.nachSatz(
            sessionId: sessionB,
            satz: AblaufSatz(exerciseId: "e3", hauptmuskeln: ["quads"], cardio: false), jetzt: Self.jetzt))
        #expect(neu.einheitKey == "B")
        #expect(neu.stand == 1)
        #expect(sut.gebundeneSessionId == sessionB)
    }

    @Test func tauschenVorDemStartBleibtBisZumSatzErhalten() throws {
        let verzeichnis = Self.verzeichnis()
        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        sut.tauschen(positionKey: "A0", ersatz: (exerciseId: "e7", hauptmuskeln: ["chest"]))

        // Neuladen des Bootstraps und Neustart der App aendern daran nichts.
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt.addingTimeInterval(60))
        let nachNeustart = Self.store(verzeichnis)
        nachNeustart.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt.addingTimeInterval(120))
        #expect(nachNeustart.zustand?.positionen.first?.status == .getauscht)

        let satz = try #require(nachNeustart.nachSatz(
            sessionId: sessionA,
            satz: AblaufSatz(exerciseId: "e7", hauptmuskeln: ["chest"], cardio: false), jetzt: Self.jetzt))
        #expect(satz.positionen.first == .init(key: "A0", status: .erledigt, exerciseId: "e7"))
    }

    @Test func getauschtGehtMitErsatzuebungInDieMomentaufnahme() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        sut.tauschen(positionKey: "A1", ersatz: (exerciseId: "e8", hauptmuskeln: ["lats"]))

        let satz = try #require(sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt))
        #expect(satz.positionen[1] == .init(key: "A1", status: .getauscht, exerciseId: "e8"))
    }

    @Test func resetLoeschtAllesAuchAufDerPlatte() {
        let verzeichnis = Self.verzeichnis()
        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        sut.reset()

        let nachher = Self.store(verzeichnis)
        #expect(nachher.zustand == nil)
        nachher.vorbereiten(plan: Self.plan(naechste: "A"), jetzt: Self.jetzt)
        #expect(nachher.einheitKey == "A")
    }

    // MARK: - Umordnen und Auslassen

    @Test func umordnenSpeichertImLauf() {
        let verzeichnis = Self.verzeichnis()
        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        let vorher = sut.stand

        sut.umordnen(positionKey: "A2", nach: 0)

        #expect(sut.zustand?.positionen.map(\.key) == ["A2", "A0", "A1"])
        #expect(sut.stand == vorher + 1)
        #expect(Self.store(verzeichnis).zustand?.positionen.map(\.key) == ["A2", "A0", "A1"])
    }

    @Test func ausgelassenUeberlebtSpeichernUndLaden() {
        let verzeichnis = Self.verzeichnis()
        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)

        sut.auslassen(positionKey: "A1")

        #expect(sut.ausgelassen == ["A1"])
        #expect(Self.store(verzeichnis).ausgelassen == ["A1"])
    }

    @Test func auslassenZuruecknehmen() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        sut.auslassen(positionKey: "A1")
        sut.auslassen(positionKey: "A1")
        #expect(sut.ausgelassen == ["A1"])

        sut.auslassenZuruecknehmen(positionKey: "A1")

        #expect(sut.ausgelassen.isEmpty)
    }

    /// Einheit A mit frei gewaehlten Positionen (alle Kraft), fuer neue
    /// Planversionen mit anderen Schluesseln.
    static func plan(planId: String, version: Int, positionenA: [(key: String, exerciseId: String)]) -> Trainingsplan {
        let liste = positionenA.map { p in
            """
            {"key":"\(p.key)","baustein":"brust","rolle":"pflicht","exerciseId":"\(p.exerciseId)",
             "modelId":"m-\(p.exerciseId)","typ":"mehrgelenk","saetze":3,"wdhVon":8,"wdhBis":12,
             "reserveVon":1,"reserveBis":3,"pauseSek":120,"aufwaermsatz":false,"dauerMin":null,
             "hauptmuskeln":["chest"]}
            """
        }.joined(separator: ",")
        let json = """
        {"planId":"\(planId)","studioId":"s1","version":\(version),"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":{},
         "einheiten":[{"key":"A","geschaetzteMinuten":45,"positionen":[\(liste)]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    /// "Gefällt mir nicht" vor dem ersten Satz legt eine neue Version an; was
    /// das Mitglied heute schon umgestellt hat, darf dabei nicht verschwinden.
    @Test func eineNeuePlanversionVorDemErstenSatzBehaeltAusgelassenUndReihenfolge() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), jetzt: Self.jetzt)
        sut.umordnen(positionKey: "A2", nach: 0)
        sut.auslassen(positionKey: "A1")

        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"),
                        jetzt: Self.jetzt.addingTimeInterval(60))

        #expect(sut.planId == "p2")
        #expect(sut.zustand?.positionen.map(\.key) == ["A2", "A0", "A1"])
        #expect(sut.zustand?.positionen.first { $0.key == "A0" }?.exerciseId == "e7")
        #expect(sut.ausgelassen == ["A1"])
    }

    @Test func eineNeuePlanversionLaesstUnbekannteSchluesselFallenUndHaengtNeueAn() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), jetzt: Self.jetzt)
        sut.umordnen(positionKey: "A2", nach: 0)  // A2, A0, A1
        sut.auslassen(positionKey: "A1")
        sut.auslassen(positionKey: "A2")

        // Version 2: A1 gibt es nicht mehr, A3 kommt dazu (in der Mitte des Plans).
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2,
                                        positionenA: [("A0", "e1"), ("A3", "e9"), ("A2", "e4")]),
                        jetzt: Self.jetzt.addingTimeInterval(60))

        #expect(sut.zustand?.positionen.map(\.key) == ["A2", "A0", "A3"])
        #expect(sut.ausgelassen == ["A2"])
    }

    @Test func einVerfallenerLaufGibtAusgelassenUndReihenfolgeNichtWeiter() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), jetzt: Self.jetzt)
        sut.umordnen(positionKey: "A2", nach: 0)
        sut.auslassen(positionKey: "A1")

        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"),
                        jetzt: Self.jetzt.addingTimeInterval(13 * 3600))

        #expect(sut.zustand?.positionen.map(\.key) == ["A0", "A1", "A2"])
        #expect(sut.ausgelassen.isEmpty)
    }

    @Test func alteDateiOhneAusgelassenLaedt() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), jetzt: Self.jetzt)
        let lauf = PlanLauf(
            planId: "p1", version: 1, einheitKey: "A", zustand: try #require(sut.zustand),
            stand: 0, gebundeneSessionId: nil, erstelltAm: Self.jetzt, letzterSatzAm: nil)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(lauf)) as? [String: Any])
        json.removeValue(forKey: "ausgelassen")
        let alt = try JSONSerialization.data(withJSONObject: json)

        let geladen = try JSONDecoder().decode(PlanLauf.self, from: alt)

        #expect(geladen.ausgelassen == [])
        #expect(geladen.einheitKey == "A")
    }
}
