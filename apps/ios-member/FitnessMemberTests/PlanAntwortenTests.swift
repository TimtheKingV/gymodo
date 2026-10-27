import Foundation
import Testing
@testable import FitnessMember

/// Die Antworten des Onboarding-Blocks "Dein Trainingsplan" (Etappe 3,
/// Task 10): Vorbelegung, Schwerpunkt-Grenze, Einwilligung fuer
/// Beschwerden und wann die Home-Karte erscheint.
@Suite("PlanAntworten")
struct PlanAntwortenTests {
    @Test("Vorbelegung aus trainingProfile")
    func vorbelegungAusTrainingProfile() {
        let profil = TrainingsplanProfil(minutes: 60, experience: "regelmaessig", focus: ["po", "bauch"])
        let antworten = PlanAntworten(profil: profil)
        #expect(antworten.minuten == 60)
        #expect(antworten.erfahrung == "regelmaessig")
        #expect(antworten.schwerpunkt == ["po", "bauch"])
        // Beschwerden stehen nie im Profil (Gesundheitsdaten, eigener Abruf).
        #expect(antworten.beschwerden.isEmpty)
        #expect(antworten.einwilligung == false)
    }

    @Test("ohne trainingProfile ist alles leer")
    func ohneProfilLeer() {
        let antworten = PlanAntworten(profil: nil)
        #expect(antworten.minuten == nil)
        #expect(antworten.erfahrung == nil)
        #expect(antworten.schwerpunkt.isEmpty)
    }

    @Test("schwerpunkt begrenzt auf zwei")
    func schwerpunktBegrenztAufZwei() {
        var antworten = PlanAntworten(profil: nil)
        antworten.schwerpunktUmschalten("po")
        antworten.schwerpunktUmschalten("brust")
        // Das dritte Tippen ist wirkungslos -- kein Austausch, kein Fehler.
        antworten.schwerpunktUmschalten("bauch")
        #expect(antworten.schwerpunkt == ["po", "brust"])
        // Abwaehlen geht immer, danach ist wieder Platz.
        antworten.schwerpunktUmschalten("po")
        antworten.schwerpunktUmschalten("bauch")
        #expect(antworten.schwerpunkt == ["brust", "bauch"])
    }

    @Test("Weiter bleibt aktiv, nur Beschwerden ohne Einwilligung sind gedaempft")
    func kannWeiterJeSchritt() {
        var antworten = PlanAntworten(profil: nil)
        #expect(antworten.kannWeiter(.planZeit))
        #expect(antworten.kannWeiter(.planSchwerpunkt))
        #expect(antworten.kannWeiter(.planBeschwerden))

        antworten.setzeStufe("vorsichtig", fuer: "knie")
        #expect(!antworten.kannWeiter(.planBeschwerden))
        antworten.einwilligung = true
        #expect(antworten.kannWeiter(.planBeschwerden))
    }

    @Test("Nichts entfernt den Bereich, statt ihn als Stufe zu speichern")
    func nichtsEntferntBereich() {
        var antworten = PlanAntworten(profil: nil)
        antworten.setzeStufe("meiden", fuer: "knie")
        antworten.setzeStufe("nichts", fuer: "knie")
        #expect(antworten.beschwerden.isEmpty)
        #expect(antworten.stufe(fuer: "knie") == "nichts")
    }

    @Test("Beschwerden ohne Einwilligung werden nicht gesendet")
    func beschwerdenOhneEinwilligungNichtGesendet() {
        var antworten = PlanAntworten(profil: nil)
        antworten.setzeStufe("meiden", fuer: "knie")
        #expect(antworten.beschwerdenAktion == .keine)
        antworten.einwilligung = true
        #expect(antworten.beschwerdenAktion == .speichern(["knie": "meiden"]))
    }

    @Test("alle Bereiche auf Nichts ohne fruehere Einwilligung: kein Aufruf, auch mit Haken")
    func alleNichtsOhneFruehereEinwilligung() {
        var antworten = PlanAntworten(profil: nil)
        antworten.einwilligung = true
        #expect(antworten.beschwerdenAktion == .keine)
    }

    @Test("Widerruf (Einwilligung entfernt) sendet DELETE")
    func widerrufSendetDelete() {
        var antworten = PlanAntworten(profil: nil)
        antworten.beschwerdenUebernehmen(["knie": "vorsichtig"])
        #expect(antworten.einwilligung)
        #expect(antworten.beschwerdenAktion == .keine)

        antworten.einwilligung = false
        #expect(antworten.beschwerdenAktion == .widerrufen)
    }

    @Test("geaenderte Stufe mit fruehere Einwilligung wird neu gespeichert, auch leer")
    func geaenderteStufeNeuGespeichert() {
        var antworten = PlanAntworten(profil: nil)
        antworten.beschwerdenUebernehmen(["knie": "vorsichtig"])
        antworten.setzeStufe("nichts", fuer: "knie")
        #expect(antworten.beschwerdenAktion == .speichern([:]))
    }

    @Test("nach dem Schreiben gilt der gesendete Stand als frueherer")
    func nachSchreibenNeuerStand() {
        var antworten = PlanAntworten(profil: nil)
        antworten.setzeStufe("meiden", fuer: "schulter")
        antworten.einwilligung = true
        antworten.beschwerdenGeschrieben()
        #expect(antworten.beschwerdenAktion == .keine)

        antworten.einwilligung = false
        #expect(antworten.beschwerdenAktion == .widerrufen)
        antworten.beschwerdenGeschrieben()
        #expect(antworten.beschwerdenAktion == .keine)
    }

