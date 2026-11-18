import Foundation
import Testing
@testable import FitnessMember

struct PlanEinheitBearbeitungTests {
    private func position(_ key: String) -> TrainingsplanPosition {
        TrainingsplanPosition(
            key: key, baustein: "mehrgelenk", rolle: "haupt", exerciseId: "e\(key)",
            modelId: "m\(key)", typ: "mehrgelenk", saetze: 3, wdhVon: 8, wdhBis: 12,
            reserveVon: 1, reserveBis: 2, pauseSek: 90, aufwaermsatz: false, dauerMin: nil,
            hauptmuskeln: [])
    }

    private func einheit(_ keys: [String]) -> TrainingsplanEinheit {
        TrainingsplanEinheit(key: "A", positionen: keys.map(position), geschaetzteMinuten: 45)
    }

    @Test func verschiebenAendertReihenfolge() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2"]))
        #expect(!b.geaendert)
        b.verschieben(von: [2], nach: 0)
        #expect(b.keys == ["2", "0", "1"])
        #expect(b.geaendert)
    }

    @Test func zurueckVerschobenIstUnveraendert() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2"]))
        b.verschieben(von: [2], nach: 0)
        b.verschieben(von: [0], nach: 3)
        #expect(b.keys == ["0", "1", "2"])
        #expect(!b.geaendert)
    }

    @Test func mehrfachVerschiebenWieArrayMove() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2", "3"]))
        b.verschieben(von: [0, 2], nach: 4)
        var referenz = ["0", "1", "2", "3"]
        referenz.move(fromOffsets: [0, 2], toOffset: 4)
        #expect(b.keys == ["1", "3", "0", "2"])
        #expect(b.keys == referenz)
    }

    @Test func verschiebenIgnoriertUngueltigeOffsets() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1"]))
        b.verschieben(von: [5], nach: 0)
        #expect(b.keys == ["0", "1"])
    }

    @Test func entfernenLetzteBleibtVerweigert() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0"]))
        #expect(!b.darfEntfernen)
        let ok = b.entfernen([0])
        #expect(ok == false)
        #expect(b.keys == ["0"])
    }

    @Test func entfernenNimmtRaus() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2"]))
        let ok = b.entfernen([1])
        #expect(ok)
        #expect(b.keys == ["0", "2"])
        #expect(b.darfEntfernen)
        #expect(b.geaendert)
    }

    @Test func positionenFolgenDerReihenfolge() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2"]))
        b.verschieben(von: [2], nach: 0)
        #expect(b.positionen(in: einheit(["0", "1"])).map(\.key) == ["0", "1"])
        #expect(b.positionen(in: einheit(["0", "1", "2"])).map(\.key) == ["2", "0", "1"])
    }

    @Test func uebernehmenNachTausch() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2"]))
        b.verschieben(von: [2], nach: 0)
        var c = b
        b.uebernehmen(neueEinheit: einheit(["0", "1", "2"]))
        #expect(b.keys == ["2", "0", "1"])
        c.uebernehmen(neueEinheit: einheit(["0", "2"]))
        #expect(c.keys == ["2", "0"])
        c.uebernehmen(neueEinheit: einheit(["0", "2", "9"]))
        #expect(c.keys == ["2", "0", "9"])
    }

    /// Der Server führt eine entfernte Position bis "Fertig" noch; ein Tausch
    /// dazwischen darf sie nicht zurückholen.
    @Test func uebernehmenHoltEntfernteNichtZurueck() {
        var b = PlanEinheitBearbeitung(einheit: einheit(["0", "1", "2"]))
        b.entfernen([1])
        b.uebernehmen(neueEinheit: einheit(["0", "1", "2"]))
        #expect(b.keys == ["0", "2"])
        #expect(b.geaendert)
    }

    @Test func darfBearbeitenNichtWaehrendDieseEinheitLaeuft() {
        #expect(!PlanEinheitBearbeitung.darfBearbeiten(einheitKey: "A", laufEinheitKey: "A", gebunden: true))
        #expect(PlanEinheitBearbeitung.darfBearbeiten(einheitKey: "A", laufEinheitKey: "A", gebunden: false))
        #expect(PlanEinheitBearbeitung.darfBearbeiten(einheitKey: "B", laufEinheitKey: "A", gebunden: true))
    }

    /// Final-Review 3: nach einem Tausch verspricht der linke Knopf kein Rueckgaengig.
    @Test func nachEinemTauschHeisstAbbrechenSchliessen() {
        #expect(PlanEinheitBearbeitung.schliessenTitel(hatGetauscht: false) == "Abbrechen")
        #expect(PlanEinheitBearbeitung.schliessenTitel(hatGetauscht: true) == "Schließen")
        #expect(PlanEinheitBearbeitung.verwerfenHinweis(hatGetauscht: false) == nil)
        #expect(PlanEinheitBearbeitung.verwerfenHinweis(hatGetauscht: true) == "Ersetzte Übungen bleiben ersetzt.")
    }
}
