import Foundation
import Testing
import Sensorik
@testable import FitnessMember

struct SetWriteHerkunftTests {
    private func satz() -> SetWrite {
        SetWrite(machineId: "m", exerciseId: "e", setIndex: 1, load: 20, volume: 10)
    }

    @Test func ohneZaehlerIstEsEingegeben() {
        #expect(satz().volumeSource == .eingegeben)
        #expect(satz().volumeCounted == nil)
        #expect(satz().repEvents == nil)
    }

    @Test func gemessenUeberlebtDieWarteschlange() throws {
        var s = satz()
        s.volumeSource = .gemessen
        s.volumeCounted = 10
        s.repEvents = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel, ereignisse: [], satzbeginn: 0)
        let zurueck = try JSONDecoder().decode(SetWrite.self, from: JSONEncoder().encode(s))
        #expect(zurueck == s)
    }

    /// Ein Eintrag, den ein aelterer Build offline in den PendingWriteStore
    /// geschrieben hat, kennt die neuen Schluessel nicht. Er muss nach dem
    /// Update dekodieren, sonst ist genau dieser Satz verloren.
    @Test func einAlterWarteschlangenEintragDekodiertAlsEingegeben() throws {
        let alt = #"{"machineId":"m","exerciseId":"e","setIndex":1,"load":20,"volume":10,"problemFlag":false}"#
        let s = try JSONDecoder().decode(SetWrite.self, from: Data(alt.utf8))
        #expect(s.volumeSource == .eingegeben)
        #expect(s.volumeCounted == nil)
        #expect(s.repEvents == nil)
    }

    @Test func eingegebenSchicktKeineZaehlerfelder() throws {
        let json = try #require(String(data: JSONEncoder().encode(satz()), encoding: .utf8))
        #expect(json.contains(#""volumeSource":"eingegeben""#))
        #expect(!json.contains("volumeCounted"))
        #expect(!json.contains("repEvents"))
    }

    @Test func dieAntwortDesServersDekodiertMitHerkunft() throws {
        let antwort = #"{"id":"s","studioId":"st","userId":"u","sessionId":"se","machineId":"m","exerciseId":"e","setIndex":1,"load":20,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-10-10T10:00:00Z","volumeSource":"gemessen","volumeCounted":10}"#
        let r = try JSONDecoder().decode(RecordedSet.self, from: Data(antwort.utf8))
        #expect(r.volumeSource == .gemessen)
        #expect(r.volumeCounted == 10)
    }

    /// Waehrend eines gestaffelten Deploys antwortet der Server noch ohne
    /// Herkunft; das darf den Satz nicht unlesbar machen.
    @Test func eineAntwortOhneHerkunftGiltAlsEingegeben() throws {
        let antwort = #"{"id":"s","studioId":"st","userId":"u","sessionId":"se","machineId":"m","exerciseId":"e","setIndex":1,"load":20,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-10-10T10:00:00Z"}"#
        let r = try JSONDecoder().decode(RecordedSet.self, from: Data(antwort.utf8))
        #expect(r.volumeSource == .eingegeben)
        #expect(r.volumeCounted == nil)
    }
}
