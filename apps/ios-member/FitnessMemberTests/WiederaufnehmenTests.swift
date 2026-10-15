import Foundation
import Testing
@testable import FitnessMember

/// Training fortsetzen (Testnotiz 14.10., 18:45 #3/#4): die zuletzt
/// beendete Einheit bleibt 30 Minuten lokal, und die Luecke zaehlt als Pause.
@MainActor
struct WiederaufnehmenTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func store(_ verzeichnis: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)) -> WorkoutSessionStore {
        WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    }

    /// Ein Training mit einem Satz bei t0+10 min, beendet bei t0+20 min.
    private func beendet(_ sessions: WorkoutSessionStore) -> UUID {
        sessions.trainingStarten(jetzt: t0)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil,
                                  jetzt: t0.addingTimeInterval(600))
        return sessions.beenden(jetzt: t0.addingTimeInterval(1200))!
    }

    @Test func beendenLegtDieEinheitAb() {
        let sessions = store()
        let id = beendet(sessions)
        #expect(sessions.aktiveSession(jetzt: t0.addingTimeInterval(1201)) == nil)
        #expect(sessions.zuletztBeendet?.session.id == id)
        #expect(sessions.zuletztBeendet?.beendetAm == t0.addingTimeInterval(1200))
    }

    @Test func ohneSatzWirdNichtAbgelegt() {
        let sessions = store()
        sessions.trainingStarten(jetzt: t0)
        sessions.beenden(jetzt: t0.addingTimeInterval(60))
        #expect(sessions.zuletztBeendet == nil)
    }

    @Test func dasFensterIstDreissigMinuten() {
        let sessions = store()
        let id = beendet(sessions).uuidString
        #expect(sessions.kannWiederaufnehmen(sessionId: id, jetzt: t0.addingTimeInterval(1200 + 1800)))
        #expect(!sessions.kannWiederaufnehmen(sessionId: id, jetzt: t0.addingTimeInterval(1200 + 1801)))
        #expect(!sessions.kannWiederaufnehmen(sessionId: UUID().uuidString, jetzt: t0.addingTimeInterval(1300)))
    }

    @Test func dieLueckeZaehltAlsPause() {
        let sessions = store()
        let id = beendet(sessions)
        let wieder = sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1200 + 1080))  // 18 min spaeter
        #expect(wieder?.id == id)
        #expect(wieder?.startedAt == t0)
        #expect(wieder?.pausenDauer == 1080)
        #expect(sessions.aktiveSession(jetzt: t0.addingTimeInterval(2300))?.id == id)
        #expect(sessions.zuletztBeendet == nil)
    }

    /// Review Focus 1: ein zweiter Aufruf bucht die Luecke nicht doppelt.
    @Test func einZweitesWiederaufnehmenAendertNichts() {
        let sessions = store()
        _ = beendet(sessions)
        _ = sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1500))
        #expect(sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1600)) == nil)
        #expect(sessions.aktiveSession(jetzt: t0.addingTimeInterval(1600))?.pausenDauer == 300)
    }

    /// Review Focus 2: beendet waehrend einer Pause.
    @Test func eineOffenePauseWirdBisZumBeendenAbgeschlossen() {
        let sessions = store()
        sessions.trainingStarten(jetzt: t0)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil,
                                  jetzt: t0.addingTimeInterval(600))
        sessions.pausieren(jetzt: t0.addingTimeInterval(900))
        sessions.beenden(jetzt: t0.addingTimeInterval(1200))                 // 300 s Pause offen
        let wieder = sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1500))  // + 300 s Luecke
        #expect(wieder?.istPausiert == false)
        #expect(wieder?.pausenDauer == 600)
    }

    /// Review Focus 3: ein neues Training sperrt das Fortsetzen.
    @Test func einLaufendesTrainingSperrt() {
        let sessions = store()
        let id = beendet(sessions).uuidString
        sessions.trainingStarten(jetzt: t0.addingTimeInterval(1300))
        #expect(!sessions.kannWiederaufnehmen(sessionId: id, jetzt: t0.addingTimeInterval(1310)))
        #expect(sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1310)) == nil)
    }

    @Test func ortswechselLegtNichtsAb() {
        let sessions = store()
        sessions.trainingStarten(jetzt: t0)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        _ = sessions.beendenFuerOrtswechsel()
        #expect(sessions.zuletztBeendet == nil)
    }

    @Test func abmeldenLoeschtDieAblage() {
        let sessions = store()
        _ = beendet(sessions)
        sessions.reset()
        #expect(sessions.zuletztBeendet == nil)
    }

    @Test func dieAblageUeberstehtEinenNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let id = beendet(store(verzeichnis))
        #expect(store(verzeichnis).zuletztBeendet?.session.id == id)
    }
}
