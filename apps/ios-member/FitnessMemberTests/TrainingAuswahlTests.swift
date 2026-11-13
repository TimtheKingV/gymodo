import Foundation
import Testing
@testable import FitnessMember

/// Auswahl-Modell des Training-Tabs (E8, E9) auf der Woche ohne feste Tage
/// (Spec P2): naechste Einheit, die uebrigen der Reihe, offenes Cardio.
struct TrainingAuswahlTests {
    private func ziel(kraft: Int = 2, cardio: Int = 0, minuten: Int = 30) -> Wochenziel {
        Wochenziel(kraft: kraft, cardio: cardio, cardioMinuten: minuten)
    }

    @Test func naechsteVornUndRestInFolge() {
        let m = TrainingAuswahl.modell(
            einheiten: ["A", "B", "C"], naechsteEinheitKey: "B", ziel: ziel(), cardioErledigt: 0)
        #expect(m.naechsteEinheitKey == "B")
        // Wie die offenen Kraft-Karten: (i + k) mod n.
        #expect(m.weitere == [.einheit(key: "C"), .einheit(key: "A")])
    }

    @Test func ohneNaechstenKeyDieErste() {
        let m = TrainingAuswahl.modell(
            einheiten: ["A", "B"], naechsteEinheitKey: nil, ziel: ziel(), cardioErledigt: 0)
        #expect(m.naechsteEinheitKey == "A")
        #expect(m.weitere == [.einheit(key: "B")])
    }

    @Test func unbekannterKeyFaelltAufDieErste() {
        let m = TrainingAuswahl.modell(
            einheiten: ["A", "B"], naechsteEinheitKey: "X", ziel: ziel(), cardioErledigt: 0)
        #expect(m.naechsteEinheitKey == "A")
    }

    @Test func eineEinheitHatKeineWeiteren() {
        let m = TrainingAuswahl.modell(
            einheiten: ["A"], naechsteEinheitKey: "A", ziel: ziel(), cardioErledigt: 0)
        #expect(m.naechsteEinheitKey == "A")
        #expect(m.weitere.isEmpty)
    }

    @Test func cardioNurMitOffenemZiel() {
        let offen = TrainingAuswahl.modell(
            einheiten: ["A", "B"], naechsteEinheitKey: "A", ziel: ziel(cardio: 2, minuten: 30), cardioErledigt: 1)
        #expect(offen.weitere == [.einheit(key: "B"), .cardio(minuten: 30)])
        let erfuellt = TrainingAuswahl.modell(
            einheiten: ["A", "B"], naechsteEinheitKey: "A", ziel: ziel(cardio: 1), cardioErledigt: 1)
        #expect(erfuellt.weitere == [.einheit(key: "B")])
        let ohneZiel = TrainingAuswahl.modell(
            einheiten: ["A", "B"], naechsteEinheitKey: "A", ziel: ziel(cardio: 0), cardioErledigt: 0)
        #expect(ohneZiel.weitere == [.einheit(key: "B")])
    }

    @Test func ohneEinheitenNurCardio() {
        let m = TrainingAuswahl.modell(
            einheiten: [], naechsteEinheitKey: nil, ziel: ziel(cardio: 1, minuten: 45), cardioErledigt: 0)
        #expect(m.naechsteEinheitKey == nil)
        #expect(m.weitere == [.cardio(minuten: 45)])
    }

    @Test func idsSindStabil() {
        #expect(TrainingAuswahlOption.einheit(key: "B").id == "einheit-B")
        #expect(TrainingAuswahlOption.cardio(minuten: 30).id == "cardio")
    }

    @Test func danachIstNachfolger() {
        #expect(TrainingAuswahl.danach(einheitKey: "B", einheitKeys: ["A", "B"]) == "A")
        #expect(TrainingAuswahl.danach(einheitKey: "B", einheitKeys: ["A", "B", "C"]) == "C")
    }
}
