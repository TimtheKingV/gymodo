import Foundation
import Testing
@testable import FitnessMember

/// Dekodiert die JSON-Form, die GET /me/flows liefert (flows.ts).
struct FlowDTOTests {

    private let json = """
    {"flows":[{"id":"f1","studioId":"s1","key":"hiit-20","titel":"HIIT 20 Minuten",
      "beschreibung":null,"level":"mittel","dauerS":100,
      "schritte":[
        {"position":1,"name":"Burpees","beschreibung":"Volle Kraft","workS":40,"restS":20,"istWarmup":true},
        {"position":2,"name":"Plank","beschreibung":null,"workS":40,"restS":0,"istWarmup":false}]}]}
    """

    private struct Antwort: Decodable { let flows: [Flow] }

    @Test func flowDekodiertFeldFuerFeld() throws {
        let flow = try JSONDecoder().decode(Antwort.self, from: Data(json.utf8)).flows[0]
        #expect(flow.id == "f1")
        #expect(flow.studioId == "s1")
        #expect(flow.key == "hiit-20")
        #expect(flow.titel == "HIIT 20 Minuten")
        #expect(flow.beschreibung == nil)
        #expect(flow.level == "mittel")
        #expect(flow.dauerS == 100)
        #expect(flow.schritte.count == 2)
        #expect(flow.schritte[0] == FlowSchritt(position: 1, name: "Burpees", beschreibung: "Volle Kraft",
                                                workS: 40, restS: 20, istWarmup: true))
        #expect(flow.schritte[1].beschreibung == nil)
    }

    @Test func runEingabeKodiertMitDenFeldnamenDerApi() throws {
        let run = FlowRunEingabe(id: "r1", flowId: "f1", startedAt: "2026-11-26T10:00:00Z",
                                 endedAt: "2026-11-26T10:20:00Z", lastStep: 20, outcome: "finished")
        let data = try JSONEncoder().encode(run)
        let objekt = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(objekt.keys) == ["id", "flowId", "startedAt", "endedAt", "lastStep", "outcome"])
        #expect(try JSONDecoder().decode(FlowRunEingabe.self, from: data) == run)
    }
}
