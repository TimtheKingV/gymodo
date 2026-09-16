import Testing
@testable import FitnessMember

/// Ob "Verwerfen" den Server braucht -- oder die Warteschlange reicht.
struct EinheitVerwerfenTests {
    @Test func liegenAlleSaetzeNochInDerWarteschlangeReichtDieWarteschlange() {
        // Der Server legt die Einheit erst mit dem ersten Satz an: hat ihn
        // keiner erreicht, gibt es dort nichts zu loeschen -- und das geht
        // auch im Keller.
        #expect(EinheitVerwerfen.weg(offeneSchreibvorgaenge: 3, satzAnzahl: 3) == .nurLokal)
    }

    @Test func einGesendeterSatzVerlangtDenServer() {
        #expect(EinheitVerwerfen.weg(offeneSchreibvorgaenge: 2, satzAnzahl: 3) == .ueberDenServer)
        #expect(EinheitVerwerfen.weg(offeneSchreibvorgaenge: 0, satzAnzahl: 3) == .ueberDenServer)
    }
}
