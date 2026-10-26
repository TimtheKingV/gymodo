import Foundation
import Sensorik
import Testing
@testable import FitnessMember

/// Nur die Ableitungen werden geprueft -- reine SwiftUI-Views werden laut
/// Spec Abschnitt 10 manuell gegen die Artboards abgenommen.
@MainActor
struct GeraetModelTests {
    private func modell(
        maschine: BootstrapResponse.Machine,
        bootstrap: BootstrapResponse,
        sessions: WorkoutSessionStore? = nil,
        loader: FakeGeraetLoader = FakeGeraetLoader(),
        enqueue: @escaping (PendingSetWrite) -> Void = { _ in },
        satzZiel: Int = Einstellungen.satzZielVorgabe,
        mitschnitt: (any SatzMitschnitt)? = nil,
        zaehler: (any SatzZaehler)? = nil,
        startwerte: Startwerte? = nil
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            station: Station(maschine: maschine),
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: bootstrap,
            loader: loader,
            sessions: sessions ?? WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: enqueue,
            satzZiel: { satzZiel },
            mitschnitt: mitschnitt,
            zaehler: zaehler,
            startwerte: startwerte
        )
    }

    /// Offline-Spec 3b: ohne Kontext (kein Netz) kommt der Text aus dem Bootstrap.
    @Test func beschreibungOhneKontextAusDemBootstrap() {
        let maschine: BootstrapResponse.Machine = GeraetTestdaten.dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Beidbeinig","description":"Knie nicht durchdruecken.",
                       "volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
        let sut = modell(maschine: maschine, bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.kontext == nil)
        #expect(sut.beschreibung == "Knie nicht durchdruecken.")
    }

    private static let brustMuskeln = #"[{"key":"chest","name":"Brust","role":"primary"},{"key":"triceps","name":"Trizeps","role":"secondary"}]"#

    private func maschineMitMuskeln(_ muskeln: String) -> BootstrapResponse.Machine {
        GeraetTestdaten.dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Brustpresse","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Brustpresse","volumeKind":"reps","targetMin":8,"targetMax":12,
                       "muscles":\(muskeln)}]}
        """)
    }

    /// Flugmodus: ohne Kontext kommen die Muskeln aus dem Bootstrap.
    @Test func muskelnOhneKontextAusDemBootstrap() {
        let sut = modell(maschine: maschineMitMuskeln(Self.brustMuskeln),
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.kontext == nil)
        #expect(sut.muskeln == [GeraetMuskel(key: "chest", name: "Brust", role: .primary),
                                GeraetMuskel(key: "triceps", name: "Trizeps", role: .secondary)])
    }

    @Test func muskelnAusDemKontextGehenVor() {
        let sut = modell(maschine: maschineMitMuskeln(Self.brustMuskeln),
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0, muskeln: #"[{"key":"quads","name":"Quadrizeps","role":"primary"}]"#))
        #expect(sut.muskeln == [GeraetMuskel(key: "quads", name: "Quadrizeps", role: .primary)])
    }

    @Test func leereKontextMuskelnFallenAufDenBootstrapZurueck() {
        let sut = modell(maschine: maschineMitMuskeln(Self.brustMuskeln),
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))
        #expect(sut.muskeln.map(\.key) == ["chest", "triceps"])
    }

    @Test func ohneMuskelnAmBootstrapIstDieListeLeer() {
        let sut = modell(maschine: maschineMitMuskeln("[]"),
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.muskeln.isEmpty)
    }

    @Test func startetOhneHistorieAmGeraeteminimum() {
        // designsystem.md SS8: "Beim ersten Mal schlaegt gymodo kein Gewicht
        // vor. Das Rad startet am Geraetminimum."
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.belastung == 5.0)
        #expect(sut.vorschlagText == nil)
    }

    /// Testnotiz 12.10. abends, #3: mit einem Startwert am Modell steht das
    /// Rad dort statt am Minimum -- gerastet auf die Schritte des Geraets.
    @Test func startetOhneHistorieAmStartwertDesModells() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschine(loadMax: "150.0", loadStart: "41.0"),
                         bootstrap: bootstrap)

        #expect(sut.belastung == 40.0)
    }

    @Test func derLetzteSatzGehtVorDemStartwert() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine(loadMax: "150.0", loadStart: "40.0"),
                         bootstrap: bootstrap)

        #expect(sut.belastung == 77.5)
    }

    @Test func eineNeueUebungStartetAmStartwert() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let maschine: BootstrapResponse.Machine = GeraetTestdaten.dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "loadStart":40.0,"settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12},
                      {"id":"e2","name":"Einbeinig","volumeKind":"reps","targetMin":6,"targetMax":10}]}
        """)
        let sut = modell(maschine: maschine, bootstrap: bootstrap)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.belastung == 40.0)
    }

    @Test func uebernimmtDenLetztenEigenenWertOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.belastung == 77.5)
        #expect(sut.umfang == 11)
        #expect(sut.rueckblick?.zuletzt == "77,5 kg × 11")
        // Kraft unveraendert: die Belastung mit Einheit.
        #expect(sut.letzterSatzText(fuer: "e1") == "77,5 kg")
    }

    @Test func rastetEinenVorschlagAufDieSchrittweite() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 80.0)
        #expect(sut.vorschlagText == "Vorschlag · +2,5 kg")
    }

    @Test func kontextUebernehmenUebernimmtDenVorschlagOhneBerührungDesRades() {
        // Unangetastet: kontextLaden() kann jederzeit nach dem initialen
        // Rendern eintreffen -- ohne eigene Eingabe des Mitglieds soll der
        // Vorschlag ganz normal greifen (Review-Fund I2, "unberuehrt").
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 80.0)
    }

    @Test func kontextUebernehmenLaesstEinenSelbstGewaehltenWertInRuhe() {
        // Ein spaet eintreffender tagContext darf den Wert nicht mehr unter
        // dem Daumen ersetzen, sobald das Mitglied am Rad gedreht hat
        // (Review-Fund I2). belastungGewaehlt(_:) ist der einzige Weg dahin --
        // seit die Raeder immer offen sind, gibt es kein "Oeffnen" mehr, an
        // dem man es festmachen koennte.
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
        sut.belastungGewaehlt(75.0)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 75.0)
        // Der Vorschlag selbst bleibt sichtbar -- nur die Uebernahme in
        // belastung unterbleibt.
        #expect(sut.vorschlagText == "Vorschlag · +2,5 kg")
    }

    @Test func uebungWechselnGibtDenWertWiederFrei() {
        // Neue Uebung, neuer Wert: die Markierung "vom Mitglied gewaehlt" gilt
        // fuer die alte Uebung. Ein Vorschlag, der danach eintrifft, darf
        // wieder greifen -- sonst bliebe das Rad fuer e2 auf dem Wert von e1.
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        sut.belastungGewaehlt(75.0)

        sut.uebungWechseln(zu: "e2")
        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 80.0)
    }

    @Test func meldetDenAnschlagNurWennEsEinenGibt() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.anschlagText == "Maximum des Geräts erreicht")

        let ohneGrenze = modell(maschine: GeraetTestdaten.maschineOhneMaximum,
                                bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(ohneGrenze.anschlagText == nil)
    }

    @Test func einstellwerteTragenDieBeschriftungAuchOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [], mitKalibrierung: true)
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.einstellwerte.first?.label == "Sitzposition")
        #expect(sut.einstellwerte.first?.anzeige == "4")
    }

    @Test func hatEinstellparameterFolgtDenDefinitionenDesModells() {
        let mit = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        let ohne = modell(maschine: GeraetTestdaten.maschineOhneEinstellparameter,
                          bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(mit.hatEinstellparameter == true)
        #expect(ohne.hatEinstellparameter == false)
    }

    @Test func ohneEinstellparameterBleibenDieEinstellwerteLeer() {
        // GeraetView haengt die Zeile mit "aendern" an nicht leere
        // Einstellwerte. Ohne Definitionen gibt es nichts zu beschriften --
        // auch dann nicht, wenn bootstrap zu diesem Geraet noch Werte traegt
        // (etwa aus einer Zeit, in der das Modell Parameter hatte). Sonst
        // fuehrte "aendern" in einen Schritt, den es nicht mehr gibt.
        let sut = modell(maschine: GeraetTestdaten.maschineOhneEinstellparameter,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [], mitKalibrierung: true))

        #expect(sut.einstellwerte.isEmpty)
    }

    @Test func satzNummerZaehltImBlock() async {
        // Jeder Satz geht durch die Warteschlange, immer -- ein geloeschter
        // enqueue-Aufruf muss hier auffallen, nicht nur satzNummer/phase
        // (designsystem.md Konstante "gespeichert, wird gesendet").
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) })
        #expect(sut.satzNummer == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.satzNummer == 2)
        #expect(sut.laufendePause != nil)

        let laufendeSession = sessions.aktiveSession()
        let gespeicherterSatz = laufendeSession?.bloecke.first?.saetze.first
        #expect(erfasser.geschriebene.count == 1)
        #expect(erfasser.geschriebene.first?.sessionId == laufendeSession?.id)
        #expect(erfasser.geschriebene.first?.setId == gespeicherterSatz?.id)
        #expect(erfasser.geschriebene.first?.body.load == sut.belastung)
        #expect(erfasser.geschriebene.first?.body.volume == sut.umfang)
        // Die Gegenprobe aus Spec Abschnitt 9: ein Kraftsatz traegt keine
        // Nebenbelastung -- der Server wiese ihn sonst ab.
        #expect(erfasser.geschriebene.first?.body.secondaryLoad == nil)
        #expect(laufendeSession?.bloecke.first?.einheiten == .kilogrammWiederholungen)
    }

    /// Drei Saetze bis zur Abschlussentscheidung, alles Geschriebene im Erfasser.
    private func bisZumAbschluss(_ erfasser: Erfassungswarteschlange) async -> GeraetModel {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: { erfasser.geschriebene.append($0) },
                         satzZiel: 3)
        for _ in 1...3 {
            await sut.satzSichern(problemFlag: false, problemReason: nil)
            if sut.phase != .abschluss { sut.pauseBeenden() }
        }
        return sut
    }

    @Test func reserveSchicktLetztenSatzMitRirErneut() async {
        let erfasser = Erfassungswarteschlange()
        let sut = await bisZumAbschluss(erfasser)
        #expect(sut.phase == .abschluss)
        #expect(sut.zeigtReserveFrage)
        let dritter = try! #require(erfasser.geschriebene.last)

        sut.reserveSetzen(.wert(2))

        #expect(erfasser.geschriebene.count == 4)
        let neu = try! #require(erfasser.geschriebene.last)
        #expect(neu.setId == dritter.setId)
        #expect(neu.sessionId == dritter.sessionId)
        #expect(neu.body.rir == 2)
        var ohneRir = neu.body
        ohneRir.rir = nil
        #expect(ohneRir == dritter.body)
        #expect(sut.reserve == .wert(2))
    }

    @Test func fuenfPlusWirdFuenf() async {
        let erfasser = Erfassungswarteschlange()
        let sut = await bisZumAbschluss(erfasser)

        sut.reserveSetzen(.wert(5))

        #expect(erfasser.geschriebene.last?.body.rir == 5)
    }

    @Test func unbekanntNachZahlSetztNull() async {
        let erfasser = Erfassungswarteschlange()
        let sut = await bisZumAbschluss(erfasser)

        sut.reserveSetzen(.unbekannt)
        #expect(erfasser.geschriebene.count == 3)

        sut.reserveSetzen(.wert(3))
        sut.reserveSetzen(.unbekannt)

        #expect(erfasser.geschriebene.count == 5)
        #expect(erfasser.geschriebene.last?.body.rir == nil)
    }

    @Test func gleicheAntwortSchicktNichtsErneut() async {
        let erfasser = Erfassungswarteschlange()
        let sut = await bisZumAbschluss(erfasser)

        sut.reserveSetzen(.wert(2))
        sut.reserveSetzen(.wert(2))

        #expect(erfasser.geschriebene.count == 4)
    }

    @Test func reserveWirdBeiNeuemSatzZurueckgesetzt() async {
        let erfasser = Erfassungswarteschlange()
        let sut = await bisZumAbschluss(erfasser)
        sut.reserveSetzen(.wert(2))

        sut.weitererSatz()
        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.reserve == nil)
    }

    @Test func vorDemSatzzielKeineReserveFrage() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(!sut.zeigtReserveFrage)
    }

    /// Sicherheitsnetz unter Ortswechsel: ein Geraet aus s1 in einer Einheit
    /// in s2 wuerde der Server sicher abweisen -- es wird nicht geschrieben,
    /// und der Screen sagt, warum.
    @Test func einGeraetAusEinemAnderenStudioSchreibtNichtInDieEinheit() async {
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let vorher = sessions.aktiveSession()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) })

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(erfasser.geschriebene.isEmpty)
        #expect(sessions.aktiveSession() == vorher)
        #expect(sut.gesicherteSaetze == 0)
        #expect(sut.phase == .eingabe)
        #expect(sut.satzAbgelehnt != nil)
    }

    @Test func einGeraetImStudioDerEinheitSchreibtOhneHinweis() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.gesicherteSaetze == 1)
        #expect(sut.satzAbgelehnt == nil)
    }

    // MARK: - Zirkel (Spec Mini-Zirkel 21.10.)

    /// Im Zirkel entscheidet die Zirkel-Ebene, was nach dem Satz kommt --
    /// die Pause der Uebung oder die Abschlussfrage waeren dort falsch.
    @Test func imZirkelRuftSichernDenHookStattPauseOderAbschluss() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 1)
        var aufrufe = 0
        sut.beiZirkelSatzGesichert = { aufrufe += 1 }

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(aufrufe == 1)
        #expect(sut.phase == .eingabe)
        #expect(sut.gesicherteSaetze == 1)
    }

    /// Review Focus: ein abgelehnter Satz darf den Zirkel nicht weiterruecken.
    @Test func einAbgelehnterSatzRuftDenHookNicht() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions)
        var aufrufe = 0
        sut.beiZirkelSatzGesichert = { aufrufe += 1 }

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.satzAbgelehnt != nil)
        #expect(aufrufe == 0)
    }

    @Test func ohneHookBleibtDasVerhaltenUnveraendert() async {
        let mitPause = modell(maschine: GeraetTestdaten.maschine,
                              bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                              satzZiel: 3)
        await mitPause.satzSichern(problemFlag: false, problemReason: nil)
        #expect(mitPause.laufendePause != nil)

        let amZiel = modell(maschine: GeraetTestdaten.maschine,
                            bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                            satzZiel: 1)
        await amZiel.satzSichern(problemFlag: false, problemReason: nil)
        #expect(amZiel.phase == .abschluss)
    }

    /// Runde 2+: kein Drawer, kein Countdown -- gleich die Raeder, und der
    /// Mitschnitt beginnt sofort, nicht erst nach einem Countdown, der nie
    /// endet.
    @Test func startOhneCountdownGehtGleichInDieEingabe() {
        let mitschnitt = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         mitschnitt: mitschnitt)

        sut.uebungStarten(mit: Startwerte(belastung: 40, umfang: 12, nebenbelastung: nil),
                          mitCountdown: false)

        #expect(sut.phase == .eingabe)
        #expect(sut.belastung == 40)
        #expect(sut.umfang == 12)
        #expect(mitschnitt.eingaben == 1)
    }

    /// Der Zirkel in Runde 1: Startwerte aus dem Drawer, aber kein Countdown.
    /// Das Modell entsteht im ViewBuilder von TrainingRootView.ziel(_:) und
    /// wird dort bei jedem Neuaufbau neu gebaut und verworfen (der Screen
    /// haelt nur das erste ueber @State). Ein Mitschnitt aus init heraus
    /// haengte den app-weiten Zaehler an ein verworfenes Modell -- erst das
    /// Erscheinen des Screens (geraetGeoeffnet) startet ihn.
    @Test func startwerteOhneCountdownImInitStartenKeinenMitschnitt() {
        let mitschnitt = MitschnittSpion()
        let sut = GeraetModel(
            station: Station(maschine: GeraetTestdaten.maschine), uebungId: "e1", token: nil,
            bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            enqueue: { _ in }, mitschnitt: mitschnitt,
            startwerte: Startwerte(belastung: 40, umfang: 12, nebenbelastung: nil),
            mitCountdown: false)

        #expect(sut.phase == .eingabe)
        #expect(sut.belastung == 40)
        #expect(sut.umfang == 12)
        #expect(mitschnitt.eingaben == 0)

        sut.geraetGeoeffnet()
        #expect(mitschnitt.eingaben == 1)
    }

    @Test func imZirkelFolgtDemHook() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(!sut.imZirkel)
        sut.beiZirkelSatzGesichert = {}
        #expect(sut.imZirkel)
    }

    /// Fix-Runde 1 (Important 2): im Zirkel bleibt die Phase .eingabe, der
    /// Knopf steht also noch da, waehrend die Pause hereinschiebt. Ein
    /// zweiter Tipp darf keinen Phantomsatz schreiben, den der Zirkel nicht
    /// zaehlt.
    @Test func imZirkelSperrtDerGesicherteSatzEinenZweiten() async {
        var eingereiht = 0
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: { _ in eingereiht += 1 })
        var aufrufe = 0
        sut.beiZirkelSatzGesichert = { aufrufe += 1 }
        #expect(sut.kannSichern)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(aufrufe == 1)
        #expect(sut.gesicherteSaetze == 1)
        #expect(eingereiht == 1)
        #expect(!sut.kannSichern)
        // Kein Ablehnungstext: die Sperre ist kein Fehler des Mitglieds.
        #expect(sut.satzAbgelehnt == nil)
    }

    @Test func ohneZirkelBleibtSichernNachEinemSatzMoeglich() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        #expect(sut.kannSichern)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.gesicherteSaetze == 2)
    }

    /// Fix-Runde 1 (Important 1): aus dem Problem-Sheet heraus wartet die
    /// Meldung an den Zirkel, bis das Sheet zu ist -- ein Push waehrend der
    /// Sheet-Animation verwirft UIKit, und dann waere der Zirkel weiter als
    /// der Screen.
    @Test func eineAufgeschobeneZirkelMeldungKommtErstBeimNachholen() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        var aufrufe = 0
        sut.beiZirkelSatzGesichert = { aufrufe += 1 }
        sut.zirkelMeldungAufschieben = true

        await sut.satzSichern(problemFlag: true, problemReason: ProblemReason.allCases.first)
        #expect(sut.gesicherteSaetze == 1)
        #expect(aufrufe == 0)

        sut.zirkelMeldungNachholen()
        #expect(aufrufe == 1)
        sut.zirkelMeldungNachholen()
        #expect(aufrufe == 1)
    }

    /// Sheet ohne Satz geschlossen: nichts zu melden, und der naechste Satz
    /// geht wieder sofort an den Zirkel.
    @Test func nachholenOhneSatzMeldetNichtsUndHebtDasAufschiebenAuf() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        var aufrufe = 0
        sut.beiZirkelSatzGesichert = { aufrufe += 1 }
        sut.zirkelMeldungAufschieben = true

        sut.zirkelMeldungNachholen()
        #expect(aufrufe == 0)
        #expect(!sut.zirkelMeldungAufschieben)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(aufrufe == 1)
    }

    /// Runde 2 entsteht als neues Modell derselben Station und Uebung ohne
    /// Startwerte. Das Gewicht muss aus dem Satz der Vorrunde kommen, nicht
    /// aus dem Bootstrap -- der kennt die laufende Einheit nicht.
    @Test func dasGewichtDerVorrundeIstInRunde2Vorbelegt() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        // Schrittweite 1 kg, damit 14 auf dem Raster liegt.
        let kurzhantel: BootstrapResponse.Machine = GeraetTestdaten.dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Kurzhantel","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":1,"loadMin":1.0,"loadMax":50.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Bizepscurl","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
        // Das letzte Training vor Wochen: 10 kg x 12 -- darf nicht gewinnen.
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 10, 12)])
        let runde1 = modell(maschine: kurzhantel, bootstrap: bootstrap, sessions: sessions)
        runde1.belastungGewaehlt(14)
        runde1.umfangGedreht(9)
        await runde1.satzSichern(problemFlag: false, problemReason: nil)

        let runde2 = modell(maschine: kurzhantel, bootstrap: bootstrap, sessions: sessions)

        #expect(runde2.belastung == 14)
        #expect(runde2.umfang == 9)
        // GeraetView laedt den Kontext auch in Runde 2: sein Vorschlag
        // rechnet aus der Historie und darf die Vorrunde nicht ersetzen.
        runde2.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 90.0))
        #expect(runde2.belastung == 14)
    }

    /// Der Rueckkehr-Fall ohne Zirkel (Kommentar im init): ueber die
    /// Blockliste zurueck an ein Geraet, nachdem dazwischen ein anderes
    /// lief. Es zaehlt der heutige Satz DIESES Geraets -- weder der des
    /// Geraets dazwischen noch der aus dem Bootstrap.
    @Test func nachDerRueckkehrUeberDieBlocklisteGiltDerHeutigeSatzDesGeraets() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        func kurzhantel(_ id: String) -> BootstrapResponse.Machine {
            GeraetTestdaten.dekodiere("""
            {"id":"\(id)","studioId":"s1","label":"Gerät \(id)","locationNote":null,
             "status":"active","tokenHashes":[],"visitCount":2,
             "equipmentModel":{"id":"em1","name":"Kurzhantel","manufacturer":null,
               "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":1,"loadMin":1.0,"loadMax":50.0,
               "settingDefinitions":[]},
             "exercises":[{"id":"e1","name":"Bizepscurl","volumeKind":"reps","targetMin":8,"targetMax":12}]}
            """)
        }
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 10, 12), ("m2", "e1", 30, 8)])
        let hin = modell(maschine: kurzhantel("m1"), bootstrap: bootstrap, sessions: sessions)
        hin.belastungGewaehlt(14)
        hin.umfangGedreht(9)
        await hin.satzSichern(problemFlag: false, problemReason: nil)

        let dazwischen = modell(maschine: kurzhantel("m2"), bootstrap: bootstrap, sessions: sessions)
        // Am anderen Geraet zaehlt dessen Bootstrap, nicht der Satz an m1.
        #expect(dazwischen.belastung == 30)
        dazwischen.belastungGewaehlt(40)
        await dazwischen.satzSichern(problemFlag: false, problemReason: nil)

        let zurueck = modell(maschine: kurzhantel("m1"), bootstrap: bootstrap, sessions: sessions)
        #expect(zurueck.belastung == 14)
        #expect(zurueck.umfang == 9)
    }

    // MARK: - Start aus dem Drawer (Testnotiz 11.10., #10, #11)

    @Test func mitStartwertenBeginntDieSatzseiteMitDemCountdown() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         startwerte: Startwerte(belastung: 82.5, umfang: 8, nebenbelastung: nil))

        guard case .bereit = sut.phase else {
            Issue.record("Erwartet .bereit, war \(sut.phase)")
            return
        }
        // Die Werte aus dem Drawer, nicht die vom letzten Mal.
        #expect(sut.belastung == 82.5)
        #expect(sut.umfang == 8)
    }

    @Test func nachDemCountdownStehenDieRaeder() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         startwerte: Startwerte(belastung: 10, umfang: 10, nebenbelastung: nil))

        sut.countdownBeenden()

        #expect(sut.phase == .eingabe)
    }

    /// Ein spaet eintreffender Vorschlag ueberschreibt nicht, was im Drawer
    /// gewaehlt wurde.
    @Test func startwerteGeltenAlsVomMitgliedGewaehlt() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         startwerte: Startwerte(belastung: 82.5, umfang: 8, nebenbelastung: nil))

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 90.0))

        #expect(sut.belastung == 82.5)
    }

    /// Zirkel ueber die Blockliste: ohne Drawer, ohne Countdown, gleich die
    /// Raeder.
    @Test func ohneStartwerteBeginntDieSatzseiteBeiDenRaedern() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.phase == .eingabe)
    }

    /// "Weitere Übung an dem Gerät" fuehrt durch denselben Drawer wie die
    /// Liste (Testnotiz 13.10., #3): seine Startwerte gelten, der Countdown
    /// laeuft, und ein spaeter Vorschlag ersetzt sie nicht.
    @Test func nachDemWechselStartetDerDrawerMitCountdown() {
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        sut.uebungWechseln(zu: "e2")

        sut.uebungStarten(mit: Startwerte(belastung: 40, umfang: 12, nebenbelastung: nil))

        guard case .bereit = sut.phase else {
            Issue.record("Erwartet .bereit, war \(sut.phase)")
            return
        }
        #expect(sut.uebungId == "e2")
        #expect(sut.belastung == 40)
        #expect(sut.umfang == 12)
        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))
        #expect(sut.belastung == 40)
    }

    @Test func startwerteAusDemModellUebernehmenDieRaeder() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]))
        sut.belastungGewaehlt(80)
        #expect(sut.startwerte == Startwerte(belastung: 80, umfang: 11, nebenbelastung: nil))
    }

    // MARK: - Gewicht in der Pause (Testnotiz 11.10., #12)

    /// Charakterisierung: belastungGewaehlt tut in der Pause schon das
    /// Richtige -- der Drawer "Gewicht" ruft genau das auf. Die Pause laeuft
    /// weiter, und der naechste Satz traegt das neue Gewicht.
    @Test func einInDerPauseGewaehltesGewichtGiltFuerDenNaechstenSatz() async {
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) },
                         satzZiel: 3)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)

        sut.belastungGewaehlt(82.5)
        #expect(sut.laufendePause != nil)

        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(erfasser.geschriebene.last?.body.load == 82.5)
    }

    // MARK: - Phasen

    @Test func vorDemLetztenGeplantenSatzStartetDiePause() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)
        #expect(sut.phase != .abschluss)

        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)
    }

    @Test func nachDemLetztenGeplantenSatzKommtKeinePauseSondernDieEntscheidung() async {
        // Eine Pause vor einem Satz, der nicht mehr kommt, ist nur
        // Wartezeit -- an ihrer Stelle steht die Frage "noch einer, oder
        // fertig hier?".
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions,
                         satzZiel: 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        #expect(sut.satzNummer == 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.phase == .abschluss)
        #expect(sut.laufendePause == nil)
    }

    @Test func weitererSatzStartetEineNeuePause() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.phase == .abschluss)

        sut.weitererSatz()
        #expect(sut.laufendePause != nil)
    }

    @Test func pauseBeendenSchaltetZurueckAufDieEingabe() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()

        #expect(sut.phase == .eingabe)
        #expect(sut.laufendePause == nil)
    }

    @Test func verlaengernSchiebtNurDasEndeUndNurInDerPause() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)

        // Ausserhalb der Pause ist "+30 s" wirkungslos statt zustandsbildend.
        sut.pauseVerlaengern()
        #expect(sut.phase == .eingabe)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        let vorher = sut.laufendePause
        sut.pauseVerlaengern()

        #expect(sut.laufendePause?.start == vorher?.start)
        #expect(sut.laufendePause?.endetAm == vorher?.endetAm.addingTimeInterval(30))
    }

    @Test func uebungWechselnSetztDiePhaseZurueck() async {
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.phase == .abschluss)

        // e2 hat eigene Saetze und ein eigenes Ziel -- die Entscheidung von
        // e1 gilt dort nicht.
        sut.uebungWechseln(zu: "e2")
        #expect(sut.phase == .eingabe)
    }

    @Test func satzSichernSchreibtKeineReserveMehr() async {
        let erfasser = Erfassungswarteschlange()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: { erfasser.geschriebene.append($0) })

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(erfasser.geschriebene.first?.body.rir == nil)
    }

    @Test func gesicherteSaetzeSteigtNurBeimSichernNichtBeimUebungswechsel() async {
        // Review-Fund Task 9: satzNummer ist die Satznummer der GERADE
        // ANGEZEIGTEN Uebung. Hat die Zielübung schon mehr gesicherte
        // Saetze als die aktuelle, springt satzNummer beim blossen
        // uebungWechseln(zu:) nach oben, ohne dass ein Satz gesichert
        // wurde -- ein an satzNummer haengender Haptik-Trigger feuerte
        // dann bei einer Navigation. gesicherteSaetze darf das nicht.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        // e2 hat schon zwei gesicherte Saetze -- mehr, als e1 unten nach
        // dem einen gesicherten Satz haben wird.
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions)
        #expect(sut.gesicherteSaetze == 0)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.gesicherteSaetze == 1)
        #expect(sut.satzNummer == 2)

        sut.uebungWechseln(zu: "e2")
        // satzNummer springt (e2 hatte schon zwei Saetze) -- das ist der
        // Fehler, den der alte Trigger nicht kannte. gesicherteSaetze
        // bleibt unberuehrt.
        #expect(sut.satzNummer == 3)
        #expect(sut.gesicherteSaetze == 1)

        sut.uebungWechseln(zu: "e1")
        #expect(sut.gesicherteSaetze == 1)
    }

    @Test func verwirftKalibrierungUndVorschlagDerVorherigenUebungBeimWechsel() {
        // tag-context.ts berechnet calibration und suggestion serverseitig
        // fuer genau eine Uebung (selectedExerciseId). Nach einem Wechsel
        // muessen Einstellwerte wieder aus bootstrap fuer die NEUE Uebung
        // kommen und der Vorschlag verschwinden -- sonst zeigt der Screen
        // die Sitzposition der vorherigen Uebung unter dem falschen Namen,
        // und das Mitglied stellt das Geraet physisch falsch ein.
        let bootstrap = GeraetTestdaten.bootstrap(
            lastSets: [], mitKalibrierung: true,
            kalibrierungExerciseId: "e2", kalibrierungSitzWert: 6
        )
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0, kalibrierungSitzWert: 4))
        #expect(sut.einstellwerte.first?.anzeige == "4")
        #expect(sut.vorschlagText != nil)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.vorschlagText == nil)
        #expect(sut.einstellwerte.first?.anzeige == "6")
    }

    @Test func kalibrierungVorbereitenLiestDurchDenselbenUebungsgateWieKalibrierungswerte() {
        // Dieselbe Klammer wie kalibrierungswerte: der Entwurf muss aus der
        // Kalibrierung der AKTUELLEN Uebung entstehen, nicht aus e1, auch
        // wenn der geladene Kontext (falls vorhanden) noch zu e1 gehoert.
        let bootstrap = GeraetTestdaten.bootstrap(
            lastSets: [], mitKalibrierung: true,
            kalibrierungExerciseId: "e2", kalibrierungSitzWert: 6
        )
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap)
        sut.uebungWechseln(zu: "e2")

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfEinstellung["sitz"] == 6)
        #expect(sut.kalibrierungFehler == nil)
    }

    @Test func kalibrierungVorbereitenFaelltOhneVorherigeWerteAufsMinimum() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfEinstellung["sitz"] == 1)
    }

    @Test func kalibrierungSichernSpeichertUndSchliesst() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.success(RecordedCalibration(
            id: "c1", machineId: "m1", exerciseId: "e1",
            settingValues: .number(4), schemaVersion: 1, source: "self",
            createdAt: "2026-09-01T10:00:00Z"
        )))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungOeffnen()
        sut.entwurfEinstellung = ["sitz": 4]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == true)
        #expect(sut.kalibrierungFehler == nil)
        #expect(sut.kalibrierungOffen == false)
    }

    @Test func kalibrierungSichernZeigtDenServertextWoertlichUndSchliesstNicht() async {
        // Der Text kommt vom Server -- nur er kennt die Grenzen des
        // Geraetemodells. Er wird hier NICHT umformuliert.
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.failure(.validation(message: "Sitz darf höchstens 8 sein.")))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungOeffnen()
        sut.entwurfEinstellung = ["sitz": 99]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == false)
        #expect(sut.kalibrierungFehler == "Sitz darf höchstens 8 sein.")
        #expect(sut.kalibrierungOffen == true)
    }

    // MARK: - Auswahl-Einstellungen (Testnotiz 06.10., #17)

    @Test func kalibrierungVorbereitenBelegtEineAuswahlMitDemErstenErlaubtenWert() {
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfAuswahl["griff"] == "eng")
        // Eine Auswahl ist keine Zahl -- sie darf im Zahlenentwurf nicht
        // auftauchen, sonst ginge sie als 0 an den Server.
        #expect(sut.entwurfEinstellung["griff"] == nil)
        #expect(sut.entwurfEinstellung["hoehe"] == 1)
        #expect(sut.entwurfEinstellung["sitz"] == 1)
    }

    @Test func kalibrierungVorbereitenUebernimmtDieBisherigeAuswahl() {
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrapMitAuswahl(griff: "weit"))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfAuswahl["griff"] == "weit")
        #expect(sut.entwurfEinstellung["hoehe"] == 7)
        #expect(sut.entwurfEinstellung["sitz"] == 3)
    }

    @Test func kalibrierungVorbereitenVerwirftEineNichtMehrErlaubteAuswahl() {
        // Das Studio hat die Werteliste seither geaendert -- ein alter Wert
        // ausserhalb der Liste wuerde am Server abgewiesen.
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrapMitAuswahl(griff: "breit"))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfAuswahl["griff"] == "eng")
    }

    @Test func kalibrierungSichernSendetEineAuswahlAlsText() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.success(RecordedCalibration(
            id: "c1", machineId: "m1", exerciseId: "e1",
            settingValues: .null, schemaVersion: 1, source: "self",
            createdAt: "2026-10-06T10:00:00Z"
        )))
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungVorbereiten()
        sut.entwurfAuswahl["griff"] = "neutral"
        sut.entwurfEinstellung["hoehe"] = 12

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == true)
        let gesendet = await loader.kalibrierungen.last?.settingValues
        #expect(gesendet == ["hoehe": .number(12), "griff": .string("neutral"), "sitz": .number(1)])
    }

    // MARK: - Uebung abschliessen (Testnotiz 06.10., #12)

    @Test func uebungAbschliessenFragtNurBeiMehrerenUebungenNach() {
        // Antwort auf die Rueckfrage: der Drawer "Weitere Uebung / Geraet
        // abschliessen" kommt immer, sobald das Geraet mehr als eine Uebung
        // hat -- auch wenn alle schon dran waren.
        let eine = modell(maschine: GeraetTestdaten.maschine,
                          bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(eine.abschlussFragtNach == false)
        let zwei = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                          bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(zwei.abschlussFragtNach == true)
    }

    // MARK: - Offener Satz vor dem Abschluss (Testnotiz 12.10. abends, #5)

    /// Nur unter den Raedern steht ein Satz offen. In der Pause und nach
    /// dem Satzziel ist der letzte schon gesichert, im Countdown hat noch
    /// keiner begonnen.
    @Test func nurDieEingabeFragtVorDemAbschlussNachDemSatz() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.abschlussFragtNachSatz == true)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.abschlussFragtNachSatz == false)

        let imCountdown = modell(maschine: GeraetTestdaten.maschine,
                                 bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                                 startwerte: Startwerte(belastung: 20, umfang: 10, nebenbelastung: nil))
        #expect(imCountdown.abschlussFragtNachSatz == false)
    }

    /// "Satz speichern" sichert wie der Hauptknopf und sagt, ob es geklappt
    /// hat -- nur dann geht es weiter aus der Uebung heraus.
    @Test func satzSpeichernVorDemAbschlussMeldetDenErfolg() async {
        let erfasser = Erfassungswarteschlange()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: { erfasser.geschriebene.append($0) })

        #expect(await sut.satzSichernVorAbschluss() == true)
        #expect(erfasser.geschriebene.count == 1)
        #expect(sut.gesicherteSaetze == 1)
    }

    @Test func einAbgelehnterSatzHaeltDenAbschlussAuf() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions)

        #expect(await sut.satzSichernVorAbschluss() == false)
        #expect(sut.satzAbgelehnt != nil)
    }

    @Test func blockInEinheitNenntDieSaetzeJederUebungDiesesGeraets() {
        // Die Uebungsliste zeigt bei schon gemachten Uebungen die Saetze der
        // laufenden Einheit, wie die Blockliste im Training-Tab.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), sessions: sessions)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 42.5, volume: 9,
                                  problemFlag: false, problemReason: nil)
        // Derselbe Uebungs-Schluessel an einem anderen Geraet zaehlt nicht.
        _ = sessions.satzSichern(station: .testGeraet("m2"), exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 20, volume: 12,
                                  problemFlag: false, problemReason: nil)

        #expect(sut.blockInEinheit(fuer: "e1")?.saetze.count == 2)
        #expect(sut.blockInEinheit(fuer: "e2") == nil)
    }

    /// Testnotiz 14.10., 18:25: was in diesem Training am Geraet schon dran
    /// war, steht in der Uebungsliste oben -- hier e2 vor e1, obwohl das
    /// Studio e1 zuerst fuehrt.
    @Test func sortierteUebungenBeginnenMitDenenDiesesTrainings() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), sessions: sessions)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 20, volume: 12,
                                  problemFlag: false, problemReason: nil)

        #expect(sut.sortierteUebungen.map(\.id) == ["e2", "e1"])
    }

    @Test func erstkontaktLaeuftGenauEinmalJeGeraetUndUebung() {
        // "Der Dreischritt laeuft genau einmal je Geraet und Uebung" --
        // erstkontaktAbschliessen() ist die einzige Stelle, die istErstkontakt
        // fuer die AKTUELLE Uebung nach einem abgeschlossenen Dreischritt
        // korrigiert (Task 16, Step 3 der Aufgabe).
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.istErstkontakt == true)

        sut.erstkontaktAbschliessen()

        #expect(sut.istErstkontakt == false)

        // Der Fluchtweg (Schliessen des Uebungsstart-Drawers) ruft
        // erstkontaktAbschliessen() NIE auf -- sonst zeigte istErstkontakt beim naechsten Scan
        // faelschlich "erledigt", obwohl das Mitglied den Dreischritt nie zu
        // Ende gebracht hat. Ein frisches Modell im selben Ausgangszustand,
        // ohne den Aufruf, steht dafuer: istErstkontakt bleibt wahr.
        let abgebrochen = modell(maschine: GeraetTestdaten.maschine,
                                 bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(abgebrochen.istErstkontakt == true)
    }

    @Test func istErstkontaktBleibtNachRueckkehrZumGeraetFalschTrotzStalemBootstrap() {
        // Der Zirkelfall aus M1-Spec SS5.3 (Schlusswellen-Fund C2, Faelle 1):
        // Dreischritt an Maschine 7 abgeschlossen, Saetze gemacht, zu einem
        // anderen Geraet gewechselt und ueber die Blockliste zurueck --
        // TrainingRootView.modell(...) baut dabei ein FRISCHES GeraetModel.
        // bootstrap bleibt dabei die alte Momentaufnahme ohne Kalibrierung
        // und ohne lastSet; nur die lokale Session weiss vom Satz.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])

        let erstesModell = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap, sessions: sessions)
        #expect(erstesModell.istErstkontakt == true)
        erstesModell.erstkontaktAbschliessen()
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)

        // Ein neuer Push: dieselbe sessions-Instanz, aber ein komplett neues
        // GeraetModel -- erledigt der ersten Instanz ist damit weg, nur
        // sessions kennt noch den Satz.
        let zweitesModell = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap, sessions: sessions)
        #expect(zweitesModell.istErstkontakt == false)
    }

    @Test func istErstkontaktGiltFuerEineNieBenutzteUebungAuchNachDemWechsel() {
        // Faelle 2 desselben Funds: uebungWechseln(zu:) darf den Dreischritt
        // einer noch nie benutzten Uebung nicht ueberspringen, nur weil eine
        // ANDERE Uebung am selben Geraet ihn schon hinter sich hat.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap, sessions: sessions)
        #expect(sut.istErstkontakt == true)

        sut.erstkontaktAbschliessen()
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        #expect(sut.istErstkontakt == false)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.istErstkontakt == true)
    }

    @Test func kalibrierungSichernZeigtEinenEigenenTextOffline() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.failure(.offline))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.entwurfEinstellung = ["sitz": 4]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == false)
        #expect(sut.kalibrierungFehler?.contains("Ohne Empfang") == true)
    }

    // MARK: - Rueckblick (Sammelstelle Punkt 11)

    @Test func rueckblickTraegtDenLetztenSatzUndSpaeterDenVorschlag() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
        // Offline gibt es nur den letzten Satz; der Vorschlag kommt mit dem Kontext.
        #expect(sut.rueckblick == Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: nil))

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.rueckblick == Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: "Vorschlag · +2,5 kg"))
    }

    @Test func beimErstenMalAmGeraetGibtEsKeinenRueckblick() {
        // Ohne letzten Satz und ohne Vorschlag haette der Drawer nichts zu
        // sagen -- er kommt gar nicht (Sammelstelle Punkt 11).
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.rueckblick == nil)
    }

    @Test func rueckblickGehoertZurAngezeigtenUebung() {
        // Derselbe Uebungs-Vorbehalt wie bei kalibrierungswerte: der letzte Satz
        // von e2 sagt nichts ueber e1.
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e2", 40, 10)]))
        #expect(sut.rueckblick == nil)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.rueckblick?.zuletzt == "40,0 kg × 10")
    }

    // MARK: - Markierungen im Wiederholungsrad

    @Test func umfangsradMarkiertDenLetztenWertUndDieZielspanne() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]))

        #expect(sut.letzterUmfang == 11)
        #expect(sut.zielspanne == 8...12)
    }

    @Test func beimErstenMalGibtEsKeinenLetztenUmfang() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.letzterUmfang == nil)
    }

    // MARK: - Belastung und Umfang in der Einheit des Geraets (Cardio Schnitt 3)

    @Test func dieBeinpresseNenntSchrittBereichUndZielWieBisher() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.loadUnit == .kg)
        #expect(sut.volumeKind == .reps)
        #expect(sut.secondaryUnit == nil)
        #expect(sut.nebenbelastung == nil)
        #expect(sut.kontextzeileBelastung == "Schritt 2,5 kg · 5,0 – 150,0")
        #expect(sut.kontextzeileUmfang == "Ziel 8 – 12")
        #expect(sut.umfangsWerte == Array(1...40))
        #expect(sut.umfang == 8)

        let ohneGrenze = modell(maschine: GeraetTestdaten.maschineOhneMaximum,
                                bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(ohneGrenze.kontextzeileBelastung == "Schritt 2,5 kg · ab 5,0")
    }

    @Test func dasLaufbandLiestEinheitUndUmfangsartVomModell() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.loadUnit == .kmh)
        #expect(sut.secondaryUnit == .pct)
        #expect(sut.volumeKind == .seconds)
        #expect(sut.kontextzeileBelastung == "Schritt 0,5 km/h · 0,0 – 20,0")
        #expect(sut.kontextzeileUmfang == "Ziel 15 – 20 min")
        #expect(sut.umfangsWerte == Rastwerte.umfang(.seconds))
        #expect(sut.belastungsWerte.count == 41)
        #expect(sut.nebenbelastungsWerte.count == 31)
        // Ohne Historie: Belastung am Geraeteminimum, Umfang am unteren
        // Korridorende -- dieselbe Regel wie an der Beinpresse.
        #expect(sut.belastung == 0)
        #expect(sut.umfang == 900)
    }

    @Test func eineStufenanzeigeSchreibtDieEinheitHinterDieSchrittweite() {
        // "Schritt Level 1" laese sich wie die Stufe 1, nicht wie eine
        // Aenderung um eine Stufe.
        let sut = modell(maschine: GeraetTestdaten.ergometerMitStufen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.kontextzeileBelastung == "Schritt 1 Level · 1 – 20")
        #expect(sut.kontextzeileUmfang == "Ziel 20 – 30 min")
        #expect(sut.secondaryUnit == .rpm)
        #expect(sut.nebenbelastung == 50)
    }

    @Test func dieNebenbelastungStartetOhneHistorieAmMinimum() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.nebenbelastung == 0)
    }

    @Test func dieNebenbelastungIstVomLetztenSatzVorbelegt() {
        // Cardio-Spec 3.1b: im Normalfall bleibt die Neigung gleich, und
        // das Mitglied fasst den Regler nicht an.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]))

        #expect(sut.belastung == 8.5)
        #expect(sut.nebenbelastung == 6)
        #expect(sut.umfang == 1200)
        #expect(sut.rueckblick?.zuletzt == "8,5 km/h · 6,0 % × 20:00 min")
    }

    @Test func einUmfangAbseitsDerRasterRastetAufDieListe() {
        // Ein Satz aus einer anderen Quelle (Portal, spaetere Fassung) kann
        // 1195 Sekunden tragen; RastRad verlangt ein Element der Liste.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.4, 6.2, 1195)]))

        #expect(sut.umfang == 1200)
        #expect(sut.belastung == 8.5)
        #expect(sut.nebenbelastung == 6)
    }

    @Test func derVorschlagUebernimmtBelastungUndNebenbelastung() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 4, 1200)]))

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: 9, bisher: 8.5, neben: 6))

        #expect(sut.belastung == 9)
        #expect(sut.nebenbelastung == 6)
        #expect(sut.vorschlagText == "Vorschlag · +0,5 km/h")
    }

    @Test func eineSelbstGesetzteNebenbelastungBleibtBeimVorschlag() {
        // Dieselbe ...VomNutzer-Regel wie bei der Belastung, aber getrennt
        // gefuehrt: wer nur die Neigung anfasst, bekommt den
        // Tempo-Vorschlag trotzdem.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 4, 1200)]))
        sut.nebenbelastungGewaehlt(2)

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: 9, bisher: 8.5, neben: 6))

        #expect(sut.nebenbelastung == 2)
        #expect(sut.belastung == 9)
    }

    @Test func eineSelbstGesetzteBelastungLaesstDieNebenbelastungDemVorschlag() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 4, 1200)]))
        sut.belastungGewaehlt(7)

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: 9, bisher: 8.5, neben: 6))

        #expect(sut.belastung == 7)
        #expect(sut.nebenbelastung == 6)
    }

    @Test func dieNebenbelastungRastetAufDieStufenDesGeraets() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.nebenbelastungGewaehlt(6.3)
        #expect(sut.nebenbelastung == 6.5)
        sut.nebenbelastungGewaehlt(99)
        #expect(sut.nebenbelastung == 15)
    }

    @Test func anEinemKraftgeraetBleibtDieNebenbelastungNil() {
        // Ein gesetzter Wert liesse den Server den Satz abweisen.
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.nebenbelastungGewaehlt(6)
        #expect(sut.nebenbelastung == nil)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))
        #expect(sut.nebenbelastung == nil)
    }

    @Test func derSatzTraegtDieNebenbelastungGenauWennDasModellEineHat() async {
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) })

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        let body = erfasser.geschriebene.first?.body
        #expect(body?.load == 8.5)
        #expect(body?.secondaryLoad == 6)
        #expect(body?.volume == 1200)
        let block = sessions.aktiveSession()?.bloecke.first
        #expect(block?.einheiten == Blockeinheiten(loadUnit: .kmh, secondaryUnit: .pct, volumeKind: .seconds))
        #expect(block?.saetze.first?.secondaryLoad == 6)
    }

    @Test func derKontextKannEineNebenbelastungBringenDieDerPrefetchNichtKannte() {
        // Das Studio hat dem Modell seit dem letzten Prefetch eine
        // Nebenbelastung eingetragen. Ohne Abgleich bliebe sie nil, und der
        // Server wiese den Satz ab.
        let sut = modell(maschine: GeraetTestdaten.laufbandOhneNeigung,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.nebenbelastung == nil)

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: nil, bisher: nil, neben: nil))

        #expect(sut.secondaryUnit == .pct)
        #expect(sut.nebenbelastung == 0)
    }

    // MARK: - Satzziel bei Zeit und Strecke (Task 6)

    @Test func amLaufbandIstNachDemErstenSatzDieEntscheidungDran() async {
        // Ein Satz ist bei Zeit und Strecke die Einheit: keine Pause vor
        // einem zweiten Dauerlauf, auch wenn das Profil drei Saetze plant.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        #expect(sut.satzZiel == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.phase == .abschluss)
        #expect(sut.laufendePause == nil)
    }

    @Test func einWeitererSatzAmLaufbandBekommtSeinePause() async {
        // Wer trotzdem weitermacht (Intervalle), bekommt die Pause wie
        // jeder Zusatzsatz -- die Regel aendert nur, wann gefragt wird.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        await sut.satzSichern(problemFlag: false, problemReason: nil)

        sut.weitererSatz()

        #expect(sut.laufendePause != nil)
    }

    @Test func auchMeterUebungenHabenEinenSatz() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 4)
        sut.uebungWechseln(zu: "e10")

        #expect(sut.volumeKind == .meters)
        #expect(sut.satzZiel == 1)
    }

    @Test func dieBeinpresseFolgtWeiterDemProfil() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        #expect(sut.satzZiel == 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.phase != .abschluss)
        #expect(sut.laufendePause != nil)
    }

    @Test func derUebungswechselRastetDenUmfangAufDieNeueUmfangsart() {
        // Vom Dauerlauf (Sekunden) auf das Intervall (Meter): die Liste
        // wechselt, und der Startwert ist das untere Korridorende der neuen
        // Uebung.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]))
        #expect(sut.umfang == 1200)

        sut.uebungWechseln(zu: "e10")

        #expect(sut.volumeKind == .meters)
        #expect(sut.umfangsWerte == Rastwerte.umfang(.meters))
        #expect(sut.umfang == 2000)
        #expect(sut.kontextzeileUmfang == "Ziel 2.000 – 5.000 m")
        // Fuer die neue Uebung gibt es keinen letzten Satz: die
        // Nebenbelastung faellt auf das Minimum, nicht auf die 6 Prozent
        // des Dauerlaufs.
        #expect(sut.nebenbelastung == 0)
    }

    // MARK: - Am Geraetetyp

    private func typModell(
        bootstrap: BootstrapResponse,
        loader: FakeGeraetLoader = FakeGeraetLoader(),
        enqueue: @escaping (PendingSetWrite) -> Void = { _ in }
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            station: GeraetTestdaten.typ, uebungId: "e1", token: nil,
            bootstrap: bootstrap, loader: loader,
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: enqueue)
    }

    /// Kalibrierungen haengen am Geraet (Spec 5.4): am Typ gibt es keinen
    /// Ort, an dem eine Sitzposition gelten koennte.
    @Test func amTypGibtEsKeinKalibrieren() async {
        let loader = FakeGeraetLoader()
        let sut = typModell(bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)

        #expect(!sut.kannKalibrieren)
        // Der Typ hat Einstellparameter, der Erstkontakt fragt trotzdem nicht.
        #expect(sut.hatEinstellparameter)
        #expect(!sut.erstkontaktFragtEinstellung)
        sut.kalibrierungOeffnen()
        #expect(!sut.kalibrierungOffen)
        #expect(await sut.kalibrierungSichern() == false)
        #expect(await loader.kalibrierungen.isEmpty)
    }

    @Test func amGeraetBleibtDasKalibrieren() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.kannKalibrieren)
        #expect(sut.erstkontaktFragtEinstellung)
    }

    @Test func amTypKommenDieStartwerteAusDenTypsaetzen() {
        var bootstrap = GeraetTestdaten.bootstrap(lastSets: [("em7", "e1", 99.0, 3)])
        bootstrap.lastTypeSets = [BootstrapResponse.LastTypeSet(
            equipmentModelId: "em7", exerciseId: "e1", load: 42.5, secondaryLoad: nil,
            volume: 9, rir: nil, performedAt: "2026-09-20T10:00:00Z")]
        let sut = typModell(bootstrap: bootstrap)

        #expect(sut.belastung == 42.5)
        #expect(sut.umfang == 9)
        #expect(sut.rueckblick?.zuletzt == "42,5 kg × 9")
        #expect(sut.letzteBelastung(fuer: "e1") == 42.5)
    }

    @Test func amTypSchreibtDerSatzOhneMachineId() async throws {
        var geschrieben: [PendingSetWrite] = []
        let sut = typModell(bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                            enqueue: { geschrieben.append($0) })

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        let body = try #require(geschrieben.first).body
        #expect(body.machineId == nil)
        #expect(body.equipmentModelId == "em7")
        #expect(body.studioId == "s1")
    }

    // MARK: - Zaehler

    private func mitZaehler(_ double: ZaehlerDouble = ZaehlerDouble(),
                            enqueue: @escaping (PendingSetWrite) -> Void = { _ in },
                            mitschnitt: (any SatzMitschnitt)? = nil,
                            maschine: BootstrapResponse.Machine = GeraetTestdaten.maschine) -> GeraetModel {
        let sut = modell(maschine: maschine, bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: enqueue, mitschnitt: mitschnitt, zaehler: double)
        sut.geraetGeoeffnet()
        return sut
    }

    @Test func dasRadFolgtDemZaehler() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        #expect(double.kontexte.count == 1)
        #expect(double.kontexte.first?.volumeKind == .reps)
        double.melde?(.bereit)
        #expect(sut.zaehlerZustand == .bereit)
        double.melde?(.stand(3))
        #expect(sut.umfang == 3)
        #expect(sut.zaehlerZustand == .zaehlt(3))
    }

    @Test func drehenInBereitIstKeineKorrektur() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        double.melde?(.bereit)
        sut.umfangGedreht(12)
        #expect(sut.zaehlerZustand == .bereit)
        double.melde?(.stand(1))
        #expect(sut.umfang == 1)
    }

    @Test func drehenNachDerZaehlungGehoertDerHand() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        double.melde?(.stand(5))
        sut.umfangGedreht(6)
        #expect(sut.zaehlerZustand == .vonHand(5))
        double.melde?(.stand(6))
        double.melde?(.stand(7))
        #expect(sut.umfang == 6)
    }

    @Test func pruefenHaeltDieZahl() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        double.melde?(.stand(4))
        double.melde?(.pruefen(4, .luecke))
        #expect(sut.zaehlerZustand == .pruefen(4))
        #expect(sut.umfang == 4)
        sut.umfangGedreht(5)
        #expect(sut.zaehlerZustand == .vonHand(4))
    }

    @Test func neueUnsichereZahlFolgtDemRadBisZurHandkorrektur() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(4))
        double.melde?(.pruefen(7, .luecke))
        #expect(sut.umfang == 7)
        #expect(sut.zaehlerZustand == .pruefen(7))
        sut.umfangGedreht(10)
        double.melde?(.pruefen(8, .luecke))
        #expect(sut.umfang == 10)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volume == 10)
        #expect(geschrieben.first?.body.volumeSource == .korrigiert)
        #expect(geschrieben.first?.body.volumeCounted == 8)
    }

    @Test(arguments: [(nil as Int?, 8, VolumeSource.eingegeben), (8, 8, .gemessen), (8, 9, .korrigiert)])
    func herkunftBeimSichern(gezaehlt: Int?, umfang: Int, erwartet: VolumeSource) async {
        let double = ZaehlerDouble()
        double.ergebnisWert = gezaehlt.map(ZaehlerDouble.ergebnis)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        if let gezaehlt { double.melde?(.stand(gezaehlt)) }
        if umfang != gezaehlt { sut.umfangGedreht(umfang) }
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        let body = geschrieben.first?.body
        #expect(body?.volume == umfang)
        #expect(body?.volumeSource == erwartet)
        #expect(body?.volumeCounted == gezaehlt)
        #expect(body?.repEvents?.wiederholungen.count == gezaehlt)
        #expect(sut.zaehlerZustand == .aus)
    }

    /// Testnotiz 16.10., #4 (Aufnahmen 1421-03, 1433-01): live stand das
    /// Rad auf 1, die Takt-Auswertung am Satzende zaehlte 8. Gespeichert
    /// wurden 1 und "korrigiert", obwohl niemand gedreht hatte. Ungedreht
    /// gilt die Endzahl des Zaehlers.
    @Test func ungedrehtGiltDieEndzahlDesZaehlers() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(1))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volume == 8)
        #expect(geschrieben.first?.body.volumeSource == .gemessen)
        #expect(geschrieben.first?.body.volumeCounted == 8)
    }

    /// Von Hand gedreht bleibt die Hand, auch wenn die Endzahl anders ist.
    @Test func gedrehtBleibtDerHandwert() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(1))
        sut.umfangGedreht(9)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volume == 9)
        #expect(geschrieben.first?.body.volumeSource == .korrigiert)
    }

    @Test func zurueckGedrehtIstGemessen() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(5)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(5))
        sut.umfangGedreht(6)
        sut.umfangGedreht(5)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volumeSource == .gemessen)
    }

    /// Review Focus 3: mehr Wiederholungen als das Rad hat (1...40).
    @Test func ueberDemRadmaximumWirdKorrigiert() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(43)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(43))
        #expect(sut.umfang == 40)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volumeSource == .korrigiert)
        #expect(geschrieben.first?.body.volumeCounted == 43)
    }

    @Test func uebungswechselVerwirftUndBeginntNeu() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double, maschine: GeraetTestdaten.maschineMitZweiUebungen)
        double.melde?(.stand(2))
        sut.uebungWechseln(zu: "e2")
        #expect(double.verworfen == 1)
        #expect(double.kontexte.last?.exerciseId == "e2")
        #expect(sut.zaehlerZustand == .aus)
    }

    @Test func screenVerlassenVerwirft() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        sut.screenVerlassen()
        #expect(double.verworfen == 1)
    }

    @Test func derMitschnittBekommtHerkunftErgebnisUndArt() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        let spion = MitschnittSpion()
        let sut = mitZaehler(double, mitschnitt: spion)
        double.melde?(.stand(8))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        guard case .gesichert(let satz)? = spion.ereignisse.last else { Issue.record("nichts gesichert"); return }
        #expect(satz.volumeSource == .gemessen)
        #expect(satz.zaehler?.gezaehlt == 8)
        #expect(satz.befestigung == BefestigungsWahl(art: .stapel, quelle: .vorschlag))
    }

    /// Review Focus 4: ein abgelehnter Satz holt kein Ergebnis ab, die
    /// Zaehlung laeuft weiter. Aufbau wie der Ortskonflikt-Test oben
    /// (laufende Einheit in einem anderen Studio).
    @Test func abgelehnterSatzHoltKeinErgebnis() async {
        let verzeichnis = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(4)
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions, mitschnitt: spion, zaehler: double)
        sut.geraetGeoeffnet()
        double.melde?(.stand(4))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.satzAbgelehnt != nil)
        #expect(double.ergebnisAufrufe == 0)
        #expect(sut.zaehlerZustand == .zaehlt(4))
        #expect(!spion.ereignisse.contains { if case .gesichert = $0 { true } else { false } })
    }

    /// Review Focus 5: Herkunft nur bei Wiederholungen -- der Server lehnt
    /// sie sonst ab (Spec 6.3).
    @Test func sekundenuebungBleibtEingegeben() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(3)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) }, maschine: GeraetTestdaten.maschineSekunden)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volumeSource == .eingegeben)
        #expect(geschrieben.first?.body.repEvents == nil)
    }

    // MARK: - Mitschnitt

    @Test func oeffnenMeldetDieEingabeMitGeraetUndUebung() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        #expect(spion.ereignisse == [.eingabe(SatzMitschnittKontext(
            station: Station(maschine: GeraetTestdaten.maschine), exerciseId: "e1", exerciseName: "Beidbeinig"))])
    }

    @Test func sichernMeldetGenauDenGeschriebenenSatz() async throws {
        let spion = MitschnittSpion()
        var geschrieben: [PendingSetWrite] = []
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         enqueue: { geschrieben.append($0) }, mitschnitt: spion)
        sut.geraetGeoeffnet()

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        let write = try #require(geschrieben.first)
        #expect(spion.ereignisse.last == .gesichert(GesicherterSatz(
            sessionId: write.sessionId, setId: write.setId, setIndex: 1,
            weightKg: 77.5, reps: 11, problemFlag: false)))
    }

    @Test func nachDerPauseBeginntDieEingabeErneut() async {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(spion.eingaben == 1)          // in der Pause laeuft nichts
        sut.pauseBeenden()
        #expect(spion.eingaben == 2)
    }

    @Test func uebungswechselInDerEingabeMeldetDenNeuenKontext() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        sut.uebungWechseln(zu: "e2")
        #expect(spion.ereignisse.last == .eingabe(SatzMitschnittKontext(
            station: Station(maschine: GeraetTestdaten.maschineMitZweiUebungen),
            exerciseId: "e2", exerciseName: "Einbeinig")))
        #expect(spion.eingaben == 2)
    }

    @Test func uebungswechselAusDerPauseMeldetGenauEinmal() async {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.uebungWechseln(zu: "e2")
        #expect(spion.eingaben == 2)
    }

    @Test func amCardioGeraetBleibtDasLabelOhneKiloUndWiederholungen() async throws {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]),
                         mitschnitt: spion)
        sut.geraetGeoeffnet()

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        guard case .gesichert(let satz)? = spion.ereignisse.last else {
            Issue.record("kein gesicherter Satz gemeldet"); return
        }
        #expect(satz.weightKg == nil)
        #expect(satz.reps == nil)
    }

    @Test func verlassenWirdWeitergereicht() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        sut.screenVerlassen()
        #expect(spion.ereignisse.last == .verlassen)
    }
}

