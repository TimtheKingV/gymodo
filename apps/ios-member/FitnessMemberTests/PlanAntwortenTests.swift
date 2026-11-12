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

    @Test("Karte erscheint im Freien Training ohne Plan")
    func karteImFreienTrainingOhnePlan() {
        // Kein Studio noetig: der Plan gehoert dem Mitglied, nicht einem Ort.
        #expect(PlanEinrichten.zeigtKarte(member: Self.member()))
    }

    @Test("Karte erscheint nicht mit Plan")
    func karteNichtMitPlan() {
        #expect(!PlanEinrichten.zeigtKarte(member: Self.member(plans: [Self.plan(studioId: "s1")])))
        // Auch ein Plan eines anderen Ortes ist der Plan des Mitglieds.
        #expect(!PlanEinrichten.zeigtKarte(member: Self.member(plans: [Self.plan(studioId: "s2")])))
    }

    @Test("Karte erscheint nicht vor dem Onboarding")
    func karteNichtVorDemOnboarding() {
        // Das Gate zeigt den Block selbst.
        #expect(!PlanEinrichten.zeigtKarte(member: Self.member(abgeschlossen: false)))
    }

    @Test("Karte oeffnet ohne Profil alle vier Schritte, mit Profil nur die Vorschau")
    func karteUmfang() {
        #expect(PlanEinrichten.umfang(member: Self.member()) == .nurPlan)
        let profil = TrainingsplanProfil(minutes: 60, experience: "neu", focus: [])
        #expect(PlanEinrichten.umfang(member: Self.member(profil: profil)) == .nurVorschau)
    }

    // MARK: - Cardio und Deine Woche (Wochenplan ohne Tage, Spec §4)

    @Test("Vorbelegung des Wochenziels aus dem Profil, ohne Profil Kraft 2 und kein Cardio")
    func vorbelegungWoche() {
        let leer = PlanAntworten(profil: nil)
        #expect(leer.woche == WochenAuswahl(ziel: Wochenziel(kraft: 2, cardio: 0, cardioMinuten: 30), profil: nil))

        let profil = TrainingsplanProfil(
            minutes: 60, experience: "neu", focus: [], cardioArten: ["laufen"],
            kraftProWoche: 3, cardioProWoche: 2, cardioMinuten: 45)
        let antworten = PlanAntworten(profil: profil)
        #expect(antworten.woche.kraft == 3)
        #expect(antworten.woche.cardio == 2)
        #expect(antworten.woche.cardioMinuten == 45)
        #expect(antworten.woche.cardioArten == ["laufen"])
    }

    @Test("Kraft folgt der Wie-oft-Antwort, sonst dem Wochenziel, sonst 2")
    func kraftVorbelegungAusWieOft() {
        #expect(PlanAntworten(profil: nil, wieOft: 4).woche.kraft == 4)
        // Geklemmt auf 1...7.
        #expect(PlanAntworten(profil: nil, wieOft: 9).woche.kraft == 7)
        let ziel = Wochenziel(kraft: 3, cardio: 1, cardioMinuten: 30)
        #expect(PlanAntworten(profil: nil, wieOft: nil, wochenziel: ziel).woche.kraft == 3)
        #expect(PlanAntworten(profil: nil, wieOft: 4, wochenziel: ziel).woche.kraft == 4)
        #expect(PlanAntworten(profil: nil).woche.kraft == 2)
    }

    @Test("ein Kraft-Ziel im Profil gewinnt gegen die Wie-oft-Antwort")
    func profilKraftGewinnt() {
        let profil = TrainingsplanProfil(
            minutes: 60, experience: "neu", focus: [], kraftProWoche: 5, cardioProWoche: 0, cardioMinuten: 30)
        var antworten = PlanAntworten(profil: profil, wieOft: 4)
        #expect(antworten.woche.kraft == 5)
        antworten.kraftVorbelegen(wieOft: 3, wochenziel: Wochenziel(kraft: 6, cardio: 0, cardioMinuten: 30))
        #expect(antworten.woche.kraft == 5)
    }

    @Test("die spaete Antwort auf Wie oft setzt Kraft nach")
    func kraftVorbelegenNachtraeglich() {
        var antworten = PlanAntworten(profil: nil)
        #expect(antworten.woche.kraft == 2)
        antworten.kraftVorbelegen(wieOft: 4, wochenziel: nil)
        #expect(antworten.woche.kraft == 4)
    }

    @Test("Zusammenfassung nennt Zaehler und Minuten, der Cardio-Teil entfaellt bei 0")
    func zusammenfassung() {
        var antworten = PlanAntworten(profil: nil)
        antworten.woche.kraft = 2
        antworten.woche.cardio = 1
        antworten.woche.cardioMinuten = 30
        #expect(antworten.zusammenfassung == "2× Kraft · 1× Cardio 30 min · Kurse nach Buchung")
        antworten.woche.cardio = 0
        #expect(antworten.zusammenfassung == "2× Kraft · Kurse nach Buchung")
        antworten.woche.kraft = 4
        antworten.woche.cardio = 3
        antworten.woche.cardioMinuten = 45
        #expect(antworten.zusammenfassung == "4× Kraft · 3× Cardio 45 min · Kurse nach Buchung")
    }

    @Test("Weiter im Cardio-Schritt: ohne Cardio immer, mit Cardio erst mit einer Art")
    func weiterImCardioSchritt() {
        var antworten = PlanAntworten(profil: nil)
        #expect(antworten.kannWeiter(.planCardio))
        #expect(antworten.weiterGesperrtHinweis(.planCardio) == nil)

        antworten.woche.cardio = 1
        #expect(!antworten.kannWeiter(.planCardio))
        #expect(antworten.weiterGesperrtHinweis(.planCardio) == "Erst wählen, was du machst.")
        antworten.cardioArtUmschalten("laufen")
        #expect(antworten.kannWeiter(.planCardio))
        antworten.woche.cardio = 0
        #expect(antworten.kannWeiter(.planCardio))
    }

    @Test("Cardio-Arten bleiben in Anzeigereihenfolge")
    func cardioArtenReihenfolge() {
        var antworten = PlanAntworten(profil: nil)
        antworten.cardioArtUmschalten("wandern")
        antworten.cardioArtUmschalten("laufen")
        #expect(antworten.woche.cardioArten == ["laufen", "wandern"])
        antworten.cardioArtUmschalten("laufen")
        #expect(antworten.woche.cardioArten == ["wandern"])
    }

    @Test("Zaehler gehen nur mit, wenn der Flow die Woche gefragt hat, und ohne Tagesfelder")
    func zaehlerNurWennGefragt() throws {
        var antworten = PlanAntworten(profil: nil)
        antworten.minuten = 60
        antworten.erfahrung = "neu"
        // Ohne Wochenfragen (etwa nur "Zeit oder Schwerpunkt ändern"): nil = nicht senden.
        #expect(antworten.trainingsprofil?.kraftProWoche == nil)
        #expect(antworten.trainingsprofil?.cardioProWoche == nil)

        antworten.wochenGefragt = true
        antworten.woche.kraft = 3
        antworten.woche.cardio = 2
        antworten.woche.cardioMinuten = 40
        antworten.cardioArtUmschalten("laufen")
        let profil = try #require(antworten.trainingsprofil)
        #expect(profil.kraftProWoche == 3)
        #expect(profil.cardioProWoche == 2)
        #expect(profil.cardioMinuten == 40)
        #expect(profil.cardioArten == ["laufen"])
        #expect(profil.kursTage == nil && profil.cardioTage == nil && profil.kraftTage == nil)

        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(profil)) as? [String: Any])
        for key in ["kursTage", "cardioTage", "kraftTage"] { #expect(json[key] == nil) }
        #expect(json["kraftProWoche"] as? Int == 3)
    }

    @Test("Cardio-Arten ohne Cardio gehen leer raus")
    func cardioArtenOhneCardioLeer() {
        let profil = TrainingsplanProfil(
            minutes: 60, experience: "neu", focus: [], cardioArten: ["laufen"],
            kraftProWoche: 2, cardioProWoche: 0, cardioMinuten: 30)
        var antworten = PlanAntworten(profil: profil)
        antworten.wochenGefragt = true
        #expect(antworten.trainingsprofil?.cardioArten == [])
        antworten.woche.cardio = 1
        #expect(antworten.trainingsprofil?.cardioArten == ["laufen"])
    }

    @Test("Ueberspringen stellt den Cardio-Stand vom Server wieder her")
    func ueberspringenStelltWiederHer() {
        let profil = TrainingsplanProfil(
            minutes: 60, experience: "neu", focus: [], cardioArten: ["wandern"],
            kraftProWoche: 3, cardioProWoche: 1, cardioMinuten: 20)
        var antworten = PlanAntworten(profil: profil)
        antworten.woche.cardio = 4
        antworten.woche.cardioMinuten = 60
        antworten.cardioArtUmschalten("laufen")
        antworten.cardioVerwerfen()
        #expect(antworten.woche.cardio == 1)
        #expect(antworten.woche.cardioMinuten == 20)
        #expect(antworten.woche.cardioArten == ["wandern"])
        // Kraft gehoert zu "Deine Woche", nicht zum Cardio-Schritt.
        #expect(antworten.woche.kraft == 3)
    }

    @Test("Der Hinweis steht an einer Stelle: Du legst fest, wie oft, nicht wann")
    func hinweisEineQuelle() {
        #expect(WochenAuswahl.hinweis == "Du legst fest, wie oft – nicht wann. Montag beginnt die Woche neu.")
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
