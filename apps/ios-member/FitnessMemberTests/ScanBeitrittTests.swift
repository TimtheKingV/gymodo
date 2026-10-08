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

    // MARK: - nachBeitritt

    /// joinStudio hat den Ort schon gewechselt; `vorher` ist der Ort vor dem
    /// Beitritt, an dem eine offene Einheit laufen kann.
    @Test func nachDemBeitrittOeffnetSichDasGeraet() {
        let m = maschine(studioId: "s2")
        let ergebnis = JoinResult(studioId: "s2", machineId: "m1", joined: true)
        #expect(ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: bootstrap([m]),
                                              vorher: .studio("s1"), offeneEinheit: nil)
                == .oeffnen(Station(maschine: m)))
    }

    @Test func einAushangZeigtDieListeDesStudios() {
        let ergebnis = JoinResult(studioId: "s2", machineId: nil, joined: true)
        #expect(ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: bootstrap([]),
                                              vorher: .freiesTraining, offeneEinheit: nil)
                == .listeZeigen)
    }

    /// Beitritt passiert immer, das Geraet erst nach "Training beenden".
    @Test func nachDemBeitrittFragtEineEinheitAnEinemAnderenOrt() {
        let m = maschine(studioId: "s2")
        let mitGeraet = JoinResult(studioId: "s2", machineId: "m1", joined: true)
        #expect(ScanEntscheidung.nachBeitritt(mitGeraet, bootstrap: bootstrap([m]),
                                              vorher: .studio("s1"), offeneEinheit: einheit(ort: .studio("s1")))
                == .erstBeenden(laufenderOrt: .studio("s1"), station: Station(maschine: m)))
        let aushang = JoinResult(studioId: "s2", machineId: nil, joined: true)
        #expect(ScanEntscheidung.nachBeitritt(aushang, bootstrap: bootstrap([]),
                                              vorher: .studio("s1"), offeneEinheit: einheit(ort: .studio("s1")))
                == .erstBeenden(laufenderOrt: .studio("s1"), station: nil))
    }

    /// Kennt das frische Bootstrap das Geraet nicht (Nachladen gescheitert),
    /// bleibt wenigstens die Liste des Studios.
    @Test func einUnbekanntesGeraetNachDemBeitrittZeigtDieListe() {
        let ergebnis = JoinResult(studioId: "s2", machineId: "m9", joined: false)
        #expect(ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: nil,
                                              vorher: .studio("s1"), offeneEinheit: nil)
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