@MainActor
final class ZaehlerDouble: SatzZaehler {
    var automatikMelde: (@MainActor (SatzAutomatik.Ereignis) -> Void)?
    func automatikBeobachten(_ melde: (@MainActor (SatzAutomatik.Ereignis) -> Void)?) { automatikMelde = melde }
    var kontexte: [SatzZaehlerKontext] = []
    var melde: (@MainActor (ZaehlerMeldung) -> Void)?
    var verworfen = 0
    var ergebnisAufrufe = 0
    var ergebnisWert: ZaehlerErgebnis?
    var befestigung: BefestigungsWahl? = BefestigungsWahl(art: .stapel, quelle: .vorschlag)

    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void) {
        kontexte.append(kontext)
        self.melde = melde
    }
    func ergebnis() -> ZaehlerErgebnis? { ergebnisAufrufe += 1; return ergebnisWert }
    func satzVerworfen() { verworfen += 1 }

    static func ergebnis(_ n: Int) -> ZaehlerErgebnis {
        let w = (0..<n).map { i in
            Wiederholung(nummer: i + 1, beginn: Double(i) * 2, umkehr: Double(i) * 2 + 1, ende: Double(i) * 2 + 2,
                         ausschlag: 0.4, sicherheit: 1, pauseDavor: nil)
        }
        return ZaehlerErgebnis(gezaehlt: n, repEvents: RepEvents(
            algo: "stapel/2", befestigungsart: .stapel, ereignisse: w.map(ZaehlerEreignis.wiederholung), satzbeginn: 0))
    }
}

