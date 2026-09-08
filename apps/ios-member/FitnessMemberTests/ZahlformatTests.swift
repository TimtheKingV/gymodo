import Testing
@testable import FitnessMember

struct ZahlformatTests {
    @Test func gewichtHatImmerGenauEineNachkommastelle() {
        #expect(Zahlformat.gewicht(80) == "80,0")
        #expect(Zahlformat.gewicht(82.5) == "82,5")
        #expect(Zahlformat.gewicht(5) == "5,0")
    }

    @Test func gewichtNutztDezimalkommaUnabhaengigVonDerSystemsprache() {
        // Ein Punkt hier waere ein Formatfehler, kein Gebietsschema-Detail:
        // designsystem.md SS3 legt Dezimalkomma fest.
        #expect(!Zahlformat.gewicht(82.5).contains("."))
    }

    @Test func gewichtMitEinheitHaengtKilogrammAn() {
        #expect(Zahlformat.gewichtMitEinheit(80) == "80,0 kg")
    }

    @Test func gesprocheneAnsageIstEineZeichenkette() {
        // designsystem.md SS12: sonst liest VoiceOver "achtzig, Komma, null,
        // k, g" als vier Elemente.
        #expect(Zahlformat.gewichtGesprochen(80) == "80,0 Kilogramm")
        #expect(Zahlformat.wiederholungenGesprochen(1) == "1 Wiederholung")
        #expect(Zahlformat.wiederholungenGesprochen(10) == "10 Wiederholungen")
    }
}
