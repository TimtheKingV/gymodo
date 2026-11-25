import AVFoundation
import Foundation
import Koerperbild
import Sensorik
import Testing
@testable import FitnessMember

/// Eine Bildquelle, die Bilder auf Zuruf liefert oder beim Start wirft.
@MainActor
final class TestBildquelle: Bildquelle {
    let anzeige = AVSampleBufferDisplayLayer()
    var beiFehler: (@MainActor () -> Void)?
    var startFehler: (any Error)?
    private(set) var startAufrufe = 0
    private(set) var stoppAufrufe = 0
    private(set) var laeuft = false
    private var beiBild: (@MainActor (Kamerabild) -> Void)?

    func starten(beiBild: @escaping @MainActor (Kamerabild) -> Void) async throws {
        startAufrufe += 1
        if let startFehler { throw startFehler }
        self.beiBild = beiBild
        laeuft = true
    }

    func stoppen() {
        stoppAufrufe += 1
        laeuft = false
        beiBild = nil
    }

    func liefere(t: TimeInterval, skelett: Skelett?) { beiBild?(Kamerabild(t: t, skelett: skelett, anzeige: nil)) }
}

@MainActor
final class NahtDouble: KameraNaht {
    var kameraStart: KameraStart?
    var kameraWahl: KameraWahl = .mitKamera
    var kameraEinstieg: KameraEinstieg = .video
    var anzeigeSatz = 1
    /// Wie GeraetModel: nur eine laufende Pause zaehlt.
    var laufendePause: Resttimer? { pause.flatMap { $0.laeuft() ? $0 : nil } }
    private var pause: Resttimer?
    /// Wie GeraetModel.phase: in der Pause (auch abgelaufen) wird nichts gesichert.
    private var inPause = false
    var satzAbgelehnt: String?

    /// Was `kameraSatzSichern` antwortet, und die Pause, die das Sichern startet.
    var sichernAntwort: KameraSichern = .gesichert(letzterSatz: false)
    var pauseNachSichern: Resttimer?
    var sichernPausiert = false

    private(set) var gesichert: [Int] = []
    private(set) var verlassen: [Int?] = []
    private(set) var verlassenAufrufe = 0
    private(set) var abgeschlossen = 0
    private(set) var nachgetragen: [Int] = []
    private(set) var pausenEnden = 0
    private(set) var weitereSaetze = 0

    func kameraSatzSichern(wiederholungen: Int) async -> KameraSichern {
        if inPause { return .abgelehnt("Satz konnte nicht gesichert werden.") }
        gesichert.append(wiederholungen)
        if sichernPausiert { try? await Task.sleep(for: .milliseconds(50)) }
        if case .gesichert = sichernAntwort {
            pause = pauseNachSichern
            inPause = pauseNachSichern != nil
        }
        return sichernAntwort
    }

    func kameraVerlassen(gezaehlt: Int?) {
        verlassen.append(gezaehlt)
        verlassenAufrufe += 1
    }

    func kameraAblaufSchliessen() { abgeschlossen += 1 }
    func kameraWiederAufnehmen() {}
    func umfangNachtragen(_ wiederholungen: Int) { nachgetragen.append(wiederholungen) }
    func pauseBeenden() {
        pausenEnden += 1
        pause = nil
        inPause = false
    }
    /// Wie GeraetModel: "Weiterer Satz" oeffnet eine neue Pause.
    func weitererSatz() {
        weitereSaetze += 1
        pause = Resttimer(dauer: 60)
        inPause = true
    }
}