@MainActor
final class MitschnittSpion: SatzMitschnitt {
    enum Ereignis: Equatable {
        case eingabe(SatzMitschnittKontext)
        case gesichert(GesicherterSatz)
        case verlassen
    }
    var ereignisse: [Ereignis] = []
    var eingaben: Int { ereignisse.filter { if case .eingabe = $0 { true } else { false } }.count }

    func eingabeBegonnen(_ kontext: SatzMitschnittKontext) { ereignisse.append(.eingabe(kontext)) }
    func satzGesichert(_ satz: GesicherterSatz) { ereignisse.append(.gesichert(satz)) }
    func screenVerlassen() { ereignisse.append(.verlassen) }
}

/// Faengt ein, was eine GeraetModel-Instanz einreiht -- damit ein
/// still geloeschter enqueue-Aufruf in einem Test auffaellt statt
/// unbemerkt durchzugehen.
@MainActor
private final class Erfassungswarteschlange {
    var geschriebene: [PendingSetWrite] = []
}

// MARK: - Testdaten

actor FakeGeraetLoader: GeraetLoading {
    var kontextResult: Result<TagContextResponse, APIError> = .failure(.offline)
    var calibrationResult: Result<RecordedCalibration, APIError> = .failure(.offline)

    /// Wer gerufen wurde. Seit ein Geraet auch ohne Token erreichbar ist,
    /// ist die Wegwahl selbst pruefenswert, nicht nur das Ergebnis.
    private(set) var tagAufrufe: [String] = []
    private(set) var machineAufrufe: [String] = []
    struct TypAufruf: Equatable { let modelId: String; let studio: String? }
    private(set) var typAufrufe: [TypAufruf] = []

    func setKontext(_ value: Result<TagContextResponse, APIError>) { kontextResult = value }
    func setCalibration(_ value: Result<RecordedCalibration, APIError>) { calibrationResult = value }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        tagAufrufe.append(token)
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Liefert dasselbe wie tagContext: der Server liefert auf beiden
    /// Wegen dieselbe Form, und geprueft wird hier der Weg, nicht der Inhalt.
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse {
        machineAufrufe.append(machineId)
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func equipmentModelContext(modelId: String, studio: String?) async throws(APIError) -> TagContextResponse {
        typAufrufe.append(TypAufruf(modelId: modelId, studio: studio))
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Was gesendet wurde -- bei Auswahlwerten zaehlt die Form (Text statt
    /// Zahl), nicht nur, dass gesendet wurde.
    private(set) var kalibrierungen: [CalibrationWrite] = []

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        kalibrierungen.append(body)
        switch calibrationResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func completeSession(sessionId: UUID, pausedSeconds: Int) async throws(APIError) -> CompletedSession {
        throw APIError.offline
    }
}

enum GeraetTestdaten {
    static func dekodiere<T: Decodable>(_ json: String, as: T.Type = T.self) -> T {
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    /// Ein Geraetetyp ohne Geraet im Studio s1, mit Einstellparameter --
    /// damit "kein Kalibrieren" nicht nur an fehlenden Parametern haengt.
    static var typ: Station {
        Station(typ: dekodiere("""
        {"id":"em7","name":"Beinpresse","manufacturer":null,"photoPath":null,
         "category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
         "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
           "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}],
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """), studioId: "s1")
    }

    /// Cardio-Typ ohne Wiederholungen: der Zaehler hat hier keinen Vorschlag
    /// fuer die Befestigung (Sensor-Spec B, Nachtrag 14.10. Punkt 2).
    static var cardioTyp: Station {
        Station(typ: dekodiere("""
        {"id":"em9","name":"Ruderergometer","manufacturer":null,"photoPath":null,
         "category":"cardio","loadUnit":"level","loadStep":1,"loadMin":1.0,"loadMax":10.0,
         "settingDefinitions":[],
         "exercises":[{"id":"e9","name":"Rudern","volumeKind":"meters","targetMin":500,"targetMax":2000}]}
        """), studioId: "s1")
    }

    static var maschine: BootstrapResponse.Machine { maschine(loadMax: "150.0") }

    /// Eine Uebung in Sekunden (Plank-artig) am selben Geraet: Herkunft
    /// bleibt dort eingegeben (Sensor-Spec B 6.3).
    static var maschineSekunden: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Halten","volumeKind":"seconds","targetMin":60,"targetMax":90}]}
        """)
    }
    static var maschineOhneMaximum: BootstrapResponse.Machine { maschine(loadMax: "null") }

    /// Ein Modell ohne Einstellparameter -- laut Trainerportal ein
    /// regulaerer Zustand, kein Datenfehler.
    static var maschineOhneEinstellparameter: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
    }

    /// Drei Einstellparameter, der mittlere eine Auswahl -- genau der Fall
    /// aus der Testnotiz 06.10., #17 (Kabelzug mit Griffposition).
    static var maschineMitAuswahl: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Kabelzug","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":2.5,"loadMax":100.0,
           "settingDefinitions":[
             {"key":"hoehe","label":"Höhe","kind":"number",
              "minValue":1,"maxValue":20,"stepValue":1,"unit":null,"allowedValues":null},
             {"key":"griff","label":"Griffposition","kind":"enum",
              "minValue":null,"maxValue":null,"stepValue":null,"unit":null,
              "allowedValues":["eng","weit","neutral"]},
             {"key":"sitz","label":"Sitz","kind":"number",
              "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Kabelzug hoch","volumeKind":"reps","targetMin":10,"targetMax":15}]}
        """)
    }

    /// Ein Bootstrap mit einer Kalibrierung, die eine Auswahl enthaelt.
    static func bootstrapMitAuswahl(griff: String) -> BootstrapResponse {
        dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],
         "calibrations":[{"machineId":"m1","exerciseId":"e1","settingValues":{"hoehe":7,"griff":"\(griff)","sitz":3},
           "schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}],"lastSets":[]}
        """)
    }

    static func maschine(loadMax: String, loadStart: String = "null") -> BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":\(loadMax),
           "loadStart":\(loadStart),
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
    }

    /// Zwei Uebungen an einem Geraet -- fuer den Uebungswechsel-Test:
    /// tag-context.ts liefert calibration/suggestion nur fuer eine der beiden.
    static var maschineMitZweiUebungen: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12},
                      {"id":"e2","name":"Einbeinig","volumeKind":"reps","targetMin":6,"targetMax":10}]}
        """)
    }

    /// Das Laufband aus Spec Abschnitt 9: km/h in halben Schritten,
    /// Neigung als Nebenbelastung, Dauerlauf 15 bis 20 Minuten. Die zweite
    /// Uebung zaehlt Meter -- fuer den Wechsel der Umfangsart.
    static var laufband: BootstrapResponse.Machine { laufband(neigung: true) }
    static var laufbandOhneNeigung: BootstrapResponse.Machine { laufband(neigung: false) }

    private static func laufband(neigung: Bool) -> BootstrapResponse.Machine {
        let neben = neigung
            ? #""secondaryUnit":"pct","secondaryStep":0.5,"secondaryMin":0,"secondaryMax":15,"#
            : #""secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null,"#
        return dekodiere("""
        {"id":"m9","studioId":"s1","label":"Laufband 2","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em9","name":"Laufband","manufacturer":"Technogym",
           "category":"cardio","photoPath":null,"loadUnit":"kmh","loadStep":0.5,"loadMin":0,"loadMax":20,
           \(neben)
           "settingDefinitions":[]},
         "exercises":[{"id":"e9","name":"Dauerlauf","volumeKind":"seconds","targetMin":900,"targetMax":1200},
                      {"id":"e10","name":"Intervall","volumeKind":"meters","targetMin":2000,"targetMax":5000}]}
        """)
    }

    /// Ergometer mit Stufenanzeige (Spec Abschnitt 9): die Stufe ist die
    /// Belastung, die Trittfrequenz die Nebenbelastung.
    static var ergometerMitStufen: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m8","studioId":"s1","label":"Ergometer 1","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em8","name":"Ergometer","manufacturer":null,
           "category":"cardio","photoPath":null,"loadUnit":"level","loadStep":1,"loadMin":1,"loadMax":20,
           "secondaryUnit":"rpm","secondaryStep":5,"secondaryMin":50,"secondaryMax":120,
           "settingDefinitions":[]},
         "exercises":[{"id":"e8","name":"Grundlage","volumeKind":"seconds","targetMin":1200,"targetMax":1800}]}
        """)
    }

    /// Letzte Saetze mit Nebenbelastung: (Geraet, Uebung, Belastung,
    /// Nebenbelastung, Umfang).
    static func bootstrap(laufbandSaetze: [(String, String, Double, Double, Int)]) -> BootstrapResponse {
        let saetze = laufbandSaetze.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "load":\(eintrag.2),"secondaryLoad":\(eintrag.3),"volume":\(eintrag.4),"rir":null,
             "performedAt":"2026-09-20T10:00:00Z"}
            """
        }.joined(separator: ",")
        return dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[\(saetze)]}
        """)
    }

    /// Der Kontext zum Laufband. `neben` ist die Nebenbelastung, bei der
    /// der Vorschlag gilt -- die Regel steigert sie nie, sie gibt sie mit.
    static func laufbandKontext(vorschlag: Double?, bisher: Double?, neben: Double?) -> TagContextResponse {
        func json(_ wert: Double?) -> String { wert.map { "\($0)" } ?? "null" }
        return dekodiere("""
        {"machine":{"id":"m9","label":"Laufband 2","locationNote":null},
         "equipmentModel":{"id":"em9","name":"Laufband","manufacturer":"Technogym",
           "photoUrl":null,"loadUnit":"kmh","loadStep":0.5,"loadMin":0,"loadMax":20,
           "secondaryUnit":"pct","secondaryStep":0.5,"secondaryMin":0,"secondaryMax":15},
         "settingDefinitions":[],
         "exercises":[{"id":"e9","name":"Dauerlauf","description":null,
           "volumeKind":"seconds","targetMin":900,"targetMax":1200,"instructionVideoUrl":null},
           {"id":"e10","name":"Intervall","description":null,
           "volumeKind":"meters","targetMin":2000,"targetMax":5000,"instructionVideoUrl":null}],
         "selectedExerciseId":"e9","calibration":null,
         "history":[],
         "suggestion":{"algoVersion":"2.0.0","resultLoad":\(json(vorschlag)),
           "resultSecondaryLoad":\(json(neben)),
           "reasonCode":"korridor_oben_erreicht","inputs":{"targetMin":900,"targetMax":1200,
             "loadStep":0.5,"loadMin":0,"loadMax":20,
             "currentLoad":\(json(bisher)),"currentSecondaryLoad":\(json(neben)),"consideredBlocks":2}}}
        """)
    }

    static func bootstrap(
        lastSets: [(String, String, Double, Int)],
        mitKalibrierung: Bool = false,
        kalibrierungExerciseId: String = "e1",
        kalibrierungSitzWert: Int = 4
    ) -> BootstrapResponse {
        let saetze = lastSets.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "load":\(eintrag.2),"volume":\(eintrag.3),"rir":null,
             "performedAt":"2026-09-01T10:00:00Z"}
            """
        }.joined(separator: ",")
        let kalibrierungen = mitKalibrierung
            ? #"{"machineId":"m1","exerciseId":"\#(kalibrierungExerciseId)","settingValues":{"sitz":\#(kalibrierungSitzWert)},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}"#
            : ""
        return dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[\(kalibrierungen)],"lastSets":[\(saetze)]}
        """)
    }

    static func kontext(vorschlag: Double, kalibrierungSitzWert: Int? = nil, muskeln: String? = nil) -> TagContextResponse {
        let kalibrierung = kalibrierungSitzWert.map {
            #"{"settingValues":{"sitz":\#($0)},"schemaVersion":1,"source":"self","createdAt":"2026-09-01T10:00:00Z"}"#
        } ?? "null"
        return dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0},
         "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
           "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "volumeKind":"reps","targetMin":8,"targetMax":12,"instructionVideoUrl":null\(muskeln.map { #","muscles":\#($0)"# } ?? "")},
           {"id":"e2","name":"Einbeinig","description":null,
           "volumeKind":"reps","targetMin":6,"targetMax":10,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":\(kalibrierung),
         "history":[{"performedOn":"2026-09-01","load":77.5,"volume":[11,11,10]}],
         "suggestion":{"algoVersion":"v1","resultLoad":\(vorschlag),
           "reasonCode":"steigerung","inputs":{"targetMin":8,"targetMax":12,
             "loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
             "currentLoad":77.5,"consideredBlocks":1}}}
        """)
    }
}