    @Test("Ueberspringen setzt die Beschwerden auf den frueheren Stand zurueck")
    func ueberspringenSetztZurueck() {
        var antworten = PlanAntworten(profil: nil)
        antworten.beschwerdenUebernehmen(["knie": "vorsichtig"])
        antworten.setzeStufe("meiden", fuer: "huefte")
        antworten.einwilligung = false
        antworten.beschwerdenVerwerfen()
        #expect(antworten.beschwerden == ["knie": "vorsichtig"])
        #expect(antworten.einwilligung)
        #expect(antworten.beschwerdenAktion == .keine)
    }

    @Test("Haken weg mit gewaehlten Bereichen: Weiter aktiv und DELETE")
    func abwaehlenMitBereichenWiderruft() {
        var antworten = PlanAntworten(profil: nil)
        antworten.beschwerdenUebernehmen(["knie": "meiden", "schulter": "vorsichtig"])
        antworten.einwilligung = false
        // Ohne Einwilligung darf keine Auswahl stehen bleiben -- sie liesse
        // sich ohnehin nicht senden und sperrte nur Weiter.
        #expect(antworten.beschwerden.isEmpty)
        #expect(antworten.kannWeiter(.planBeschwerden))
        #expect(antworten.beschwerdenAktion == .widerrufen)
    }

    @Test("Haken weg ohne gespeicherte Einwilligung: nichts wird gesendet")
    func abwaehlenOhneFruehereEinwilligung() {
        var antworten = PlanAntworten(profil: nil)
        antworten.setzeStufe("meiden", fuer: "knie")
        antworten.einwilligung = true
        antworten.einwilligung = false
        #expect(antworten.beschwerden.isEmpty)
        #expect(antworten.kannWeiter(.planBeschwerden))
        #expect(antworten.beschwerdenAktion == .keine)
    }

    @Test("Ueberspringen nach dem Abwaehlen sendet nichts und laesst den gespeicherten Stand")
    func ueberspringenNachAbwaehlen() {
        var antworten = PlanAntworten(profil: nil)
        antworten.beschwerdenUebernehmen(["knie": "meiden"])
        antworten.einwilligung = false
        antworten.beschwerdenVerwerfen()
        #expect(antworten.beschwerdenAktion == .keine)
    }

    @Test("Trainingsprofil nur mit Minuten und Erfahrung")
    func trainingsprofilNurVollstaendig() {
        var antworten = PlanAntworten(profil: nil)
        antworten.minuten = 45
        #expect(antworten.trainingsprofil == nil)
        antworten.erfahrung = "neu"
        antworten.schwerpunktUmschalten("beine")
        #expect(antworten.trainingsprofil == TrainingsplanProfil(minutes: 45, experience: "neu", focus: ["beine"]))
    }

    // MARK: - Karte 1.5

    private static func member(abgeschlossen: Bool = true, plans: [Trainingsplan] = [],
                               profil: TrainingsplanProfil? = nil) -> BootstrapResponse.Member {
        BootstrapResponse.Member(
            displayName: "Tim", onboardingCompletedAt: abgeschlossen ? "2026-10-01T10:00:00Z" : nil,
            trainingProfile: profil, plans: plans)
    }

    static func plan(studioId: String) -> Trainingsplan {
        let json = """
        {"planId":"p-\(studioId)","studioId":"\(studioId)","version":1,"regelVersion":"1.2.0",
         "struktur":"gk_eine","gruende":[],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":{},
         "einheiten":[{"key":"A","geschaetzteMinuten":30,"positionen":[]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    @Test("Karte erscheint nur ohne Plan im aktiven Studio")
    func karteNurOhnePlanImAktivenStudio() {
        // Plan nur in einem anderen Studio: Karte erscheint.
        #expect(PlanEinrichten.zeigtKarte(member: Self.member(plans: [Self.plan(studioId: "s2")]), studioId: "s1"))
        // Plan im aktiven Studio: keine Karte.
        #expect(!PlanEinrichten.zeigtKarte(member: Self.member(plans: [Self.plan(studioId: "s1")]), studioId: "s1"))
        // Kein Studio aktiv (Freies Training): keine Karte.
        #expect(!PlanEinrichten.zeigtKarte(member: Self.member(), studioId: nil))
        // Onboarding noch offen: das Gate zeigt den Block selbst, keine Karte.
        #expect(!PlanEinrichten.zeigtKarte(member: Self.member(abgeschlossen: false), studioId: "s1"))
    }

    @Test("Karte oeffnet ohne Profil alle vier Schritte, mit Profil nur die Vorschau")
    func karteUmfang() {
        #expect(PlanEinrichten.umfang(member: Self.member()) == .nurPlan)
        let profil = TrainingsplanProfil(minutes: 60, experience: "neu", focus: [])
        #expect(PlanEinrichten.umfang(member: Self.member(profil: profil)) == .nurVorschau)
    }

    // MARK: - Namen

    @Test("Bausteine haben deutsche Namen, Unbekanntes bleibt lesbar")
    func bausteinNamen() {
        #expect(BausteinName.text("beine_knie") == "Beine, Knie")
        #expect(BausteinName.text("druecken") == "Drücken")
        #expect(BausteinName.text("beine_ergaenzung") == "Beine, Ergänzung")
        #expect(BausteinName.text("cardio") == "Cardio")
        // Ein Baustein, den erst ein spaeterer Server kennt: kein Absturz,
        // kein Rohschluessel mit Unterstrich.
        #expect(BausteinName.text("neu_dabei") == "Neu dabei")
    }
}
