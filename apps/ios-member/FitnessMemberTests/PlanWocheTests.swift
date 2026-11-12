import Foundation
import Testing
@testable import FitnessMember

/// Filter des Plan-Tabs und das Dekodieren der aelteren Plan-/Profilantworten.
struct PlanWocheTests {
    @Test func filterTitel() {
        #expect(PlanFilter.allCases.map(\.titel) == ["Alle", "Kraft", "Kurse", "Cardio"])
    }

    @Test func sichtbareFilter() {
        #expect(PlanWoche.sichtbareFilter(hatPlan: false, hatKurse: true, hatCardio: false) == [.alle, .kurse])
        #expect(PlanWoche.sichtbareFilter(hatPlan: false, hatKurse: false, hatCardio: false) == [])
        #expect(PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: false, hatCardio: false) == [])
        #expect(PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: true, hatCardio: true)
                == [.alle, .kraft, .kurse, .cardio])
    }

    @Test func rasterUndProfilDekodierenAeltereAntworten() throws {
        let json = #"[{"tag":1,"art":"kurs"},{"tag":3,"art":"kraft","einheitKey":"A"}]"#
        let r = try JSONDecoder().decode([Rasterplatz].self, from: Data(json.utf8))
        #expect(r == [Rasterplatz(tag: 1, art: .kurs, einheitKey: nil), Rasterplatz(tag: 3, art: .kraft, einheitKey: "A")])
        let alt = try JSONDecoder().decode(
            TrainingsplanProfil.self, from: Data(#"{"minutes":60,"experience":"neu","focus":[]}"#.utf8))
        #expect(alt.kursTage == nil && alt.cardioArten == nil)
        let neu = try JSONDecoder().decode(
            TrainingsplanProfil.self,
            from: Data(#"{"minutes":60,"experience":"neu","focus":[],"kursTage":[1],"cardioTage":[7],"cardioArten":["laufen"],"kraftTage":[3]}"#.utf8))
        #expect(neu.kursTage == [1] && neu.cardioTage == [7] && neu.cardioArten == ["laufen"] && neu.kraftTage == [3])
        let raus = String(decoding: try JSONEncoder().encode(alt), as: UTF8.self)
        #expect(!raus.contains("kursTage"))
    }
}