@MainActor
extension GeraetModelTests {
    private func automatikModell(_ double: ZaehlerDouble, ziel: Int = 3,
                                 startwerte: Bool = true) -> (GeraetModel, WorkoutSessionStore, Erfassungswarteschlange) {
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        sessions.trainingStarten()
        let writes = Erfassungswarteschlange()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), sessions: sessions,
                         enqueue: { writes.geschriebene.append($0) }, satzZiel: ziel, zaehler: double)
        if startwerte { sut.belastungGewaehlt(42.5) }
        sut.automatikVorbereiten()
        return (sut, sessions, writes)
    }

    @Test func automatikStartetAusPauseOhneZaehlerNeustart() {
        let double = ZaehlerDouble()
        let (sut, _, _) = automatikModell(double)
        let starts = double.kontexte.count
        let kennung = UUID()
        double.melde?(.stand(2))
        double.automatikMelde?(.begonnen(kennung: kennung, beginn: 10, bewegung: 14))
        #expect(sut.phase == .eingabe)
        #expect(sut.umfang == 2)
        #expect(sut.belastung == 42.5)
        #expect(double.kontexte.count == starts)
        sut.geraetGeoeffnet()
        #expect(double.kontexte.count == starts)
    }

    @Test func automatikUndManuellesSpeichernErzeugenGenauEinenSatz() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        let (sut, sessions, writes) = automatikModell(double)
        let kennung = UUID()
        let callback = double.automatikMelde
        callback?(.begonnen(kennung: kennung, beginn: 10, bewegung: 26))
        callback?(.beendet(kennung: kennung, bewegung: 26))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        await Task.yield()
        callback?(.beendet(kennung: kennung, bewegung: 26))
        await Task.yield()
        #expect(writes.geschriebene.count == 1)
        #expect(sessions.aktiveSession()?.bloecke.first?.saetze.count == 1)
        #expect(writes.geschriebene.first?.body.load == 42.5)
        #expect(writes.geschriebene.first?.body.volumeCounted == 8)
    }

    @Test func ohneStartwerteStartetAutomatikNicht() {
        let double = ZaehlerDouble()
        let (sut, _, _) = automatikModell(double, startwerte: false)
        double.automatikMelde?(.begonnen(kennung: UUID(), beginn: 10, bewegung: 14))
        if case .pause = sut.phase {} else { Issue.record("Fehlende Startwerte brauchen die manuelle Eingabe") }
    }

    @Test func satzzielUndAlteKennungVerhindernWeitereAutomatischeSaetze() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        let (sut, _, writes) = automatikModell(double, ziel: 1)
        let callback = double.automatikMelde
        let kennung = UUID()
        callback?(.begonnen(kennung: kennung, beginn: 10, bewegung: 26))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        callback?(.begonnen(kennung: UUID(), beginn: 40, bewegung: 44))
        callback?(.beendet(kennung: kennung, bewegung: 26))
        await Task.yield()
        #expect(sut.phase == .abschluss)
        #expect(writes.geschriebene.count == 1)
    }
}

