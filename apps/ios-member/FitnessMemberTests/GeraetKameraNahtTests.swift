import Foundation
import Koerperbild
import Sensorik
import Testing
@testable import FitnessMember

/// Die Naht, durch die der Kamera-Ablauf einen gezaehlten Satz an das
/// Geraete-Modell uebergibt. Der Ablauf selbst hat eigene Tests.
@MainActor
struct GeraetKameraNahtTests {
    private static let kameraJson = #""kamera":{"profil":"oberkoerper","signal":"ellbogen","seite":"beide","beginntMit":"senken"}"#

    private static func maschine(uebung: String) -> BootstrapResponse.Machine {
        GeraetTestdaten.dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Kurzhantel","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[\(uebung)]}
        """)
    }

    /// Eine Wiederholungsuebung mit Kameraprofil und Geraetelabel.
    private static var mitKamera: BootstrapResponse.Machine {
        maschine(uebung: #"{"id":"e1","name":"Curl","geraetLabel":"Kurzhantel","volumeKind":"reps","targetMin":8,"targetMax":12,"# + kameraJson + "}")
    }

    private static let startwerte = Startwerte(belastung: 10, umfang: 10, nebenbelastung: nil)

    private struct Aufbau {
        let sut: GeraetModel
        let sessions: WorkoutSessionStore
        let writes: Erfassungswarteschlange
    }

    private func aufbau(maschine: BootstrapResponse.Machine = GeraetKameraNahtTests.mitKamera,
                        startwerte: Startwerte? = GeraetKameraNahtTests.startwerte,
                        sessions: WorkoutSessionStore? = nil,
                        zaehler: (any SatzZaehler)? = nil,
                        satzZiel: Int = 3) -> Aufbau {
        let store = sessions ?? WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        let writes = Erfassungswarteschlange()
        let sut = GeraetModelTests().modell(
            maschine: maschine, bootstrap: GeraetTestdaten.bootstrap(lastSets: []), sessions: store,
            enqueue: { writes.geschriebene.append($0) }, satzZiel: satzZiel, zaehler: zaehler,
            startwerte: startwerte)
        return Aufbau(sut: sut, sessions: store, writes: writes)
    }

    @Test func kameraUebungStartetOhneCountdownMitOffenemAblauf() {
        let sut = aufbau().sut
        #expect(sut.phase == .eingabe)
        #expect(sut.kameraWahl == .mitKamera)
        #expect(sut.kameraEinstieg == .video)
        #expect(sut.kameraAblaufOffen)
        let start = sut.kameraStart
        #expect(start?.exerciseId == "e1")
        #expect(start?.name == "Curl")
        #expect(start?.geraet == "Kurzhantel")
        #expect(start?.vorgabe.profil == .oberkoerper)
        #expect(start?.tempo == .standard(beginntMit: .senken))
        #expect(start?.sollWiederholungen == 10)
        #expect(start?.satzZiel == 3)
    }

    @Test func ohneProfilZeitUebungUndZirkelBleibenWieHeute() {
        func countdownLaeuft(_ sut: GeraetModel) -> Bool {
            if case .bereit = sut.phase { return true }
            return false
        }
        // Ohne Profil: der Server liefert kein kamera.
        let ohneProfil = aufbau(maschine: GeraetTestdaten.maschine).sut
        #expect(ohneProfil.kameraStart == nil)
        #expect(countdownLaeuft(ohneProfil))
        #expect(!ohneProfil.kameraAblaufOffen)
        #expect(ohneProfil.kameraWahl == .keine)

        // Profil ohne_kamera.
        let ohneKameraProfil = aufbau(maschine: Self.maschine(
            uebung: #"{"id":"e1","name":"Curl","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"ohne_kamera","signal":null,"seite":null,"beginntMit":"heben"}}"#)).sut
        #expect(ohneKameraProfil.kameraStart == nil)
        #expect(countdownLaeuft(ohneKameraProfil))

        // Zeituebung mit kamera im Katalog: keine Wiederholungen, keine Kamera.
        let zeit = aufbau(maschine: Self.maschine(
            uebung: #"{"id":"e1","name":"Halten","volumeKind":"seconds","targetMin":30,"targetMax":60,"# + Self.kameraJson + "}")).sut
        #expect(zeit.kameraStart == nil)
        #expect(countdownLaeuft(zeit))
        #expect(!zeit.kameraAblaufOffen)

        // Zirkel: der Hook ist gesetzt, bevor der Drawer startet.
        let zirkel = aufbau(startwerte: nil).sut
        zirkel.beiZirkelSatzGesichert = {}
        zirkel.uebungStarten(mit: Self.startwerte)
        #expect(zirkel.kameraStart == nil)
        #expect(countdownLaeuft(zirkel))
        #expect(!zirkel.kameraAblaufOffen)
        #expect(zirkel.kameraWahl == .keine)
    }

    @Test func kameraSatzWirdMitGezaehlterZahlEingegebenGesichert() async {
        let a = aufbau()
        let ergebnis = await a.sut.kameraSatzSichern(wiederholungen: 7)
        #expect(ergebnis == .gesichert(letzterSatz: false))
        #expect(a.writes.geschriebene.count == 1)
        #expect(a.writes.geschriebene.first?.body.volume == 7)
        #expect(a.writes.geschriebene.first?.body.volumeSource == .eingegeben)
        #expect(a.writes.geschriebene.first?.body.volumeCounted == nil)
        #expect(a.sut.umfang == 7)
        #expect(a.sut.laufendePause != nil)
        // Der Rueckblick folgt: der Ablauf bleibt offen.
        #expect(a.sut.kameraAblaufOffen)
    }

    @Test func letzterSatzMeldetDasSatzziel() async {
        let a = aufbau(satzZiel: 1)
        #expect(await a.sut.kameraSatzSichern(wiederholungen: 6) == .gesichert(letzterSatz: true))
        #expect(a.sut.phase == .abschluss)
    }

    /// Wie `einGeraetAusEinemAnderenStudioSchreibtNichtInDieEinheit`: die
    /// Einheit laeuft in s2, das Geraet steht in s1.
    @Test func kameraSatzAbgelehntMeldetGrund() async {
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let a = aufbau(sessions: sessions)
        let ergebnis = await a.sut.kameraSatzSichern(wiederholungen: 7)
        guard case .abgelehnt(let grund) = ergebnis else {
            Issue.record("Erwartet: abgelehnt, war \(ergebnis)")
            return
        }
        #expect(grund == a.sut.satzAbgelehnt)
        #expect(!grund.isEmpty)
        #expect(a.writes.geschriebene.isEmpty)
        #expect(a.sut.gesicherteSaetze == 0)
        // Der Rueckblick erscheint trotzdem.
        #expect(a.sut.kameraAblaufOffen)
    }

    @Test func sensorAutomatikIstImKameraSatzStill() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(3)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        sessions.trainingStarten()
        // Ohne Startwerte: der Sensor beginnt, die Kamera kommt erst danach dazu.
        let a = aufbau(startwerte: nil, sessions: sessions, zaehler: double)
        a.sut.belastungGewaehlt(42.5)
        a.sut.automatikVorbereiten()
        let kennung = UUID()
        double.automatikMelde?(.begonnen(kennung: kennung, beginn: 10, bewegung: 14))
        #expect(a.sut.phase == .eingabe)
        a.sut.kameraWiederAufnehmen()

        double.automatikMelde?(.beendet(kennung: kennung, bewegung: 26))
        await Task.yield()
        #expect(a.writes.geschriebene.isEmpty)

        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        #expect(a.writes.geschriebene.count == 1)
        #expect(a.writes.geschriebene.first?.body.volume == 7)
        #expect(a.writes.geschriebene.first?.body.volumeSource == .eingegeben)
        #expect(a.writes.geschriebene.first?.body.volumeCounted == nil)
        #expect(a.writes.geschriebene.first?.body.repEvents == nil)
        #expect(double.ergebnisAufrufe == 0)
    }

    @Test func kameraSatzBeendetEinenSchonZaehlendenSensor() async {
        let double = ZaehlerDouble()
        let a = aufbau(startwerte: nil, zaehler: double)
        a.sut.geraetGeoeffnet()
        a.sut.kameraWiederAufnehmen()
        let vorher = double.verworfen
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        #expect(double.verworfen == vorher + 1)
        #expect(double.ergebnisAufrufe == 0)
    }

    @Test func zweiterKameraSatzDerselbenPauseIstAbgelehntUndSchreibtNichts() async {
        let a = aufbau()
        #expect(await a.sut.kameraSatzSichern(wiederholungen: 7) == .gesichert(letzterSatz: false))
        #expect(await a.sut.kameraSatzSichern(wiederholungen: 9) == .abgelehnt("Satz ist schon gesichert."))
        #expect(a.writes.geschriebene.count == 1)
        // Der abgelehnte Versuch laesst Umfang und Satz des ersten unberuehrt.
        #expect(a.sut.umfang == 7)
    }

    @Test func kameraSatzInEinerFremdenPauseBeendetSieUndSichert() async {
        let a = aufbau(satzZiel: 1)
        #expect(await a.sut.kameraSatzSichern(wiederholungen: 7) == .gesichert(letzterSatz: true))
        a.sut.weitererSatz()
        #expect(a.sut.laufendePause != nil)
        #expect(await a.sut.kameraSatzSichern(wiederholungen: 9) == .gesichert(letzterSatz: true))
        #expect(a.writes.geschriebene.count == 2)
    }

    @Test func weitererKameraSatzNachDemLetztenSatzWirdGesichert() async {
        let a = aufbau(satzZiel: 1)
        #expect(await a.sut.kameraSatzSichern(wiederholungen: 7) == .gesichert(letzterSatz: true))
        a.sut.weitererSatz()
        #expect(a.sut.laufendePause != nil)
        if case .abgelehnt = await a.sut.kameraSatzSichern(wiederholungen: 6) { Issue.record("abgelehnt") }
        #expect(a.writes.geschriebene.count == 2)
        #expect(a.writes.geschriebene.last?.body.volume == 6)
    }

    @Test func umfangNachtragenNachAbgelehntemKameraSatzTutNichts() async {
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let a = aufbau(sessions: sessions)
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        a.sut.umfangNachtragen(8)
        #expect(a.writes.geschriebene.isEmpty)
    }

    @Test func kameraSatzStartetDenSensorNicht() {
        let double = ZaehlerDouble()
        let a = aufbau(zaehler: double)
        #expect(a.sut.kameraWahl == .mitKamera)
        #expect(double.kontexte.isEmpty)
    }

    @Test func ohneKameraWeiterzaehlenStelltRadUndSichertNicht() {
        let double = ZaehlerDouble()
        // Der Sensor lief schon, als die Kamera dazukam.
        let a = aufbau(startwerte: nil, zaehler: double)
        a.sut.geraetGeoeffnet()
        #expect(double.melde != nil)
        a.sut.kameraWiederAufnehmen()

        a.sut.kameraVerlassen(gezaehlt: 5)

        #expect(a.sut.kameraWahl == .ohneKamera)
        #expect(!a.sut.kameraAblaufOffen)
        #expect(a.sut.umfang == 5)
        #expect(a.sut.zaehlerZustand == .vonHand(5))
        #expect(a.writes.geschriebene.isEmpty)
        // Der Sensor bleibt fuer diesen Satz still.
        double.melde?(.stand(2))
        #expect(a.sut.umfang == 5)
        #expect(a.sut.zaehlerZustand == .vonHand(5))
    }

    @Test func nachOhneKameraZaehltDerSensorImNaechstenSatzWieder() async {
        let double = ZaehlerDouble()
        let a = aufbau(zaehler: double)
        a.sut.kameraVerlassen(gezaehlt: 6)
        await a.sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(a.writes.geschriebene.first?.body.volume == 6)
        #expect(double.kontexte.isEmpty)

        a.sut.pauseBeenden()

        #expect(double.kontexte.count == 1)
        #expect(!a.sut.kameraAblaufOffen)
    }

    @Test func pausenendeOeffnetAblaufBeimAufstellen() async {
        let a = aufbau()
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        a.sut.kameraAblaufSchliessen()
        #expect(!a.sut.kameraAblaufOffen)

        a.sut.pauseBeenden()

        #expect(a.sut.phase == .eingabe)
        #expect(a.sut.kameraAblaufOffen)
        #expect(a.sut.kameraEinstieg == .aufstellen)
        // Doppelter Aufruf bleibt wirkungslos.
        a.sut.kameraAblaufSchliessen()
        a.sut.pauseBeenden()
        #expect(!a.sut.kameraAblaufOffen)
    }

    @Test func weitererSatzNachAbschlussOeffnetAblaufBeimAufstellen() async {
        let a = aufbau(satzZiel: 1)
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        #expect(a.sut.phase == .abschluss)
        a.sut.kameraAblaufSchliessen()

        a.sut.weitererSatz()

        #expect(a.sut.kameraAblaufOffen)
        #expect(a.sut.kameraEinstieg == .aufstellen)
    }

    @Test func pausenendeNachOhneKameraOeffnetNichts() async {
        let a = aufbau()
        a.sut.kameraVerlassen(gezaehlt: nil)
        await a.sut.satzSichern(problemFlag: false, problemReason: nil)

        a.sut.pauseBeenden()

        #expect(a.sut.phase == .eingabe)
        #expect(!a.sut.kameraAblaufOffen)
        #expect(a.sut.kameraWahl == .ohneKamera)
    }

    @Test func rueckblickSchliessenLaesstKameraWahl() async {
        let a = aufbau()
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        a.sut.kameraAblaufSchliessen()
        #expect(!a.sut.kameraAblaufOffen)
        #expect(a.sut.kameraWahl == .mitKamera)
    }

    @Test func mitKameraAusDerPauseBeendetPauseUndOeffnet() async {
        let a = aufbau()
        a.sut.kameraVerlassen(gezaehlt: nil)
        await a.sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(a.sut.laufendePause != nil)

        a.sut.kameraWiederAufnehmen()

        #expect(a.sut.phase == .eingabe)
        #expect(a.sut.kameraWahl == .mitKamera)
        #expect(a.sut.kameraEinstieg == .aufstellen)
        #expect(a.sut.kameraAblaufOffen)
    }

    @Test func uebungWechselnSetztKameraWahlZurueck() {
        let a = aufbau()
        a.sut.uebungWechseln(zu: "e1")
        #expect(a.sut.kameraWahl == .keine)
        #expect(!a.sut.kameraAblaufOffen)
        #expect(a.sut.kameraStart?.sollWiederholungen == nil)
    }

    @Test func umfangNachtragenSchicktDenLetztenSatzErneut() async {
        let a = aufbau()
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        let erster = a.writes.geschriebene[0]

        a.sut.umfangNachtragen(8)

        #expect(a.writes.geschriebene.count == 2)
        #expect(a.writes.geschriebene[1].setId == erster.setId)
        #expect(a.writes.geschriebene[1].sessionId == erster.sessionId)
        #expect(a.writes.geschriebene[1].body.volume == 8)
        #expect(a.writes.geschriebene[1].body.volumeSource == .eingegeben)
        #expect(a.writes.geschriebene[1].body.load == erster.body.load)
        #expect(a.sessions.aktiveSession()?.bloecke.first?.saetze.first?.volume == 8)
    }

    @Test func umfangNachtragenUnterEinsTutNichts() async {
        let a = aufbau()
        _ = await a.sut.kameraSatzSichern(wiederholungen: 7)
        a.sut.umfangNachtragen(0)
        a.sut.umfangNachtragen(-3)
        #expect(a.writes.geschriebene.count == 1)
        #expect(a.sessions.aktiveSession()?.bloecke.first?.saetze.first?.volume == 7)
    }

    @Test func umfangNachtragenOhneSatzTutNichts() {
        let a = aufbau()
        a.sut.umfangNachtragen(8)
        #expect(a.writes.geschriebene.isEmpty)
    }
}

@MainActor
struct WorkoutSessionStoreUmfangNachtragenTests {
    @Test func nachtragErsetztVolumeBehaeltRirUndSetId() {
        let store = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        let station = Station.testGeraet("m1")
        var geschrieben = store.satzSichern(
            station: station, exerciseId: "e1", einheiten: .kilogrammWiederholungen,
            load: 20, volume: 7, problemFlag: false, problemReason: nil)
        geschrieben.body.volumeSource = .eingegeben
        let blockId = LokalerBlock.kennung(stationSchluessel: station.schluessel, exerciseId: "e1")
        let write = PendingSetWrite(sessionId: geschrieben.sessionId, setId: geschrieben.setId, body: geschrieben.body)
        var eingereiht: [PendingSetWrite] = []
        store.satzEinreihen(write, blockId: blockId, enqueue: { eingereiht.append($0) })
        store.reserveNachtragen(blockId: blockId, reserve: .wert(2), enqueue: { eingereiht.append($0) })

        store.umfangNachtragen(blockId: blockId, umfang: 9, enqueue: { eingereiht.append($0) })

        #expect(eingereiht.count == 3)
        #expect(eingereiht[2].setId == write.setId)
        #expect(eingereiht[2].body.volume == 9)
        #expect(eingereiht[2].body.rir == 2)
        #expect(store.letzterWrite(blockId: blockId)?.body.volume == 9)

        // Ein spaeterer Reserve-Nachtrag baut auf dem neuen Umfang auf.
        store.reserveNachtragen(blockId: blockId, reserve: .wert(1), enqueue: { eingereiht.append($0) })
        #expect(eingereiht[3].body.volume == 9)
        #expect(eingereiht[3].body.rir == 1)
    }

    @Test func ohneLetztenWriteGeschiehtNichts() {
        let store = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        var eingereiht: [PendingSetWrite] = []
        store.umfangNachtragen(blockId: "gibt-es-nicht", umfang: 9, enqueue: { eingereiht.append($0) })
        #expect(eingereiht.isEmpty)
    }
}
