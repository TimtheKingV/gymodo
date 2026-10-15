import Foundation
import Testing
@testable import FitnessMember

struct FortsetzbarkeitTests {
    private func teil(_ id: String, start: String) -> SessionSummary {
        SessionSummary(id: id, startedAt: start, completedAt: nil, completedReason: "manual",
                       machineCount: 0, setCount: 0, blocks: [])
    }

    /// Review Focus 5: eine zusammengelegte Karte setzt ihren JUENGSTEN Teil fort.
    @Test func nurDerJuengsteTeilZaehlt() {
        let karte = Trainingskarte(teile: [teil("alt", start: "2026-10-14T17:00:00Z"),
                                           teil("neu", start: "2026-10-14T17:47:00Z")])
        #expect(Fortsetzbarkeit.fortsetzbarerTeil(karte) { $0 == "neu" } == "neu")
        #expect(Fortsetzbarkeit.fortsetzbarerTeil(karte) { $0 == "alt" } == nil)
    }

    @Test func ohneErlaubnisKeinButton() {
        let karte = Trainingskarte(teile: [teil("s1", start: "2026-10-14T17:47:00Z")])
        #expect(Fortsetzbarkeit.fortsetzbarerTeil(karte) { _ in false } == nil)
    }

    /// Review Focus 4: bei jedem conflict verschwindet der Button, die
    /// Meldung kommt vom Server.
    @Test func conflictVerwirftDieAblage() {
        let folge = Fortsetzbarkeit.folgeNachFehler(.conflict(message: "Zu spät zum Fortsetzen."))
        #expect(folge.text == "Zu spät zum Fortsetzen.")
        #expect(folge.ablageVerwerfen)
    }

    @Test func ohneNetzBleibtDieAblage() {
        let folge = Fortsetzbarkeit.folgeNachFehler(.offline)
        #expect(folge.text == "Ohne Verbindung geht Fortsetzen nicht.")
        #expect(!folge.ablageVerwerfen)
    }
}
