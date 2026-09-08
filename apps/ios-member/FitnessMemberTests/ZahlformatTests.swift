import Foundation
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

    @Test func uhrzeitFormatiertStundeUndMinuteZweistellig() {
        // uhrzeit() setzt bewusst keine Zeitzone -- die Einheit lief auf
        // diesem Geraet, in dessen lokaler Zeit. Der Test rechnet deshalb
        // ueber die Geraete-Zeitzone (.current), nicht ueber eine fest
        // verdrahtete, sonst waere er selbst zeitzonenabhaengig brüchig.
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = .current
        var komponenten = DateComponents()
        komponenten.year = 2026; komponenten.month = 9; komponenten.day = 8
        komponenten.hour = 18; komponenten.minute = 4
        let zeitpunkt = kalender.date(from: komponenten)!
        #expect(Zahlformat.uhrzeit(zeitpunkt) == "18:04")
    }
}
