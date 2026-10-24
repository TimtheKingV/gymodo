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
                     naechste: String? = "A", positionA0: String = "e1") -> Trainingsplan {
        func position(_ key: String, _ baustein: String, _ exerciseId: String, _ muskeln: [String]) -> String {
            let liste = muskeln.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"key":"\(key)","baustein":"\(baustein)","rolle":"pflicht","exerciseId":"\(exerciseId)",
             "machineId":"m-\(exerciseId)","typ":"mehrgelenk","saetze":3,"wdhVon":8,"wdhBis":12,
             "reserveVon":1,"reserveBis":3,"pauseSek":120,"aufwaermsatz":false,"dauerMin":null,
             "hauptmuskeln":[\(liste)]}
            """
        }
        let naechsteJSON = naechste.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"planId":"\(planId)","studioId":"\(studioId)","version":\(version),"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":\(naechsteJSON),"zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":{},
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
        sut.vorbereiten(plan: Self.plan(naechste: "B"), studioId: "s1", jetzt: Self.jetzt)

        #expect(sut.planId == "p1")
        #expect(sut.einheitKey == "B")
        #expect(sut.zustand?.positionen.map(\.key) == ["B0"])
        #expect(sut.gebundeneSessionId == nil)
    }

    @Test func dieCardioPositionIstAlsCardioMarkiert() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)

        #expect(sut.zustand?.positionen.map(\.cardio) == [false, false, true])
        #expect(sut.zustand?.positionen.allSatisfy { $0.status == .offen && $0.ersatzExerciseId == nil } == true)
    }

    @Test func lokalZuletztHatVorrangBisNachBootstrapBeiLeererWarteschlange() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        // Der Server weiss noch nichts vom Ende: er nennt weiter A.
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        // Noch ein Satz in der Warteschlange: der Bootstrap kann veraltet sein.
        sut.nachBootstrap(offeneSchreibvorgaenge: 1)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        // Leere Warteschlange: jetzt gilt wieder der Server.
        sut.nachBootstrap(offeneSchreibvorgaenge: 0)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
    }

    @Test func nachSatzHaektAbUndErhoehtStand() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)

        let erste = try #require(sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt))
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
        let zweite = try #require(sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt))
        #expect(zweite.stand == 2)

        let cardio = try #require(sut.nachSatz(
            sessionId: sessionA, studioId: "s1",
            satz: AblaufSatz(exerciseId: "x9", hauptmuskeln: [], cardio: true), jetzt: Self.jetzt))
        #expect(cardio.stand == 3)
        #expect(cardio.positionen.map(\.status) == [.erledigt, .offen, .erledigt])
    }

    @Test func ohnePlanImFreienTrainingUndInAnderemStudioIstDieMomentaufnahmeNil() {
        let ohnePlan = Self.store()
        ohnePlan.vorbereiten(plan: nil, studioId: "s1", jetzt: Self.jetzt)
        #expect(ohnePlan.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt) == nil)
        #expect(ohnePlan.zustand == nil)

        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.nachSatz(sessionId: sessionA, studioId: nil, satz: Self.brust, jetzt: Self.jetzt) == nil)
        #expect(sut.nachSatz(sessionId: sessionA, studioId: "s2", satz: Self.brust, jetzt: Self.jetzt) == nil)
        // Nichts gebunden, nichts abgehakt.
        #expect(sut.gebundeneSessionId == nil)
        #expect(sut.zustand?.positionen.allSatisfy { $0.status == .offen } == true)
        #expect(sut.stand == 0)

        // Ein Plan eines anderen Studios gilt hier nicht.
        let fremd = Self.store()
        fremd.vorbereiten(plan: Self.plan(studioId: "s2"), studioId: "s1", jetzt: Self.jetzt)
        #expect(fremd.zustand == nil)
        #expect(fremd.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt) == nil)
    }

    @Test func zustandUeberlebtNeustart() throws {
        let verzeichnis = Self.verzeichnis()
        let vorher = Self.store(verzeichnis)
        vorher.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = vorher.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)

        let nachher = Self.store(verzeichnis)
        #expect(nachher.zustand == vorher.zustand)
        #expect(nachher.gebundeneSessionId == sessionA)
        #expect(nachher.einheitKey == "A")
        // Der Stand zaehlt nach dem Neustart weiter, nicht von vorn: sonst
        // ignorierte der Server jede weitere Momentaufnahme.
        let weiter = try #require(nachher.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt))
        #expect(weiter.stand == 2)
    }

    @Test func lokalZuletztUeberlebtNeustart() {
        let verzeichnis = Self.verzeichnis()
        let vorher = Self.store(verzeichnis)
        vorher.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = vorher.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        vorher.einheitBeendet()

        let nachher = Self.store(verzeichnis)
        nachher.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(nachher.einheitKey == "B")
    }

    @Test func gebundeneSessionBehaeltIhrePlanversionAuchWennEinNeuerPlanImBootstrapSteht() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        let vorher = sut.zustand

        // Dauerhafter Tausch mitten in der Einheit: Version 2 tauscht A0 gegen e7.
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.planId == "p1")
        #expect(sut.zustand == vorher)

        let weiter = try #require(sut.nachSatz(
            sessionId: sessionA, studioId: "s1",
            satz: AblaufSatz(exerciseId: "e2", hauptmuskeln: ["lats"], cardio: false), jetzt: Self.jetzt))
        #expect(weiter.planId == "p1")
        #expect(weiter.einheitKey == "A")
        #expect(weiter.positionen.map(\.status) == [.erledigt, .erledigt, .offen])

        // Erst die naechste Einheit folgt der neuen Version.
        sut.einheitBeendet()
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.planId == "p2")
        #expect(sut.einheitKey == "B")
    }

    @Test func eineNeuePlanversionErsetztDenZustandVorDemErstenSatz() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(planId: "p1", version: 1), studioId: "s1", jetzt: Self.jetzt)
        sut.vorbereiten(plan: Self.plan(planId: "p2", version: 2, positionA0: "e7"), studioId: "s1", jetzt: Self.jetzt)

        #expect(sut.planId == "p2")
        #expect(sut.zustand?.positionen.first?.exerciseId == "e7")
    }

    @Test func einZustandOhneSatzVerfaelltNachZwoelfStunden() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        sut.tauschen(positionKey: "A0", ersatz: (exerciseId: "e7", hauptmuskeln: ["chest"]))

        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(11 * 3600))
        #expect(sut.zustand?.positionen.first?.status == .getauscht)

        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(13 * 3600))
        #expect(sut.zustand?.positionen.first?.status == .offen)
    }

    /// Eine nie beendete Einheit endet nach vier Stunden ohne Satz von selbst
    /// (Review Focus 5) -- sie zaehlt dann wie eine beendete.
    @Test func eineGebundeneEinheitOhneSatzSeitVierStundenGiltAlsBeendet() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)

        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(3 * 3600))
        #expect(sut.gebundeneSessionId == sessionA)

        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(5 * 3600))
        #expect(sut.gebundeneSessionId == nil)
        #expect(sut.einheitKey == "B")
    }

    @Test func einheitBeendetZaehltNurMitErledigterOderOptionalerPosition() {
        // Nur ungeplante Uebung ohne passende Muskeln: nichts erledigt, nichts optional.
        let ohne = Self.store()
        ohne.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = ohne.nachSatz(sessionId: sessionA, studioId: "s1",
                          satz: AblaufSatz(exerciseId: "x1", hauptmuskeln: ["calves"], cardio: false), jetzt: Self.jetzt)
        ohne.einheitBeendet()
        #expect(ohne.zustand == nil)
        ohne.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(ohne.einheitKey == "A")

        // Ungeplante Uebung mit passendem Muskel: Position wird optional, die Einheit zaehlt.
        let optional = Self.store()
        optional.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = optional.nachSatz(sessionId: sessionA, studioId: "s1",
                              satz: AblaufSatz(exerciseId: "x2", hauptmuskeln: ["chest"], cardio: false), jetzt: Self.jetzt)
        optional.einheitBeendet()
        optional.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(optional.einheitKey == "B")

        // Beenden ohne einen einzigen Satz zaehlt nie.
        let leer = Self.store()
        leer.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        leer.einheitBeendet()
        leer.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(leer.einheitKey == "A")
    }

    @Test func verwerfenZaehltNicht() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        // "Training verwerfen" auf dem Abschluss-Screen: die Einheit gab es nie.
        sut.einheitVerworfen(sessionId: sessionA)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.einheitKey == "A")
        #expect(sut.gebundeneSessionId == nil)
    }

    @Test func verwerfenEinerAnderenEinheitAendertNichts() {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        sut.einheitVerworfen(sessionId: sessionB)
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")
    }

    @Test func fortsetzenHoltDenAblaufDerBeendetenEinheitZurueck() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()
        sut.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(sut.einheitKey == "B")

        sut.einheitWiederaufgenommen(sessionId: sessionA)
        #expect(sut.einheitKey == "A")
        #expect(sut.gebundeneSessionId == sessionA)
        let weiter = try #require(sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt))
        #expect(weiter.stand == 2)
    }

    @Test func eineNeueSessionBeendetDieAlteGebundeneUndBeginntDieNaechsteEinheit() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)

        let neu = try #require(sut.nachSatz(
            sessionId: sessionB, studioId: "s1",
            satz: AblaufSatz(exerciseId: "e3", hauptmuskeln: ["quads"], cardio: false), jetzt: Self.jetzt))
        #expect(neu.einheitKey == "B")
        #expect(neu.stand == 1)
        #expect(sut.gebundeneSessionId == sessionB)
    }

    @Test func tauschenVorDemStartBleibtBisZumSatzErhalten() throws {
        let verzeichnis = Self.verzeichnis()
        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        sut.tauschen(positionKey: "A0", ersatz: (exerciseId: "e7", hauptmuskeln: ["chest"]))

        // Neuladen des Bootstraps und Neustart der App aendern daran nichts.
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(60))
        let nachNeustart = Self.store(verzeichnis)
        nachNeustart.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt.addingTimeInterval(120))
        #expect(nachNeustart.zustand?.positionen.first?.status == .getauscht)

        let satz = try #require(nachNeustart.nachSatz(
            sessionId: sessionA, studioId: "s1",
            satz: AblaufSatz(exerciseId: "e7", hauptmuskeln: ["chest"], cardio: false), jetzt: Self.jetzt))
        #expect(satz.positionen.first == .init(key: "A0", status: .erledigt, exerciseId: "e7"))
    }

    @Test func getauschtGehtMitErsatzuebungInDieMomentaufnahme() throws {
        let sut = Self.store()
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        sut.tauschen(positionKey: "A1", ersatz: (exerciseId: "e8", hauptmuskeln: ["lats"]))

        let satz = try #require(sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt))
        #expect(satz.positionen[1] == .init(key: "A1", status: .getauscht, exerciseId: "e8"))
    }

    @Test func resetLoeschtAllesAuchAufDerPlatte() {
        let verzeichnis = Self.verzeichnis()
        let sut = Self.store(verzeichnis)
        sut.vorbereiten(plan: Self.plan(), studioId: "s1", jetzt: Self.jetzt)
        _ = sut.nachSatz(sessionId: sessionA, studioId: "s1", satz: Self.brust, jetzt: Self.jetzt)
        sut.einheitBeendet()

        sut.reset()

        let nachher = Self.store(verzeichnis)
        #expect(nachher.zustand == nil)
        nachher.vorbereiten(plan: Self.plan(naechste: "A"), studioId: "s1", jetzt: Self.jetzt)
        #expect(nachher.einheitKey == "A")
    }
}
