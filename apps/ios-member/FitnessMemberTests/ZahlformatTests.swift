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

    @Test func verstrichenZeigtMinutenUndSekundenUnterEinerStunde() {
        let start = Date(timeIntervalSince1970: 0)
        #expect(Zahlformat.verstrichen(seit: start, bis: start.addingTimeInterval(23 * 60 + 41)) == "23:41")
        #expect(Zahlformat.verstrichen(seit: start, bis: start) == "00:00")
    }

    @Test func verstrichenSchaltetAbEinerStundeAufStundenUm() {
        // m2: "80:14" liest sich nicht mehr eindeutig als Minuten:Sekunden --
        // ab einer Stunde muss die Lesart auf "1:20:14" kippen.
        let start = Date(timeIntervalSince1970: 0)
        #expect(Zahlformat.verstrichen(seit: start, bis: start.addingTimeInterval(80 * 60 + 14)) == "1:20:14")
        // Die Stundengrenze selbst, auf die Sekunde genau: 3599 s ist noch
        // "MM:SS", 3600 s kippt bereits um -- ohne diese beiden Behauptungen
        // koennte der Testname die Grenze versprechen, ohne sie zu pruefen.
        #expect(Zahlformat.verstrichen(seit: start, bis: start.addingTimeInterval(3599)) == "59:59")
        #expect(Zahlformat.verstrichen(seit: start, bis: start.addingTimeInterval(3600)) == "1:00:00")
        // Der Grenzfall: eine Einheit darf bis zu vier Stunden laufen
        // (WorkoutSessionStore.sessionPause).
        #expect(Zahlformat.verstrichen(seit: start, bis: start.addingTimeInterval(4 * 3600 - 1)) == "3:59:59")
    }

    @Test func verstrichenGesprochenNenntMinutenOderStundenUndMinuten() {
        // designsystem.md SS12: "23:41" liest VoiceOver sonst als Uhrzeit.
        let start = Date(timeIntervalSince1970: 0)
        #expect(Zahlformat.verstrichenGesprochen(seit: start, bis: start.addingTimeInterval(60)) == "1 Minute trainiert")
        #expect(Zahlformat.verstrichenGesprochen(seit: start, bis: start.addingTimeInterval(23 * 60)) == "23 Minuten trainiert")
        #expect(Zahlformat.verstrichenGesprochen(seit: start, bis: start.addingTimeInterval(3600 + 60)) == "1 Stunde 1 Minute trainiert")
        #expect(Zahlformat.verstrichenGesprochen(seit: start, bis: start.addingTimeInterval(80 * 60)) == "1 Stunde 20 Minuten trainiert")
    }
}