@MainActor
struct KameraAblaufModellTests {
    private static let vorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .links)!
    /// 2 s senken, 1 s heben, Hub 90 Grad (170 -> 80).
    private static let tempo = Uebungstempo(senken: 2, halten: 0, heben: 1, beginntMit: .senken)
    private static let oben = 170.0
    private static let hub = 90.0
    private static let rate = 30.0

    private static func start() -> KameraStart {
        KameraStart(exerciseId: "e1", name: "Kniebeuge", geraet: nil, vorgabe: vorgabe, tempo: tempo,
                    sollWiederholungen: 10, satzZiel: 3)
    }

    /// Linke Seite im Bild, Kniewinkel `winkel` (Hueft-Knie-Fuss).
    private static func skelett(knie winkel: Double) -> Skelett {
        let a = winkel * .pi / 180
        let punkte: [Gelenk: Punkt] = [
            .schulterL: Punkt(x: 0.5, y: 0.2, sicherheit: 1),
            .hueftL: Punkt(x: 0.5, y: 0.5, sicherheit: 1),
            .knieL: Punkt(x: 0.5, y: 0.7, sicherheit: 1),
            .fussL: Punkt(x: 0.5 + 0.2 * sin(a), y: 0.7 - 0.2 * cos(a), sicherheit: 1),
        ]
        return Skelett(punkte: punkte, seitenverhaeltnis: 1)
    }

    /// Alles, was ein Test braucht, mit einer fortlaufenden Bilduhr.
    @MainActor private final class Aufbau {
        let naht = NahtDouble()
        let quelle = TestBildquelle()
        let speicher: Hubspeicher
        var erlaubnis: Kameraerlaubnis = .erlaubt
        /// Haelt `anfragen` an, bis `anfrageFreigeben()` kommt.
        var anfrageHalten = false
        private var anfrageWeiter: CheckedContinuation<Void, Never>?
        var anfrageWartet: Bool { anfrageWeiter != nil }
        func anfrageFreigeben() { anfrageWeiter?.resume(); anfrageWeiter = nil }
        var antwortAufAnfrage: Kameraerlaubnis = .erlaubt
        private(set) var anfragen = 0
        private(set) var idleZustand: Bool?
        /// Der Wert, den der Bildschirm vor dem Oeffnen hatte.
        var idleVorher = false
        var t = 0.0
        var modell: KameraAblaufModell!

        init(einstieg: KameraEinstieg = .video) {
            let suite = "kamera-test-\(UUID().uuidString)"
            speicher = Hubspeicher(defaults: UserDefaults(suiteName: suite)!)
            naht.kameraStart = KameraAblaufModellTests.start()
            naht.kameraEinstieg = einstieg
            modell = KameraAblaufModell(
                naht: naht, quelle: { [quelle] _ in quelle }, hub: speicher,
                erlaubnis: { [unowned self] in erlaubnis },
                anfragen: { [unowned self] in
                    anfragen += 1
                    if anfrageHalten { await withCheckedContinuation { anfrageWeiter = $0 } }
                    erlaubnis = antwortAufAnfrage
                    return antwortAufAnfrage
                },
                idleTimer: { [unowned self] in idleZustand = $0 },
                idleTimerStand: { [unowned self] in idleVorher })
        }

        /// Ruhig stehen, bis der Countdown durch ist und der Satz laeuft.
        func bisSatz() {
            while t < 1000, modell.ablauf?.schritt != .satz {
                quelle.liefere(t: t, skelett: KameraAblaufModellTests.skelett(knie: KameraAblaufModellTests.oben))
                t += 1 / KameraAblaufModellTests.rate
            }
        }

        /// Bewegung nach der Soll-Welle ab der Los-Marke `los` fuer `sekunden`.
        func wellen(los: Double, sekunden: Double) {
            let welle = Sollwelle(vorgabe: KameraAblaufModellTests.tempo.vorgabe)
            let ende = los + sekunden
            while t < ende {
                let winkel = KameraAblaufModellTests.oben - KameraAblaufModellTests.hub * welle.lage(bei: max(0, t - los))
                quelle.liefere(t: t, skelett: KameraAblaufModellTests.skelett(knie: winkel))
                t += 1 / KameraAblaufModellTests.rate
            }
        }

        /// Startet den Ablauf, stellt auf und zaehlt `wiederholungen` volle Wiederholungen.
        func satzMit(wiederholungen: Int) async {
            if modell.ablauf == nil { await modell.erscheint() }
            if modell.ablauf?.schritt == .video { await modell.handyAufstellen() }
            bisSatz()
            wellen(los: t - 1 / KameraAblaufModellTests.rate, sekunden: Double(wiederholungen) * 3 + 0.5)
        }
    }

    private func warte(maximal: Double = 3, bis bedingung: () -> Bool) async {
        let ende = Date().addingTimeInterval(maximal)
        while !bedingung(), Date() < ende { try? await Task.sleep(for: .milliseconds(10)) }
    }

    // MARK: Einstieg

    @Test func videoEinstiegStartetKameraErstBeimAufstellen() async {
        let a = Aufbau(einstieg: .video)
        await a.modell.erscheint()
        #expect(a.quelle.startAufrufe == 0)
        #expect(a.modell.ablauf?.schritt == .video)
        #expect(a.modell.videoOffen)
        #expect(a.idleZustand == true)

        await a.modell.handyAufstellen()
        #expect(a.quelle.startAufrufe == 1)
        #expect(a.modell.ablauf?.schritt == .aufstellen)
        #expect(!a.modell.videoOffen)
        #expect(a.modell.ansicht == .ablauf)
    }

    @Test func aufstellenEinstiegStartetKameraSofort() async {
        let a = Aufbau(einstieg: .aufstellen)
        await a.modell.erscheint()
        #expect(a.quelle.startAufrufe == 1)
        #expect(a.modell.ablauf?.schritt == .aufstellen)
        #expect(!a.modell.videoOffen)
    }

    @Test func ohneKameravorgabeVerlaesstDerAblaufSofort() async {
        let a = Aufbau()
        a.naht.kameraStart = nil
        await a.modell.erscheint()
        #expect(a.naht.verlassen == [nil])
        #expect(a.quelle.startAufrufe == 0)
    }

    @Test func verweigerteErlaubnisZeigtHinweis() async {
        let a = Aufbau()
        a.erlaubnis = .verweigert
        await a.modell.erscheint()
        await a.modell.handyAufstellen()
        #expect(a.modell.ansicht == .erlaubnisFehlt)
        #expect(a.quelle.startAufrufe == 0)
        #expect(a.anfragen == 0)
    }

    @Test func offeneErlaubnisWirdBeimAufstellenGefragt() async {
        let a = Aufbau()
        a.erlaubnis = .offen
        await a.modell.erscheint()
        #expect(a.anfragen == 0)
        await a.modell.handyAufstellen()
        #expect(a.anfragen == 1)
        #expect(a.quelle.startAufrufe == 1)
        #expect(a.modell.ansicht == .ablauf)
    }

    @Test func schliessenWaehrendDerAnfrageStartetKeineKamera() async {
        let a = Aufbau()
        a.erlaubnis = .offen
        a.anfrageHalten = true
        await a.modell.erscheint()
        let aufstellen = Task { await a.modell.handyAufstellen() }
        await warte { a.anfrageWartet }
        a.modell.verschwindet()
        a.anfrageFreigeben()
        await aufstellen.value
        #expect(a.quelle.startAufrufe == 0)
        #expect(a.modell.ansicht == .ablauf)
    }

    @Test func szenenwechselWaehrendDerAnfrageStartetKameraNurEinmal() async {
        let a = Aufbau(einstieg: .aufstellen)
        a.erlaubnis = .offen
        a.anfrageHalten = true
        let erscheint = Task { await a.modell.erscheint() }
        await warte { a.anfrageWartet }
        a.modell.szene(aktiv: false)
        a.modell.szene(aktiv: true)
        a.anfrageFreigeben()
        await erscheint.value
        await warte { a.anfrageWartet }
        a.anfrageFreigeben()
        await warte { a.quelle.startAufrufe >= 1 }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(a.quelle.startAufrufe == 1)
    }

    @Test func abgelehnteAnfrageZeigtHinweis() async {
        let a = Aufbau()
        a.erlaubnis = .offen
        a.antwortAufAnfrage = .verweigert
        await a.modell.erscheint()
        await a.modell.handyAufstellen()
        #expect(a.modell.ansicht == .erlaubnisFehlt)
        #expect(a.quelle.startAufrufe == 0)
    }

    @Test func kameraNichtVerfuegbarZeigtHinweisOhneAbsturz() async {
        let a = Aufbau()
        a.quelle.startFehler = BildquellenFehler.nichtVerfuegbar
        await a.modell.erscheint()
        await a.modell.handyAufstellen()
        #expect(a.modell.ansicht == .kameraFehlt)
        // Der Satz bleibt erreichbar: ohne Kamera weiterzaehlen.
        a.modell.ohneKamera()
        await warte { a.naht.verlassenAufrufe == 1 }
        #expect(a.naht.verlassen == [nil])
    }

    @Test func abgebrochenerStartZeigtKeinenHinweis() async {
        let a = Aufbau()
        a.quelle.startFehler = CancellationError()
        await a.modell.erscheint()
        await a.modell.handyAufstellen()
        #expect(a.modell.ansicht == .ablauf)
    }

    @Test func kameraAusfallNachDemStartZeigtHinweisAuchBeiDoppelterMeldung() async {
        let a = Aufbau()
        await a.modell.erscheint()
        await a.modell.handyAufstellen()
        a.quelle.beiFehler?()
        a.quelle.beiFehler?()
        #expect(a.modell.ansicht == .kameraFehlt)
        #expect(!a.quelle.laeuft)
    }

    // MARK: Satzende

    @Test func satzendeSichertGenauEinmalUndZeigtRueckblick() async {
        let a = Aufbau()
        a.naht.sichernPausiert = true
        await a.satzMit(wiederholungen: 4)
        #expect(a.modell.ablauf?.wiederholungen == 4)
        async let erstes: Void = a.modell.satzBeenden()
        async let zweites: Void = a.modell.satzBeenden()
        _ = await (erstes, zweites)
        await a.modell.satzBeenden()
        #expect(a.naht.gesichert == [4])
        guard case .rueckblick(let daten) = a.modell.ansicht else { Issue.record("\(a.modell.ansicht)"); return }
        #expect(daten.wiederholungen == 4)
        #expect(daten.abgelehnt == nil)
        #expect(daten.rueckblick != nil)
        #expect(daten.tempo == Self.tempo)
        #expect(!a.quelle.laeuft)
    }

    @Test func abgelehntesSichernZeigtRueckblickMitGrund() async {
        let a = Aufbau()
        a.naht.sichernAntwort = .abgelehnt("Nicht gesichert")
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        guard case .rueckblick(let daten) = a.modell.ansicht else { Issue.record("\(a.modell.ansicht)"); return }
        #expect(daten.abgelehnt == "Nicht gesichert")
        #expect(daten.wiederholungen == 3)
        #expect(a.naht.gesichert == [3])
    }

    @Test func ohneKameraImSatzUebergibtGezaehlte() async {
        let a = Aufbau()
        await a.satzMit(wiederholungen: 2)
        a.modell.ohneKamera()
        await warte { a.naht.verlassenAufrufe == 1 }
        #expect(a.naht.verlassen == [2])
        #expect(a.naht.gesichert.isEmpty)
        #expect(!a.quelle.laeuft)
    }

    @Test func umfangKorrigierenNachtragenUndRueckblickAnpassen() async {
        let a = Aufbau()
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        a.modell.umfangKorrigieren(5)
        #expect(a.naht.nachgetragen == [5])
        guard case .rueckblick(let daten) = a.modell.ansicht else { Issue.record("\(a.modell.ansicht)"); return }
        #expect(daten.wiederholungen == 5)
        a.modell.rueckblickSchliessen()
        #expect(a.naht.abgeschlossen == 1)
    }

    // MARK: Naechster Satz

    @Test func pausenendeStartetNaechstenSatzBeimAufstellen() async {
        let a = Aufbau()
        a.naht.pauseNachSichern = Resttimer(dauer: 0.1)
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        #expect(a.quelle.startAufrufe == 1)
        await warte { a.modell.ansicht == .ablauf && a.quelle.startAufrufe == 2 }
        #expect(a.naht.pausenEnden >= 1)
        #expect(a.modell.ansicht == .ablauf)
        #expect(a.modell.ablauf?.schritt == .aufstellen)
        #expect(a.quelle.laeuft)
    }

    @Test func naechsterSatzInDerPauseBeendetSieUndStartetAufstellen() async {
        let a = Aufbau()
        a.naht.pauseNachSichern = Resttimer(dauer: 60)
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        await a.modell.naechsterSatz()
        #expect(a.naht.pausenEnden == 1)
        #expect(a.naht.weitereSaetze == 0)
        #expect(a.modell.ablauf?.schritt == .aufstellen)
        #expect(a.quelle.startAufrufe == 2)
    }

    @Test func weitererSatzNachDemLetztenSatz() async {
        let a = Aufbau()
        a.naht.sichernAntwort = .gesichert(letzterSatz: true)
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        await a.modell.naechsterSatz()
        #expect(a.naht.weitereSaetze == 1)
        // Die neue Pause des Geraets ist beendet, sonst wuerde der naechste Satz abgelehnt.
        #expect(a.naht.pausenEnden == 1)
        #expect(a.naht.laufendePause == nil)
        #expect(a.modell.ablauf?.schritt == .aufstellen)
        // Der Zusatzsatz wird gesichert, nicht von einer Pause abgelehnt.
        await a.satzMit(wiederholungen: 1)
        await a.modell.satzBeenden()
        #expect(a.naht.gesichert == [3, 1])
        guard case .rueckblick(let daten) = a.modell.ansicht else { Issue.record("\(a.modell.ansicht)"); return }
        #expect(daten.abgelehnt == nil)
    }

    @Test func pausenendeStartetNaechstenSatzAuchWennDieNahtSieSchonAlsAbgelaufenMeldet() async {
        let a = Aufbau()
        a.naht.pauseNachSichern = Resttimer(dauer: 0.15)
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        #expect(a.naht.laufendePause != nil)
        await warte { a.quelle.startAufrufe == 2 }
        #expect(a.naht.laufendePause == nil)
        #expect(a.naht.pausenEnden >= 1)
        #expect(a.modell.ablauf?.schritt == .aufstellen)
    }

    @Test func wiederkehrDerAnsichtWaehrendDesRueckblicksBehaeltIhn() async {
        let a = Aufbau()
        a.naht.pauseNachSichern = Resttimer(dauer: 60)
        await a.satzMit(wiederholungen: 3)
        await a.modell.satzBeenden()
        await a.modell.erscheint()
        guard case .rueckblick = a.modell.ansicht else { Issue.record("\(a.modell.ansicht)"); return }
        #expect(a.naht.gesichert == [3])
    }

    @Test func hubWirdGemerktUndBeimNaechstenSatzGenutzt() async {
        let a = Aufbau()
        a.naht.pauseNachSichern = Resttimer(dauer: 60)
        await a.satzMit(wiederholungen: 4)
        await a.modell.satzBeenden()
        let erster = a.speicher.hub("e1")
        #expect(abs((erster ?? 0) - Self.hub) < 10)

        // Ein Hub fuer genau diese Uebung: der Merker gehoert nur ihr.
        #expect(a.speicher.hub("andere") == nil)
        a.speicher.merken(85, fuer: "e1")
        await a.modell.naechsterSatz()
        // Mit gemerktem Hub meldet schon eine einzige Wiederholung einen Hub; sonst bliebe 85 stehen.
        await a.satzMit(wiederholungen: 1)
        await a.modell.satzBeenden()
        #expect(a.naht.gesichert == [4, 1])
        #expect(a.speicher.hub("e1") != 85)
    }

    // MARK: Lebenszyklus

    @Test func hintergrundStopptKameraUndPausiert() async {
        let a = Aufbau()
        await a.satzMit(wiederholungen: 1)
        #expect(a.modell.ablauf?.schritt == .satz)
        a.modell.szene(aktiv: false)
        #expect(!a.quelle.laeuft)
        #expect(a.modell.ablauf?.schritt == .verloren)

        a.modell.szene(aktiv: true)
        await warte { a.quelle.laeuft }
        #expect(a.quelle.laeuft)
        #expect(a.quelle.startAufrufe == 2)
    }

    @Test func hintergrundImVideoStartetKeineKamera() async {
        let a = Aufbau()
        await a.modell.erscheint()
        a.modell.szene(aktiv: false)
        a.modell.szene(aktiv: true)
        await Task.yield()
        #expect(a.quelle.startAufrufe == 0)
    }

    @Test func verschwindetStopptKameraUndGibtDenBildschirmFrei() async {
        let a = Aufbau()
        await a.modell.erscheint()
        await a.modell.handyAufstellen()
        a.modell.verschwindet()
        #expect(!a.quelle.laeuft)
        #expect(a.idleZustand == false)
    }

    @Test func verschwindetStelltDenFruehherenIdleTimerWiederHer() async {
        let a = Aufbau()
        a.idleVorher = true
        await a.modell.erscheint()
        #expect(a.idleZustand == true)
        a.modell.verschwindet()
        #expect(a.idleZustand == true)
    }

    @Test func verweigerteErlaubnisZeigtSchonImVideoDenWegInDieEinstellungen() async {
        let a = Aufbau(einstieg: .video)
        a.erlaubnis = .verweigert
        await a.modell.erscheint()
        #expect(a.modell.ansicht == .erlaubnisFehlt)
        #expect(a.quelle.startAufrufe == 0)

        a.erlaubnis = .erlaubt
        a.modell.szene(aktiv: true)
        await Task.yield()
        #expect(a.modell.ansicht == .ablauf)
        #expect(a.modell.ablauf?.schritt == .video)
        #expect(a.quelle.startAufrufe == 0)
    }
}
