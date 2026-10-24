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

    // MARK: - Block "Dein Trainingsplan" (Etappe 3)

    @Test("Plan-Vorgaenge haben eigene Namen in der Aufzaehlung")
    func planVorgaengeImSatz() {
        let satz = OnboardingHinweis.hinweis(offen: [.trainingsprofil, .beschwerden], fehler: .offline)
        #expect(satz == "Dein Profil ist gespeichert. Zeit und Erfahrung sowie Beschwerden noch nicht — keine Verbindung.")
    }

    @Test("ohne Bestandsschritte sagt der Satz nicht, das Profil sei gespeichert")
    func ohneBestandKeinProfilSatz() {
        let satz = OnboardingHinweis.hinweis(offen: [.trainingsprofil], fehler: .offline, mitBestand: false)
        #expect(satz == "Keine Verbindung. Zeit und Erfahrung noch nicht gespeichert — deine Angaben bleiben hier stehen.")
    }

    @Test("Hinweistext fuer plan_nicht_moeglich nennt den Baustein deutsch")
    func planNichtMoeglichNenntBaustein() {
        let beschwerden = OnboardingHinweis.planSonderfall(
            .planNichtMoeglich(message: "x", baustein: "beine_knie", grund: "beschwerden"),
            beschwerden: ["knie": "meiden"])
        #expect(beschwerden == PlanSonderfall(
            titel: "Das geht noch nicht",
            text: "Mit deiner Angabe zu Knie bleibt für „Beine, Knie“ keine Übung übrig, die dein Studio anbietet.",
            aktion: .beschwerdenAendern))

        let keinGeraet = OnboardingHinweis.planSonderfall(
            .planNichtMoeglich(message: "x", baustein: "druecken", grund: "kein_geraet"), beschwerden: [:])
        #expect(keinGeraet == PlanSonderfall(
            titel: "Das geht noch nicht",
            text: "Dein Studio hat dafür gerade kein aktives Gerät: Drücken.",
            aktion: nil))
    }

    @Test("Beschwerden ohne bekannte Bereiche: der Satz bleibt allgemein, mehrere Bereiche werden aufgezaehlt")
    func planNichtMoeglichBereiche() {
        let ohne = OnboardingHinweis.planSonderfall(
            .planNichtMoeglich(message: "x", baustein: "schulter", grund: "beschwerden"), beschwerden: [:])
        #expect(ohne?.text == "Mit deinen Angaben zu Beschwerden bleibt für „Schulter“ keine Übung übrig, die dein Studio anbietet.")
        let zwei = OnboardingHinweis.planSonderfall(
            .planNichtMoeglich(message: "x", baustein: "beine_knie", grund: "beschwerden"),
            beschwerden: ["huefte": "vorsichtig", "knie": "meiden"])
        #expect(zwei?.text == "Mit deinen Angaben zu Knie und Hüfte bleibt für „Beine, Knie“ keine Übung übrig, die dein Studio anbietet.")
    }

    @Test("Hinweistext fuer profil_unvollstaendig nennt fehlende Angaben")
    func profilUnvollstaendigNenntFehlendes() {
        let zwei = OnboardingHinweis.planSonderfall(.profilUnvollstaendig(message: "x", fehlt: ["ziel", "tage"]), beschwerden: [:])
        #expect(zwei == PlanSonderfall(
            titel: "Zwei Angaben fehlen",
            text: "Für den Plan brauchen wir noch dein Ziel und deine Trainingstage.",
            aktion: .ergaenzen([.ziel, .wieOft])))

        let eine = OnboardingHinweis.planSonderfall(.profilUnvollstaendig(message: "x", fehlt: ["trainingsprofil"]), beschwerden: [:])
        #expect(eine == PlanSonderfall(
            titel: "Eine Angabe fehlt",
            text: "Für den Plan brauchen wir noch deine Zeit und Erfahrung.",
            aktion: .ergaenzen([.planZeit])))
    }

    @Test("andere Fehler sind kein Sonderfall, sondern ein Banner")
    func andereFehlerKeinSonderfall() {
        #expect(OnboardingHinweis.planSonderfall(.offline, beschwerden: [:]) == nil)
        #expect(OnboardingHinweis.planFehler(.offline, beimUebernehmen: false)
            == "Keine Verbindung. Für den Vorschlag braucht die App eine Verbindung.")
        #expect(OnboardingHinweis.planFehler(.offline, beimUebernehmen: true)
            == "Keine Verbindung. Dein Plan ist noch nicht übernommen.")
        #expect(OnboardingHinweis.planFehler(.server(message: "Der Dienst antwortet gerade nicht."), beimUebernehmen: true)
            == "Der Dienst antwortet gerade nicht. Dein Plan ist noch nicht übernommen.")
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
