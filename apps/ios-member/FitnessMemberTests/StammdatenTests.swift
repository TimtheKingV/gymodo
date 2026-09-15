import Testing
@testable import FitnessMember

@Suite("Stammdaten")
struct StammdatenTests {
    @Test("Altersspanne uebersetzt den Serverwert")
    func altersspanneWort() {
        #expect(Altersspanne(rawValue: "25_34")?.wort == "25–34")
    }

    @Test("Altersspanne kennt alle sieben Serverwerte")
    func altersspanneAlle() {
        #expect(Altersspanne.alle.count == 7)
    }

    @Test("Geschlecht kennt alle drei Serverwerte")
    func geschlechtAlle() {
        #expect(Geschlecht.alle.count == 3)
    }

    @Test("Trainingsrichtung uebersetzt den Serverwert")
    func trainingsrichtungWort() {
        #expect(Trainingsrichtung(rawValue: "lose_weight")?.wort == "Abnehmen")
    }

    @Test("ein unbekannter Serverwert ergibt nil statt eines Absturzes")
    func unbekannterServerwertErgibtNil() {
        #expect(Altersspanne(rawValue: "unbekannt") == nil)
        #expect(Geschlecht(rawValue: "unbekannt") == nil)
        #expect(Trainingsrichtung(rawValue: "unbekannt") == nil)
    }
}
