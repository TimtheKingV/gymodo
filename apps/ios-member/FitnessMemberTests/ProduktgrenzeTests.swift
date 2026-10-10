import Testing
@testable import FitnessMember

/// Der Satz steht wortgleich in designsystem.md SS10, auf der Landeseite
/// und auf /t/[token]. Laeuft er hier auseinander, sagt die App etwas
/// anderes als das Web -- genau das, was Befund 19 verhindern sollte.
struct ProduktgrenzeTests {
    @Test func derKanonischeSatzStimmtMitDemDesignsystemUeberein() {
        #expect(Produktgrenze.kanonisch == "Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.")
    }

    @Test func derSatzBehauptetNichtMehrDassNichtsGemessenWird() {
        #expect(!Produktgrenze.kanonisch.contains("misst nichts"))
    }
}
