import Foundation
import Testing
@testable import FitnessMember

/// Der Einstieg einer laufenden Session ueberlebt einen Neustart (Review Focus 5).
struct TrainingEinstiegSpeicherTests {
    private func speicher() -> TrainingEinstiegSpeicher {
        TrainingEinstiegSpeicher(defaults: UserDefaults(suiteName: "einstieg-tests-\(UUID().uuidString)")!)
    }

    @Test func einstiegKommtFuerDieselbeSessionZurueck() {
        let sut = speicher()
        let id = UUID()
        sut.speichern(.frei, sessionId: id)
        #expect(sut.laden(sessionId: id) == .frei)
        sut.speichern(.plan, sessionId: id)
        #expect(sut.laden(sessionId: id) == .plan)
    }

    @Test func eineAndereSessionBekommtNichts() {
        let sut = speicher()
        sut.speichern(.frei, sessionId: UUID())
        #expect(sut.laden(sessionId: UUID()) == nil)
    }

    @Test func eineNeueSessionUeberschreibtDenAltenEintrag() {
        // Am Ende wird nicht geloescht: ein alter Eintrag ist harmlos.
        let sut = speicher()
        let alt = UUID(), neu = UUID()
        sut.speichern(.frei, sessionId: alt)
        sut.speichern(.plan, sessionId: neu)
        #expect(sut.laden(sessionId: neu) == .plan)
        #expect(sut.laden(sessionId: alt) == nil)
    }
}
