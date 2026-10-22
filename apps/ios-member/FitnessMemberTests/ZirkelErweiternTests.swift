import Foundation
import Testing
@testable import FitnessMember

/// Zirkel nachtraeglich erweitern (Spec Mini-Zirkel 21.10., Task 7): aus der
/// Pause nach Satz 1 einer Einzeluebung heraus und im Zirkel nach der
/// letzten Uebung von Runde 1. Die Sheets selbst sind UI; geprueft werden
/// die Regeln, an denen sie haengen.
@MainActor
struct ZirkelErweiternTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func uebung(_ i: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:g\(i)", exerciseId: "e\(i)", token: nil)
    }

    private func modell(satzZiel: Int = 3) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let maschine = GeraetTestdaten.maschine
        return GeraetModel(
            station: Station(maschine: maschine),
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
            loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: { _ in },
            satzZiel: { satzZiel }
        )
    }

    // MARK: - Einzeluebung: "Zirkel mit weiterem Gerät"

    @Test func nachGenauEinemSatzInDerPauseKannEinZirkelBeginnen() async {
        let sut = modell()
        #expect(!sut.kannZirkelBeginnen)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)
        #expect(sut.kannZirkelBeginnen)
    }

    @Test func nachZweiSaetzenNicht() async {
        let sut = modell()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)
        #expect(!sut.kannZirkelBeginnen)
    }

    /// Ein Zirkel-Geraet erweitert ueber die Zirkel-Pause, nicht ueber sein
    /// eigenes Rad -- der Hook macht es zum Zirkel-Geraet, auch wenn eine
    /// Pause liefe.
    @Test func imZirkelmodusNicht() async {
        let sut = modell()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.beiZirkelSatzGesichert = {}
        #expect(sut.laufendePause != nil)
        #expect(!sut.kannZirkelBeginnen)
    }

    @Test func ohnePauseNicht() async {
        let sut = modell()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        #expect(!sut.kannZirkelBeginnen)
    }

    /// Carry-over Task 5: Runde 1 beginnt mit dem Einzelsatz, nicht mit dem
    /// Start des Zirkels -- sonst fehlte er in der Rundenzusammenfassung.
    @Test func derEinzelsatzNenntSeinenZeitpunkt() async {
        let sut = modell()
        #expect(sut.letzterSatzAm == nil)
        let vorher = Date()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        let am = try? #require(sut.letzterSatzAm)
        #expect(am.map { $0 >= vorher && $0 <= Date() } == true)
    }

    /// Spec "Meine Annahmen": kein Planungs-Screen -- drei Runden, Pausen
    /// aus dem Profil, der Einzelsatz zaehlt als Slot 1.
    @Test func derZirkelAusDemEinzelsatzNimmtDieProfilpausen() throws {
        let defaults = try #require(UserDefaults(suiteName: "ZirkelErweitern-\(UUID().uuidString)"))
        defaults.set(45, forKey: Einstellungen.zirkelPauseSekundenKey)
        defaults.set(120, forKey: Einstellungen.resttimerSekundenKey)
        let zirkel = Zirkel.ausEinzelsatz(uebung(1), zweite: uebung(2), defaults: defaults)
        #expect(zirkel.runden == 3)
        #expect(zirkel.uebungspause == 45)
        #expect(zirkel.rundenpause == 120)
        #expect(zirkel.schritt == 1)
        #expect(zirkel.naechste == uebung(2))
    }

    /// Der Geraete-Screen der Einzeluebung macht der neuen Zirkel-Uebung
    /// Platz -- aber nur er, kein Zirkel-Screen und keine Pause.
    @Test func ausDerEinzeluebungErsetztDieNeueUebungDenGeraeteScreen() {
        let einzel = GeraetRoute.geraet(station: "geraet:g1", exerciseId: "e1", token: nil)
        let neu = GeraetRoute.geraet(station: "geraet:g2", exerciseId: "e2", token: nil, zirkel: true)
        #expect(ZirkelPfad.ausEinzeluebung([.kategorie(.freihantel), einzel], zu: neu) == [.kategorie(.freihantel), neu])
        // Schon im Zirkel, oder oben liegt etwas anderes: nichts.
        #expect(ZirkelPfad.ausEinzeluebung([neu], zu: neu) == nil)
        #expect(ZirkelPfad.ausEinzeluebung([einzel, .zirkelPause], zu: neu) == nil)
        #expect(ZirkelPfad.ausEinzeluebung([], zu: neu) == nil)
    }

    // MARK: - Im Zirkel: "+ Übung zum Zirkel"

    private func nachRundeEins(n: Int = 2) -> ZirkelAblauf {
        let ablauf = ZirkelAblauf()
        ablauf.starten(Zirkel(uebungen: (1...n).map(uebung), runden: 3, uebungspause: 20, rundenpause: 90), jetzt: t0)
        for i in 1...n { ablauf.satzGesichert(jetzt: t0.addingTimeInterval(Double(i) * 60)) }
        return ablauf
    }

    @Test func inDerPauseNachDerLetztenUebungVonRundeEinsHaengtErweiternAn() {
        let ablauf = nachRundeEins()
        #expect(ablauf.zirkel?.kannErweitern == true)
        #expect(ablauf.erweitern(um: uebung(9)))
        #expect(ablauf.zirkel?.uebungen == [uebung(1), uebung(2), uebung(9)])
        #expect(ablauf.zirkel?.naechste == uebung(9))
        #expect(ablauf.zirkel?.runde == 1)
        // Jetzt steht kein Rundenwechsel mehr an, sondern die neue Uebung.
        #expect(ablauf.zirkel?.naechsterSchrittIstRundenwechsel == false)
    }

    /// Review Focus: Erweitern laesst die Pause, wie sie ist -- weder neu
    /// gestartet noch geraeumt. Navigiert wird nur ueber den Pfad.
    @Test func erweiternLaesstDiePauseUnveraendert() {
        let ablauf = nachRundeEins()
        let pause = ablauf.pause
        #expect(pause != nil)
        ablauf.erweitern(um: uebung(9))
        #expect(ablauf.pause == pause)
    }

    @Test func nachRundeEinsLiefertErweiternFalse() {
        let ablauf = nachRundeEins()
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(300))
        let vorher = ablauf.zirkel
        #expect(!ablauf.erweitern(um: uebung(9)))
        #expect(ablauf.zirkel == vorher)
    }

    @Test func mittenInRundeEinsLiefertErweiternFalse() {
        let ablauf = ZirkelAblauf()
        ablauf.starten(Zirkel(uebungen: (1...3).map(uebung), runden: 3, uebungspause: 20, rundenpause: 90), jetzt: t0)
        ablauf.satzGesichert(jetzt: t0)
        #expect(!ablauf.erweitern(um: uebung(9)))
    }

    /// Runde 1 war mit dem Slot vor dem Erweitern schon "geschafft"; mit der
    /// neuen Uebung laeuft sie weiter. Ihre Zusammenfassung muss deshalb
    /// wieder beim alten Rundenbeginn anfangen, sonst fehlten die Saetze
    /// vor dem Erweitern.
    @Test func nachDemErweiternUmfasstRundeEinsWiederAlleSaetze() {
        let ablauf = nachRundeEins()
        ablauf.erweitern(um: uebung(9))
        #expect(ablauf.geschaffteRunde == nil)
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(500))
        #expect(ablauf.geschaffteRunde == DateInterval(start: t0, end: t0.addingTimeInterval(500)))
        #expect(ablauf.zirkel?.runde == 2)
        #expect(ablauf.pause?.gesamtdauer == 90)
    }

    /// Aus dem Einzelsatz gestartet, ist nach der zweiten Uebung Runde 1
    /// komplett -- erweitern geht dann genauso.
    @Test func einZirkelAusDemEinzelsatzLaesstSichNachRundeEinsErweitern() {
        let ablauf = ZirkelAblauf()
        ablauf.starten(Zirkel.ausEinzelsatz(uebung(1), zweite: uebung(2), runden: 3, uebungspause: 20, rundenpause: 90),
                       jetzt: t0.addingTimeInterval(30), rundeBegann: t0)
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(120))
        #expect(ablauf.geschaffteRunde == DateInterval(start: t0, end: t0.addingTimeInterval(120)))
        #expect(ablauf.erweitern(um: uebung(3)))
        #expect(ablauf.zirkel?.naechste == uebung(3))
    }

    /// Carry-over Task 4: erweitert wird nur, solange die Pause nach Runde 1
    /// oben liegt. Ist die Pause abgelaufen und der Zirkel weitergegangen,
    /// zaehlt der Zirkel bis zum naechsten Satz zwar noch "Runde 1 komplett"
    /// -- die Uebung landete dann aber im falschen Slot.
    @Test func erweitertWirdNurAusDerPauseHeraus() {
        let ablauf = nachRundeEins()
        let zirkel = ablauf.zirkel
        let geraet = GeraetRoute.geraet(station: "geraet:g1", exerciseId: "e1", token: nil, zirkel: true)
        #expect(ZirkelPfad.kannErweitern([geraet, .zirkelPause], zirkel: zirkel))
        #expect(!ZirkelPfad.kannErweitern([geraet], zirkel: zirkel))
        #expect(!ZirkelPfad.kannErweitern([geraet, .zirkelPause], zirkel: nil))
        var weiter = zirkel
        weiter?.weiter()
        #expect(!ZirkelPfad.kannErweitern([geraet, .zirkelPause], zirkel: weiter))
    }

    /// Dieselbe Regel wie in der Planung (ZirkelEntwurf.hinzufuegen): eine
    /// Uebung nur einmal, egal mit welchem Token.
    @Test func eineUebungStehtNurEinmalImZirkel() {
        let zirkel = Zirkel(uebungen: [uebung(1), uebung(2)], uebungspause: 20, rundenpause: 90)
        #expect(zirkel.enthaelt(ZirkelUebung(station: "geraet:g1", exerciseId: "e1", token: "t")))
        #expect(!zirkel.enthaelt(uebung(3)))
    }
}
