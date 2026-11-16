import Foundation
import Testing
@testable import FitnessMember

struct UebungskarteModellTests {
    private func kraft(
        saetze: Int = 3, von: Int? = 8, bis: Int? = 12, pause: Int = 150, key: String? = "k1",
        exerciseId: String = "e1", ersetzt: String? = nil, werteOffen: Bool = false
    ) -> EntwurfsPosition {
        EntwurfsPosition(
            id: UUID(), key: key, exerciseId: exerciseId, modelId: "m1", art: .kraft(typ: "mehrgelenk"),
            saetze: saetze, wdhVon: von, wdhBis: bis, pauseSek: pause, dauerMin: nil, aufwaermsatz: true,
            ersetzt: ersetzt, werteOffen: werteOffen)
    }

    private func modell(_ p: EntwurfsPosition, ausgang: String? = nil, geaendert: Set<WertFeld> = []) -> UebungskarteModell {
        UebungskarteModell.aus(p, name: "Brustpresse", bild: nil, geaendert: geaendert, ausgangExerciseId: ausgang)
    }

    @Test func chipsKraft() {
        #expect(modell(kraft()).chips.map(\.text) == ["3 Sätze", "8–12 Wdh", "150 s"])
    }

    @Test func chipsGleicheWdh() {
        #expect(modell(kraft(von: 10, bis: 10)).chips.map(\.text)[1] == "10 Wdh")
    }

    @Test func chipsCardio() {
        let p = EntwurfsPosition(
            id: UUID(), key: "c", exerciseId: "bike", modelId: "m", art: .cardio, saetze: 1, wdhVon: nil,
            wdhBis: nil, pauseSek: 0, dauerMin: 20, aufwaermsatz: false)
        #expect(modell(p).chips.map(\.text) == ["20 min"])
    }

    @Test func markierungGetauscht() {
        let m = UebungskarteModell.aus(
            kraft(exerciseId: "e2", ersetzt: "Reverse Butterfly"), name: "X", bild: nil, geaendert: [],
            ausgangExerciseId: "e1")
        #expect(m.markierung == "statt Reverse Butterfly")
    }

    @Test func keineMarkierungBeiRueckTausch() {
        let m = modell(kraft(exerciseId: "e1", ersetzt: "B"), ausgang: "e1")
        #expect(m.markierung == nil)
    }

    @Test func markierungNeu() {
        #expect(modell(kraft(key: nil)).markierung == "neu")
    }

    @Test func geaenderteFelderHervorgehoben() {
        let m = modell(kraft(), geaendert: [.saetze, .pause])
        #expect(m.chips.map(\.hervorgehoben) == [true, false, true])
    }

    @Test func werteOffenZeigtStandard() {
        let m = modell(kraft(werteOffen: true), geaendert: [.saetze])
        #expect(m.chips.map(\.text) == ["Standard"])
        #expect(m.chips.allSatisfy { !$0.hervorgehoben })
    }

    @Test func beschreibungFuerVoiceOver() {
        #expect(modell(kraft()).beschreibung == "Brustpresse, 3 Sätze, 8 bis 12 Wiederholungen, 150 Sekunden Pause")
    }
}
