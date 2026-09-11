import Foundation
import Testing
@testable import FitnessMember

struct EinstellungenTests {
    /// Die Schluessel stammen aus Sub-Projekt 2. Aendert sich einer,
    /// verlieren Bestandsinstallationen ihre Einstellung -- deshalb
    /// woertlich festgehalten.
    @Test func dieSchluesselBleibenWoertlich() {
        #expect(Einstellungen.resttimerSekundenKey == "resttimerSekunden")
        #expect(Einstellungen.vibrationBeimSichernKey == "vibrationBeimSichern")
    }

    @Test func ohneGesetztenWertGiltDieVorgabe() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        #expect(Einstellungen.resttimerSekunden(defaults) == 90)
        #expect(Einstellungen.satzZiel(defaults) == 3)
        #expect(Einstellungen.vibriertBeimSichern(defaults) == true)
    }

    @Test func eingesetzterWertSchlaegtDieVorgabe() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(120, forKey: Einstellungen.resttimerSekundenKey)
        defaults.set(5, forKey: Einstellungen.satzZielKey)
        defaults.set(false, forKey: Einstellungen.vibrationBeimSichernKey)

        #expect(Einstellungen.resttimerSekunden(defaults) == 120)
        #expect(Einstellungen.satzZiel(defaults) == 5)
        #expect(Einstellungen.vibriertBeimSichern(defaults) == false)
    }

    @Test func dieVorgabeStehtUnterDenStufen() {
        #expect(Einstellungen.resttimerStufen.contains(Einstellungen.resttimerVorgabe))
        #expect(Einstellungen.satzZielStufen.contains(Einstellungen.satzZielVorgabe))
    }
}
