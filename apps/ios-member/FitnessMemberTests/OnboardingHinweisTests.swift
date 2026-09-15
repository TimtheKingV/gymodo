import Testing
@testable import FitnessMember

/// R22: der Bannertext nach einem gescheiterten Schreibversuch ist eine
/// reine Funktion aus dem, was noch offen ist, und dem Fehler -- ohne View
/// testbar, wie `OnboardingSchreiber` selbst.
@Suite("OnboardingHinweis")
struct OnboardingHinweisTests {
    @Test("bleibt das Profil offen, ist noch nichts gespeichert -- offline")
    func profilOffenOffline() {
        let satz = OnboardingHinweis.hinweis(offen: [.profil, .messwert, .wochenziel, .zielgewicht], fehler: .offline)
        #expect(satz == "Keine Verbindung. Noch nichts gespeichert — deine Angaben bleiben hier stehen.")
    }

    @Test("bleibt das Profil offen, ist noch nichts gespeichert -- Serverfehler")
    func profilOffenServerfehler() {
        let satz = OnboardingHinweis.hinweis(offen: [.profil], fehler: .server(message: "Der Dienst antwortet gerade nicht."))
        #expect(satz == "Der Dienst antwortet gerade nicht. Noch nichts gespeichert — deine Angaben bleiben hier stehen.")
    }

    @Test("Profil gespeichert, Gewicht und Wochenziel offen -- offline, wie im Beispiel der Weisung")
    func profilGespeichertZweiOffenOffline() {
        let satz = OnboardingHinweis.hinweis(offen: [.messwert, .wochenziel], fehler: .offline)
        #expect(satz == "Dein Profil ist gespeichert. Gewicht und Wochenziel noch nicht — keine Verbindung.")
    }

    @Test("Profil gespeichert, nur das Zielgewicht offen -- ein einzelner Teil ohne Aufzaehlung")
    func profilGespeichertEinTeilOffen() {
        let satz = OnboardingHinweis.hinweis(offen: [.zielgewicht], fehler: .offline)
        #expect(satz == "Dein Profil ist gespeichert. Zielgewicht noch nicht — keine Verbindung.")
    }

    @Test("Profil gespeichert, alle drei uebrigen Teile offen -- Aufzaehlung mit Komma und und")
    func profilGespeichertDreiTeileOffen() {
        let satz = OnboardingHinweis.hinweis(offen: [.messwert, .wochenziel, .zielgewicht], fehler: .offline)
        #expect(satz == "Dein Profil ist gespeichert. Gewicht, Wochenziel und Zielgewicht noch nicht — keine Verbindung.")
    }

    @Test("nicht offline: der Servertext ersetzt 'keine Verbindung', nicht ein zweites Mal draufgesattelt")
    func profilGespeichertServerfehler() {
        let satz = OnboardingHinweis.hinweis(offen: [.wochenziel], fehler: .validation(message: "Die Tage liegen außerhalb des Bereichs."))
        #expect(satz == "Dein Profil ist gespeichert. Wochenziel noch nicht — Die Tage liegen außerhalb des Bereichs.")
    }

    @Test("nie 'fehlgeschlagen', nie ein Ausrufezeichen (designsystem.md SS10)")
    func keinFehlgeschlagenKeinAusrufezeichen() {
        let saetze = [
            OnboardingHinweis.hinweis(offen: [.profil], fehler: .offline),
            OnboardingHinweis.hinweis(offen: [.messwert], fehler: .offline),
            OnboardingHinweis.hinweis(offen: [.messwert], fehler: .server(message: "Ein Problem ist aufgetreten.")),
        ]
        for satz in saetze {
            #expect(!satz.contains("fehlgeschlagen"))
            #expect(!satz.contains("!"))
        }
    }
}
