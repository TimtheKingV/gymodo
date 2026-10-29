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

    // MARK: - Kurse, Cardio, Deine Woche (Leinwaende 2c, 2c2, 2c3)

    @Test("ein Kurstag laesst sich nicht zugleich als Cardio waehlen (E4)")
    func kurstagNichtAlsCardio() {
        var antworten = PlanAntworten(profil: nil)
        antworten.kurseBeantworten(true)
        do {
            let ergebnis = antworten.tagUmschalten(1, fuer: .kurs)
            #expect(ergebnis == nil)
        }
        antworten.cardioBeantworten(true)
        do {
            let ergebnis = antworten.tagUmschalten(1, fuer: .cardio)
            #expect(ergebnis == .belegt(.kurs))
        }
        #expect(antworten.cardioTage.isEmpty)
        #expect(antworten.kursTage == [1])
        // Abwaehlen beim eigenen Schritt geht immer.
        do {
            let ergebnis = antworten.tagUmschalten(1, fuer: .kurs)
            #expect(ergebnis == nil)
        }
        #expect(antworten.kursTage.isEmpty)
    }

    @Test("der siebte feste Tag ist gesperrt, einer bleibt fuers Krafttraining")
    func siebterTagGesperrt() {
        var antworten = PlanAntworten(profil: nil)
        antworten.kurseBeantworten(true)
        for tag in 1...4 { antworten.tagUmschalten(tag, fuer: .kurs) }
        antworten.cardioBeantworten(true)
        antworten.tagUmschalten(5, fuer: .cardio)
        antworten.tagUmschalten(6, fuer: .cardio)
        do {
            let ergebnis = antworten.tagUmschalten(7, fuer: .cardio)
            #expect(ergebnis == .letzterFreierTag)
        }
        #expect(antworten.cardioTage == [5, 6])
        #expect(antworten.tagGesperrt(7, fuer: .cardio) == .letzterFreierTag)
        #expect(antworten.tagGesperrt(4, fuer: .cardio) == .belegt(.kurs))
        #expect(antworten.tagGesperrt(5, fuer: .cardio) == nil)
    }

    @Test("Nein leert Tage und Arten")
    func neinLeertTageUndArten() {
        var antworten = PlanAntworten(profil: nil)
        antworten.kurseBeantworten(true)
        antworten.tagUmschalten(2, fuer: .kurs)
        antworten.kurseBeantworten(false)
        #expect(antworten.kursTage.isEmpty)
        #expect(antworten.kursAntwort == false)

        antworten.cardioBeantworten(true)
        antworten.tagUmschalten(7, fuer: .cardio)
        antworten.cardioArtUmschalten("laufen")
        antworten.cardioBeantworten(false)
        #expect(antworten.cardioTage.isEmpty)
        #expect(antworten.cardioArten.isEmpty)
        #expect(antworten.cardioAntwort == false)
    }

    @Test("Weiter ist gesperrt, solange Ja ohne Tag (Cardio: ohne Art) steht")
    func weiterGesperrtBeiJaOhneTag() {
        var antworten = PlanAntworten(profil: nil)
        // Noch nichts getippt: Weiter geht (wie Nein).
        #expect(antworten.kannWeiter(.planKurse))
        #expect(antworten.kannWeiter(.planCardio))

        antworten.kurseBeantworten(true)
        #expect(!antworten.kannWeiter(.planKurse))
        antworten.tagUmschalten(1, fuer: .kurs)
        #expect(antworten.kannWeiter(.planKurse))

        antworten.cardioBeantworten(true)
        #expect(!antworten.kannWeiter(.planCardio))
        antworten.tagUmschalten(7, fuer: .cardio)
        #expect(!antworten.kannWeiter(.planCardio))
        antworten.cardioArtUmschalten("laufen")
        #expect(antworten.kannWeiter(.planCardio))
        antworten.tagUmschalten(7, fuer: .cardio)
        #expect(!antworten.kannWeiter(.planCardio))
        antworten.cardioBeantworten(false)
        #expect(antworten.kannWeiter(.planCardio))
    }

    @Test("ohne Studio mit Kursen entfaellt die Kursfrage, der Zaehler passt sich an")
    func kursFrageOhneStudio() {
        let antworten = PlanAntworten(profil: nil)
        #expect(!antworten.kursFrageSichtbar(hatStudioMitKursen: false))
        #expect(antworten.kursFrageSichtbar(hatStudioMitKursen: true))

        let onboarding = OnboardingAntworten()
        let ohne = onboarding.schritte(
            umfang: .nurPlan, mitKursen: antworten.kursFrageSichtbar(hatStudioMitKursen: false))
        let mit = onboarding.schritte(
            umfang: .nurPlan, mitKursen: antworten.kursFrageSichtbar(hatStudioMitKursen: true))
        #expect(ohne == [.planZeit, .planSchwerpunkt, .planBeschwerden, .planCardio, .planWoche, .planVorschau])
        #expect(mit == [.planZeit, .planSchwerpunkt, .planBeschwerden, .planKurse, .planCardio, .planWoche, .planVorschau])
        #expect(OnboardingSchrittzeile.text(nummer: 4, gesamt: ohne.count) == "Schritt 4 von 6")
        #expect(OnboardingSchrittzeile.text(nummer: 4, gesamt: mit.count) == "Schritt 4 von 7")
    }

    @Test("ohne Kursfrage gelten keine Kurstage, auch wenn das Profil welche hatte")
    func kurseOhneStudioGeleert() {
        let profil = TrainingsplanProfil(minutes: 60, experience: "neu", focus: [], kursTage: [1], cardioTage: [], cardioArten: [], kraftTage: [])
        var antworten = PlanAntworten(profil: profil)
        antworten.kurseOhneFrage()
        #expect(antworten.kursTage.isEmpty)
        #expect(antworten.tagGesperrt(1, fuer: .cardio) == nil)
    }

    @Test("Vorbelegung der Tage aus dem Profil, Ja nur mit Tagen")
    func vorbelegungTage() {
        let profil = TrainingsplanProfil(
            minutes: 60, experience: "neu", focus: [],
            kursTage: [1], cardioTage: [], cardioArten: ["laufen"], kraftTage: [3, 5])
        let antworten = PlanAntworten(profil: profil)
        #expect(antworten.kursTage == [1])
        #expect(antworten.kursAntwort == true)
        #expect(antworten.cardioTage.isEmpty)
        #expect(antworten.cardioAntwort == nil)
        #expect(antworten.cardioArten == ["laufen"])
        #expect(antworten.kraftTage == [3, 5])
    }

    @Test("Tagesfelder gehen nur mit, wenn der Flow die Woche gefragt hat")
    func tagesfelderNurWennGefragt() {
        var antworten = PlanAntworten(profil: nil)
        antworten.minuten = 60
        antworten.erfahrung = "neu"
        // Ohne Wochenfragen (etwa nur "Zeit oder Schwerpunkt ändern"): nil = nicht senden.
        #expect(antworten.trainingsprofil?.kursTage == nil)
        #expect(antworten.trainingsprofil?.kraftTage == nil)

        antworten.wochenGefragt = true
        antworten.kurseBeantworten(true)
        antworten.tagUmschalten(1, fuer: .kurs)
        antworten.cardioBeantworten(true)
        antworten.tagUmschalten(7, fuer: .cardio)
        antworten.cardioArtUmschalten("laufen")
        let profil = antworten.trainingsprofil
        #expect(profil?.kursTage == [1])
        #expect(profil?.cardioTage == [7])
        #expect(profil?.cardioArten == ["laufen"])
        // Kein Tausch: leer = der Server verteilt die Krafttage selbst.
        #expect(profil?.kraftTage == [])
    }

    private static let raster = [
        Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
        Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
        Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
        Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
    ]

    private static func mitWoche() -> PlanAntworten {
        var antworten = PlanAntworten(profil: nil)
        antworten.minuten = 60
        antworten.erfahrung = "neu"
        antworten.wochenGefragt = true
        antworten.kurseBeantworten(true)
        antworten.tagUmschalten(1, fuer: .kurs)
        antworten.cardioBeantworten(true)
        antworten.tagUmschalten(7, fuer: .cardio)
        antworten.cardioArtUmschalten("laufen")
        return antworten
    }

    @Test("ohne Tausch zeigt Deine Woche genau das Raster des Servers")
    func wocheOhneTauschIstServerRaster() {
        let antworten = Self.mitWoche()
        #expect(antworten.wochenAnzeige(raster: Self.raster, einheiten: ["A", "B"]) == Self.raster)
    }

    @Test("Tauschen legt einen Krafttag auf einen freien Tag und schreibt kraftTage")
    func tauschenSchreibtKraftTage() {
        var antworten = Self.mitWoche()
        do {
            let ergebnis = antworten.kraftTagTauschen(von: 5, nach: 6, raster: Self.raster)
            #expect(ergebnis)
        }
        #expect(antworten.kraftTage == [3, 6])
        #expect(antworten.trainingsprofil?.kraftTage == [3, 6])
        let anzeige = antworten.wochenAnzeige(raster: Self.raster, einheiten: ["A", "B"])
        #expect(anzeige == [
            Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
            Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
            Rasterplatz(tag: 6, art: .kraft, einheitKey: "B"),
            Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
        ])
        // Ein zweiter Tausch rechnet vom getauschten Stand aus.
        do {
            let ergebnis = antworten.kraftTagTauschen(von: 3, nach: 2, raster: Self.raster)
            #expect(ergebnis)
        }
        #expect(antworten.kraftTage == [2, 6])
    }

    @Test("Tauschen auf einen festen oder Kraft-Tag wird abgelehnt")
    func tauschenAufBelegtenTag() {
        var antworten = Self.mitWoche()
        do {
            let ergebnis = antworten.kraftTagTauschen(von: 3, nach: 1, raster: Self.raster)
            #expect(!ergebnis)
        }
        do {
            let ergebnis = antworten.kraftTagTauschen(von: 3, nach: 7, raster: Self.raster)
            #expect(!ergebnis)
        }
        do {
            let ergebnis = antworten.kraftTagTauschen(von: 3, nach: 5, raster: Self.raster)
            #expect(!ergebnis)
        }
        do {
            let ergebnis = antworten.kraftTagTauschen(von: 2, nach: 4, raster: Self.raster)
            #expect(!ergebnis)
        }
        #expect(antworten.kraftTage.isEmpty)
    }

    @Test("geaenderte Kurs- oder Cardio-Antworten verwerfen den Tausch")
    func aenderungVerwirftTausch() {
        var antworten = Self.mitWoche()
        antworten.kraftTagTauschen(von: 5, nach: 6, raster: Self.raster)
        antworten.tagUmschalten(6, fuer: .cardio)
        #expect(antworten.kraftTage.isEmpty)
        #expect(antworten.cardioTage == [6, 7])

        antworten.kraftTagTauschen(von: 5, nach: 4, raster: Self.raster)
        antworten.kurseBeantworten(false)
        #expect(antworten.kraftTage.isEmpty)

        antworten.kraftTagTauschen(von: 5, nach: 4, raster: Self.raster)
        antworten.wocheNeuVorschlagen()
        #expect(antworten.kraftTage.isEmpty)
    }

    @Test("Ueberspringen stellt Kurs- und Cardio-Stand vom Server wieder her")
    func ueberspringenStelltWiederHer() {
        let profil = TrainingsplanProfil(
            minutes: 60, experience: "neu", focus: [],
            kursTage: [2], cardioTage: [6], cardioArten: ["wandern"], kraftTage: [])
        var antworten = PlanAntworten(profil: profil)
        antworten.kurseBeantworten(false)
        antworten.kurseVerwerfen()
        #expect(antworten.kursTage == [2])
        #expect(antworten.kursAntwort == true)
        antworten.cardioArtUmschalten("laufen")
        antworten.tagUmschalten(6, fuer: .cardio)
        antworten.cardioVerwerfen()
        #expect(antworten.cardioTage == [6])
        #expect(antworten.cardioArten == ["wandern"])
    }

    @Test("Hinweise unter den Tagen nennen die Tage, nicht die Zahl der Einheiten")
    func wochenHinweise() {
        #expect(PlanWochenText.kursHinweis([1]) == "Montags ist dein Kurs gesetzt. Die Kraft-Einheiten legen wir auf die übrigen Tage.")
        #expect(PlanWochenText.kursHinweis([1, 4]) == "Montags und donnerstags sind deine Kurse gesetzt. Die Kraft-Einheiten legen wir auf die übrigen Tage.")
        #expect(PlanWochenText.kursHinweis([]) == nil)
        #expect(PlanWochenText.cardioHinweis([7]) == "Cardio am Sonntag ist ein fester Termin im Plan. Umfang und Tempo kommen später, jetzt zählt nur die Einheit.")
        #expect(PlanWochenText.cardioHinweis([2, 4, 7]) == "Cardio am Dienstag, Donnerstag und Sonntag sind feste Termine im Plan. Umfang und Tempo kommen später, jetzt zählt nur die Einheit.")
        #expect(PlanWochenText.tagLabel(1, ausgewaehlt: true) == "Montag, ausgewählt")
        #expect(PlanWochenText.tagLabel(3, ausgewaehlt: false) == "Mittwoch, nicht ausgewählt")
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
