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

    // MARK: - Block "Dein Trainingsplan" (Etappe 3)

    @Test("schritte komplett ohne Studio enthaelt 3 Plan-Schritte und keine Vorschau")
    func schritteKomplettOhneStudio() {
        var antworten = OnboardingAntworten()
        antworten.gewichtKg = 70.0
        #expect(antworten.schritte(umfang: .komplett, hatStudio: false) == [
            .ueberDich, .koerper, .ziel, .wieOft, .zielgewicht, .planZeit, .planSchwerpunkt, .planBeschwerden,
        ])
    }

    @Test("schritte komplett mit Studio endet mit der Vorschau")
    func schritteKomplettMitStudio() {
        let antworten = OnboardingAntworten()
        #expect(antworten.schritte(umfang: .komplett, hatStudio: true) == [
            .ueberDich, .koerper, .ziel, .wieOft, .planZeit, .planSchwerpunkt, .planBeschwerden, .planVorschau,
        ])
    }

    @Test("schritte nurPlan hat vier")
    func schritteNurPlanHatVier() {
        let antworten = OnboardingAntworten()
        #expect(antworten.schritte(umfang: .nurPlan, hatStudio: true) == [
            .planZeit, .planSchwerpunkt, .planBeschwerden, .planVorschau,
        ])
    }

    @Test("schritte nurVorschau ist nur die Vorschau")
    func schritteNurVorschau() {
        #expect(OnboardingAntworten().schritte(umfang: .nurVorschau, hatStudio: true) == [.planVorschau])
    }

    @Test("ergaenzte Schritte stehen in der festen Reihenfolge vor dem Plan-Block")
    func ergaenzteSchritteReihenfolge() {
        let antworten = OnboardingAntworten()
        #expect(antworten.schritte(umfang: .nurVorschau, hatStudio: true, ergaenzt: [.wieOft, .ziel]) == [
            .ziel, .wieOft, .planVorschau,
        ])
        #expect(antworten.schritte(umfang: .nurPlan, hatStudio: true, ergaenzt: [.ziel]) == [
            .ziel, .planZeit, .planSchwerpunkt, .planBeschwerden, .planVorschau,
        ])
        // Was ohnehin im Flow steht, kommt nicht doppelt.
        #expect(antworten.schritte(umfang: .nurVorschau, hatStudio: true, ergaenzt: [.planBeschwerden, .planBeschwerden]) == [
            .planBeschwerden, .planVorschau,
        ])
    }

    @Test("schritte nurBeschwerden ist nur 1.3, mit und ohne Studio")
    func schritteNurBeschwerden() {
        #expect(OnboardingAntworten().schritte(umfang: .nurBeschwerden, hatStudio: true) == [.planBeschwerden])
        #expect(OnboardingAntworten().schritte(umfang: .nurBeschwerden, hatStudio: false) == [.planBeschwerden])
    }

    @Test("die Schrittzeile zaehlt nur, was der Flow zeigt, und fehlt bei nur einem Schritt")
    func schrittzeile() {
        let schritte = OnboardingAntworten().schritte(umfang: .komplett, hatStudio: true)
        #expect(OnboardingSchrittzeile.text(nummer: 6, gesamt: schritte.count) == "Schritt 6 von 8")
        #expect(OnboardingSchrittzeile.text(nummer: 1, gesamt: 1) == nil)
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
