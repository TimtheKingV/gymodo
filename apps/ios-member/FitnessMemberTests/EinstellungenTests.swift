import Foundation
import Testing
@testable import FitnessMember

struct EinstellungenTests {
    /// Der Schluessel stammt aus Sub-Projekt 2 und steht heute in
    /// GeraetView. Aendert er sich, verlieren Bestandsinstallationen ihre
    /// Einstellung -- deshalb woertlich festgehalten.
    @Test func derRIRSchluesselBleibtWoertlich() {
        #expect(Einstellungen.rirSichtbarKey == "rirSichtbar")
    }

    @Test func ohneGesetztenWertGiltDieVorgabe() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        #expect(Einstellungen.resttimerSekunden(defaults) == 90)
        #expect(Einstellungen.vibriertBeimSichern(defaults) == true)
    }

    @Test func eingesetzterWertSchlaegtDieVorgabe() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(120, forKey: Einstellungen.resttimerSekundenKey)
        defaults.set(false, forKey: Einstellungen.vibrationBeimSichernKey)

        #expect(Einstellungen.resttimerSekunden(defaults) == 120)
        #expect(Einstellungen.vibriertBeimSichern(defaults) == false)
    }

    @Test func dieVorgabeStehtUnterDenStufen() {
        #expect(Einstellungen.resttimerStufen.contains(Einstellungen.resttimerVorgabe))
    }
}