#if DEBUG
@MainActor
extension GeraetModelTests {
    @Test func zweiAutomatischeSaetzeOhneNeueViewLaufenDurchDenLokalenSpeicherpfad() async throws {
        let quelle = AttrappenQuelle()
        quelle.zustand = ZaehlerKoordinatorTests.verbunden
        let uhr = ZaehlerKoordinatorTests.Uhr()
        let zaehler = ZaehlerKoordinator(quelle: quelle,
            einstellungen: UserDefaults(suiteName: UUID().uuidString)!, uhr: { uhr.t })
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        sessions.trainingStarten()
        let writes = Erfassungswarteschlange()
        let sut = modell(maschine: GeraetTestdaten.maschine,
            bootstrap: GeraetTestdaten.bootstrap(lastSets: []), sessions: sessions,
            enqueue: { writes.geschriebene.append($0) }, satzZiel: 2, zaehler: zaehler)
        sut.belastungGewaehlt(42.5)
        sut.geraetGeoeffnet()
        zaehler.befestigungWaehlen(.stapel)
        for satz in 1...2 {
            let werte = ZaehlerKoordinatorTests.stapelSatz(wiederholungen: 5, ab: uhr.t + 0.02)
            for wert in werte {
                uhr.t = wert.t
                zaehler.empfangen(.messwert(wert))
            }
            for _ in 0..<200 {
                if zaehler.automatik.zustand == .laeuft { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(zaehler.automatik.zustand == .laeuft)
            for _ in 0..<500 {
                uhr.t += 0.02
                zaehler.empfangen(.messwert(SensorMesswert(t: uhr.t, beschleunigung: .init(x: 0, y: 0, z: 1),
                    drehrate: .init(x: 0, y: 0, z: 0), winkel: .init(x: 0, y: 0, z: 0))))
            }
            for _ in 0..<200 {
                if writes.geschriebene.count == satz { break }
                try await Task.sleep(for: .milliseconds(10))
                uhr.t += 0.02
                zaehler.empfangen(.messwert(SensorMesswert(t: uhr.t, beschleunigung: .init(x: 0, y: 0, z: 1),
                    drehrate: .init(x: 0, y: 0, z: 0), winkel: .init(x: 0, y: 0, z: 0))))
            }
            #expect(writes.geschriebene.count == satz)
        }
        #expect(sut.phase == .abschluss)
        #expect(writes.geschriebene.map(\.body.load) == [42.5, 42.5])
        #expect(writes.geschriebene.map(\.body.volumeCounted) == [5, 5])
        #expect(sessions.aktiveSession()?.bloecke.first?.saetze.count == 2)
        sut.screenVerlassen()
    }
}
#endif
