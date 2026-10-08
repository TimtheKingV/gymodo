import Foundation
import Testing
@testable import FitnessMember

/// Was ein Scan bewirkt, als reine Funktion: die View fuehrt nur aus.
struct ScanBeitrittTests {
    private let token = "tok-1"
    private let jetzt = Date()

    private func maschine(id: String = "m1", studioId: String) -> BootstrapResponse.Machine {
        GeraetTestdaten.dekodiere("""
        {"id":"\(id)","studioId":"\(studioId)","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":["\(MachineResolver.hash(token: token))"],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
    }

    private func bootstrap(_ maschinen: [BootstrapResponse.Machine]) -> BootstrapResponse {
        BootstrapResponse(
            member: GeraetTestdaten.dekodiere(#"{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}}"#),
            studios: [], machines: maschinen, calibrations: [], lastSets: [])
    }

    private func einheit(ort: Ort?) -> LokaleSession {
        LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [], ort: ort)
    }

    // MARK: - fuer(token:bootstrap:ort:offeneEinheit:)

    @Test func einGeraetAmAktuellenOrtOeffnetSich() {
        let m = maschine(studioId: "s1")
        let entscheidung = ScanEntscheidung.fuer(
            token: token, bootstrap: bootstrap([m]), ort: .studio("s1"), offeneEinheit: nil)
        #expect(entscheidung == .oeffnen(Station(maschine: m)))
    }

    /// Unbekannt: weder im Prefetch noch ohne Prefetch -- der Server
    /// entscheidet ueber den Beitritt (und kennt auch neue Geraete).
    @Test func einUnbekannterCodeFuehrtZumBeitritt() {
        #expect(ScanEntscheidung.fuer(token: token, bootstrap: bootstrap([]),
                                      ort: .studio("s1"), offeneEinheit: nil) == .beitreten)
        #expect(ScanEntscheidung.fuer(token: token, bootstrap: nil,
                                      ort: .studio("s1"), offeneEinheit: nil) == .beitreten)
    }

    @Test func einGeraetInEinemAnderenStudioWechseltDenOrt() {
        let m = maschine(studioId: "s2")
        #expect(ScanEntscheidung.fuer(token: token, bootstrap: bootstrap([m]),
                                      ort: .studio("s1"), offeneEinheit: nil)
                == .wechselnUndOeffnen(.studio("s2"), Station(maschine: m)))
        // Auch aus dem Freien Training heraus.
        #expect(ScanEntscheidung.fuer(token: token, bootstrap: bootstrap([m]),
                                      ort: .freiesTraining, offeneEinheit: nil)
                == .wechselnUndOeffnen(.studio("s2"), Station(maschine: m)))
    }

    @Test func eineEinheitAnEinemAnderenOrtMussErstEnden() {
        let m = maschine(studioId: "s2")
        #expect(ScanEntscheidung.fuer(token: token, bootstrap: bootstrap([m]),
                                      ort: .studio("s1"), offeneEinheit: einheit(ort: .studio("s1")))
                == .erstBeenden(laufenderOrt: .studio("s1"), ziel: .studio("s2"), station: Station(maschine: m)))
    }

    /// Eine Einheit am Ort des Geraets haelt den Scan nicht auf.
    @Test func eineEinheitAmOrtDesGeraetsOeffnetDirekt() {
        let m = maschine(studioId: "s2")
        #expect(ScanEntscheidung.fuer(token: token, bootstrap: bootstrap([m]),
                                      ort: .studio("s2"), offeneEinheit: einheit(ort: .studio("s2")))
                == .oeffnen(Station(maschine: m)))
    }

    // MARK: - fuer(station:ort:offeneEinheit:) -- Auswahl aus der Liste

    /// Die Liste geht denselben Weg wie der Scan: "Auch in X suchen" darf
    /// kein Geraet in X an der Pruefung vorbei oeffnen.
    @Test func eineGewaehlteStationAmAktuellenOrtOeffnetSich() {
        let s = Station.testGeraet("m1", studioId: "s1")
        #expect(ScanEntscheidung.fuer(station: s, ort: .studio("s1"), offeneEinheit: nil) == .oeffnen(s))
        let typ = Station.testTyp("t1", studioId: nil)
        #expect(ScanEntscheidung.fuer(station: typ, ort: .freiesTraining,
                                      offeneEinheit: einheit(ort: .freiesTraining)) == .oeffnen(typ))
    }

    @Test func eineGewaehlteStationInEinemAnderenStudioWechseltErst() {
        let geraet = Station.testGeraet("m2", studioId: "s2")
        #expect(ScanEntscheidung.fuer(station: geraet, ort: .studio("s1"), offeneEinheit: nil)
                == .wechselnUndOeffnen(.studio("s2"), geraet))
        // Der Typ unter "Auch in s2" behaelt s2: der Ort wird vor dem
        // Oeffnen gewechselt, die Route traegt nur den Schluessel.
        let typ = Station.testTyp("t1", studioId: "s2")
        #expect(ScanEntscheidung.fuer(station: typ, ort: .studio("s1"), offeneEinheit: nil)
                == .wechselnUndOeffnen(.studio("s2"), typ))
    }

    @Test func eineGewaehlteStationNebenEinerEinheitAnderswoFragtErst() {
        let geraet = Station.testGeraet("m2", studioId: "s2")
        #expect(ScanEntscheidung.fuer(station: geraet, ort: .studio("s1"),
                                      offeneEinheit: einheit(ort: .studio("s1")))
                == .erstBeenden(laufenderOrt: .studio("s1"), ziel: .studio("s2"), station: geraet))
        let typ = Station.testTyp("t1", studioId: "s2")
        #expect(ScanEntscheidung.fuer(station: typ, ort: .freiesTraining,
                                      offeneEinheit: einheit(ort: .freiesTraining))
                == .erstBeenden(laufenderOrt: .freiesTraining, ziel: .studio("s2"), station: typ))
    }

    // MARK: - nachBeitritt

    /// joinStudio wechselt den Ort nicht mehr selbst: `ort` ist der Ort, an
    /// dem das Mitglied steht und eine offene Einheit laufen kann.
    @Test func nachDemBeitrittOeffnetSichDasGeraet() {
        let m = maschine(studioId: "s2")
        let ergebnis = JoinResult(studioId: "s2", machineId: "m1", joined: true)
        #expect(ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: bootstrap([m]),
                                              ort: .studio("s1"), offeneEinheit: nil)
                == .oeffnen(Station(maschine: m)))
    }

    @Test func einAushangZeigtDieListeDesStudios() {
        let ergebnis = JoinResult(studioId: "s2", machineId: nil, joined: true)
        #expect(ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: bootstrap([]),
                                              ort: .freiesTraining, offeneEinheit: nil)
                == .listeZeigen)
    }

    /// Beitritt passiert immer, das Geraet erst nach "Training beenden".
    @Test func nachDemBeitrittFragtEineEinheitAnEinemAnderenOrt() {
        let m = maschine(studioId: "s2")
        let mitGeraet = JoinResult(studioId: "s2", machineId: "m1", joined: true)
        #expect(ScanEntscheidung.nachBeitritt(mitGeraet, bootstrap: bootstrap([m]),
                                              ort: .studio("s1"), offeneEinheit: einheit(ort: .studio("s1")))
                == .erstBeenden(laufenderOrt: .studio("s1"), station: Station(maschine: m)))
        let aushang = JoinResult(studioId: "s2", machineId: nil, joined: true)
        #expect(ScanEntscheidung.nachBeitritt(aushang, bootstrap: bootstrap([]),
                                              ort: .studio("s1"), offeneEinheit: einheit(ort: .studio("s1")))
                == .erstBeenden(laufenderOrt: .studio("s1"), station: nil))
    }

    /// Kennt das frische Bootstrap das Geraet nicht (Nachladen gescheitert),
    /// bleibt wenigstens die Liste des Studios.
    @Test func einUnbekanntesGeraetNachDemBeitrittZeigtDieListe() {
        let ergebnis = JoinResult(studioId: "s2", machineId: "m9", joined: false)
        #expect(ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: nil,
                                              ort: .studio("s1"), offeneEinheit: nil)
                == .listeZeigen)
    }

    // MARK: - Fehlertext

    @Test func einUnbekannterCodeBehaeltDenBisherigenText() {
        #expect(ScanEntscheidung.fehlertext(.notFound(message: "x"))
                == "Dieser Code ist nicht aktiv. Frag im Studio nach.")
        #expect(ScanEntscheidung.fehlertext(.validation(message: "x"))
                == "Dieser Code ist nicht aktiv. Frag im Studio nach.")
        #expect(ScanEntscheidung.fehlertext(.offline)
                == "Keine Verbindung. Der Code wurde nicht gesendet.")
    }
}
