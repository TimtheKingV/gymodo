import Foundation
import Testing
@testable import FitnessMember

/// Auswahl-Modell des Training-Tabs (E8, E9).
struct TrainingAuswahlTests {
    private var kalender: Calendar { PlanKalenderKontext.kalender(zeitzone: "Europe/Berlin") }

    /// November 2026: 9 = Montag.
    private func tag(_ t: Int) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: 11, day: t))!
    }

    private func modell(_ termine: [Date: [PlanTermin]], next: String? = nil) -> TrainingAuswahlModell {
        TrainingAuswahl.modell(termine: termine, heute: tag(9), naechsteEinheitKey: next, kalender: kalender)
    }

    @Test func heuteGeplantUndRestDerWoche() {
        let beginn = tag(14).addingTimeInterval(18 * 3600)
        let m = modell([
            tag(9): [.einheit(key: "A", zustand: .geplant)],
            tag(11): [.einheit(key: "B", zustand: .geplant)],
            tag(13): [.cardio(arten: ["Laufen"], zustand: .geplant)],
            tag(14): [.kurs(titel: "Yoga", beginn: beginn, angemeldet: true, zustand: .geplant),
                      .kurs(titel: "Spin", beginn: beginn, angemeldet: false, zustand: .geplant)],
        ], next: "A")
        #expect(m.heuteEinheitKey == "A")
        #expect(m.weitere == [
            .einheit(key: "B", tag: tag(11)),
            .cardio(tag: tag(13)),
            .kurs(titel: "Yoga", beginn: beginn, tag: tag(14)),
        ])
    }

    @Test func ohneKraftHeuteKeinHeute() {
        let m = modell([
            tag(9): [.cardio(arten: ["Laufen"], zustand: .geplant)],
            tag(11): [.einheit(key: "B", zustand: .geplant)],
        ])
        #expect(m.heuteEinheitKey == nil)
        #expect(m.weitere.first == .cardio(tag: tag(9)))
    }

    @Test func naechsteEinheitStehtOhneHeutigenKraftterminZuerst() {
        let m = modell([
            tag(9): [.cardio(arten: ["Laufen"], zustand: .geplant)],
            tag(11): [.einheit(key: "B", zustand: .geplant)],
        ], next: "B")
        #expect(m.heuteEinheitKey == nil)
        #expect(m.weitere == [.einheit(key: "B", tag: tag(11)), .cardio(tag: tag(9))])
    }

    @Test func erledigtesUndVerpasstesFehlt() {
        let m = modell([
            tag(9): [.einheit(key: "A", zustand: .erledigt)],
            tag(10): [.einheit(key: "B", zustand: .verpasst(verschobenAuf: tag(11))),
                      .cardio(arten: [], zustand: .erledigt)],
        ])
        #expect(m.heuteEinheitKey == nil)
        #expect(m.weitere.isEmpty)
    }

    @Test func naechsteWocheFehlt() {
        let m = modell([tag(16): [.einheit(key: "B", zustand: .geplant)]])
        #expect(m.weitere.isEmpty)
    }

    @Test func einheitNurEinmal() {
        let m = modell([
            tag(11): [.einheit(key: "B", zustand: .geplant)],
            tag(13): [.einheit(key: "B", zustand: .geplant)],
        ])
        #expect(m.weitere == [.einheit(key: "B", tag: tag(11))])
    }

    @Test func heutigeEinheitNichtInWeitere() {
        let m = modell([
            tag(9): [.einheit(key: "A", zustand: .geplant)],
            tag(11): [.einheit(key: "A", zustand: .geplant)],
        ], next: "A")
        #expect(m.weitere.isEmpty)
    }

    @Test func sonntagIstLetzterTag() {
        let m = modell([tag(15): [.cardio(arten: [], zustand: .geplant)]])
        #expect(m.weitere == [.cardio(tag: tag(15))])
    }

    @Test func idsSindStabil() {
        #expect(TrainingAuswahlOption.einheit(key: "B", tag: tag(11)).id == "einheit-B")
        #expect(TrainingAuswahlOption.cardio(tag: tag(13)).id == "cardio-2026-11-13")
    }

    @Test func danachIstNachfolger() {
        #expect(TrainingAuswahl.danach(einheitKey: "B", einheitKeys: ["A", "B"]) == "A")
        #expect(TrainingAuswahl.danach(einheitKey: "B", einheitKeys: ["A", "B", "C"]) == "C")
    }
}
