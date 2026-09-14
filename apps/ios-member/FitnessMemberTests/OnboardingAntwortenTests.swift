import Foundation
import Testing
@testable import FitnessMember

@Suite("OnboardingAntworten")
struct OnboardingAntwortenTests {
    @Test("ohne Gewicht fehlt der Zielgewicht-Schritt")
    func schritteOhneGewicht() {
        var antworten = OnboardingAntworten()
        antworten.gewichtKg = nil
        #expect(antworten.schritte == [.ueberDich, .koerper, .ziel, .wieOft])
    }

    @Test("mit Gewicht kommen alle fuenf Schritte, Zielgewicht zuletzt")
    func schritteMitGewicht() {
        var antworten = OnboardingAntworten()
        antworten.gewichtKg = 70.0
        #expect(antworten.schritte == [.ueberDich, .koerper, .ziel, .wieOft, .zielgewicht])
    }

    @Test("Spaeter auf Schritt 2 laesst Schritt 1 stehen -- Antworten sind ein Wertetyp, Spaeter ist kein Reset")
    func spaeterBehaeltVorherigeAntworten() {
        var antworten = OnboardingAntworten()
        antworten.geschlecht = .weiblich
        antworten.altersspanne = .bis34

        // "Spaeter" auf Schritt 2 (Koerper) heisst nur: dessen Felder
        // bleiben nil. Es gibt keinen Reset-Aufruf, der Wert wird einfach
        // unveraendert weitergereicht -- genau das prueft dieser Test.
        let nachSpaeterAufSchritt2 = antworten
        #expect(nachSpaeterAufSchritt2.geschlecht == .weiblich)
        #expect(nachSpaeterAufSchritt2.altersspanne == .bis34)
        #expect(nachSpaeterAufSchritt2.groesseCm == nil)
        #expect(nachSpaeterAufSchritt2.gewichtKg == nil)
    }

    @Test("istLeer ist wahr, wenn nichts gesetzt ist")
    func istLeerWennNichtsGesetzt() {
        #expect(OnboardingAntworten().istLeer)
    }

    // R16: eine unveraenderte Vorgabe ist keine Antwort, aber eine bewusst
    // bestaetigte schon -- sonst schriebe "fuenfmal Spaeter" ein
    // Wochenziel, das niemand gewaehlt hat.
    @Test("eine bewusst gesetzte Vorgabe ist eine Antwort, keine unveraenderte Vorgabe")
    func tageProWocheGesetztIstKeineLeereAntwort() {
        var antworten = OnboardingAntworten()
        antworten.tageProWoche = OnboardingAntworten.tageVorgabe
        #expect(!antworten.istLeer)
    }
}
