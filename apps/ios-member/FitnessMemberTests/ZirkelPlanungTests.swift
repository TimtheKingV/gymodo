import Foundation
import Testing
@testable import FitnessMember

/// Die Planung vor dem Start (Spec 21.10., Entscheidungen 1-4): Entwurf und
/// die Wahl der Uebung, wenn ein Geraet hinzukommt. Beides ohne UI.
struct ZirkelPlanungTests {
    private func uebung(_ i: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:g\(i)", exerciseId: "e\(i)", token: nil)
    }

    private func entwurf(n: Int, runden: Int = 3) -> ZirkelEntwurf {
        ZirkelEntwurf(uebungen: (0..<n).map { uebung($0 + 1) }, runden: runden,
                      uebungspause: 20, rundenpause: 90)
    }

    // MARK: - Entwurf

    @Test func mitEinerUebungIstErUngueltig() {
        #expect(!entwurf(n: 1).istGueltig)
        #expect(!entwurf(n: 0).istGueltig)
    }

    @Test func mitZweiUebungenIstErGueltig() {
        #expect(entwurf(n: 2).istGueltig)
    }

    @Test func rundenAusserhalbVonZweiBisSechsSindUngueltig() {
        #expect(!entwurf(n: 3, runden: 1).istGueltig)
        #expect(!entwurf(n: 3, runden: 7).istGueltig)
        #expect(entwurf(n: 3, runden: 2).istGueltig)
        #expect(entwurf(n: 3, runden: 6).istGueltig)
    }

    @Test func verschiebeAendertDieReihenfolge() {
        var e = entwurf(n: 3)
        // Wie List.onMove: die erste ans Ende.
        e.verschiebe(von: IndexSet(integer: 0), nach: 3)
        #expect(e.uebungen == [uebung(2), uebung(3), uebung(1)])
    }

    @Test func entferneNimmtDieUebungRaus() {
        var e = entwurf(n: 3)
        e.entferne(at: IndexSet(integer: 1))
        #expect(e.uebungen == [uebung(1), uebung(3)])
    }

    @Test func hinzufuegenHaengtAnAberNichtDoppelt() {
        var e = entwurf(n: 1)
        let neu = e.hinzufuegen(uebung(2))
        let doppelt = e.hinzufuegen(uebung(1))
        #expect(neu)
        #expect(!doppelt)
        #expect(e.uebungen == [uebung(1), uebung(2)])
    }

    @Test func standardpausenKommenAusDenEinstellungen() {
        let defaults = UserDefaults(suiteName: "zirkel-planung-tests-\(UUID().uuidString)")!
        defaults.set(45, forKey: Einstellungen.zirkelPauseSekundenKey)
        defaults.set(120, forKey: Einstellungen.resttimerSekundenKey)
        let e = ZirkelEntwurf(uebungen: [uebung(1)], defaults: defaults)
        #expect(e.uebungspause == 45)
        #expect(e.rundenpause == 120)
        #expect(e.runden == 3)
    }

    @Test func ohneGesetzteEinstellungGeltenDieVorgaben() {
        let defaults = UserDefaults(suiteName: "zirkel-planung-tests-\(UUID().uuidString)")!
        let e = ZirkelEntwurf(uebungen: [], defaults: defaults)
        #expect(e.uebungspause == Einstellungen.zirkelPauseVorgabe)
        #expect(e.rundenpause == Einstellungen.resttimerVorgabe)
    }

    @Test func zirkelUebernimmtAllesUndBeginntBeiNull() {
        var e = entwurf(n: 3, runden: 4)
        e.uebungspause = 30
        e.rundenpause = 60
        let z = e.zirkel()
        #expect(z.uebungen == e.uebungen)
        #expect(z.runden == 4)
        #expect(z.uebungspause == 30)
        #expect(z.rundenpause == 60)
        #expect(z.schritt == 0)
    }

    // MARK: - Auswahl

    @Test func auswahlNimmtDieUebergebeneUebung() {
        let station = Self.station(uebungen: ["e1", "e2", "e3"])
        let gewaehlt = ZirkelAuswahl.uebung(station: station, uebungId: "e3",
                                            bootstrap: Self.bootstrap(letzte: "e2"))
        #expect(gewaehlt == ZirkelUebung(station: "geraet:m1", exerciseId: "e3", token: nil))
    }

    @Test func auswahlNimmtSonstDieZuletztGenutzte() {
        let station = Self.station(uebungen: ["e1", "e2", "e3"])
        let gewaehlt = ZirkelAuswahl.uebung(station: station, uebungId: nil,
                                            bootstrap: Self.bootstrap(letzte: "e2"))
        #expect(gewaehlt?.exerciseId == "e2")
    }

    @Test func auswahlNimmtSonstDieErste() {
        let station = Self.station(uebungen: ["e1", "e2", "e3"])
        let gewaehlt = ZirkelAuswahl.uebung(station: station, uebungId: nil,
                                            bootstrap: Self.bootstrap(letzte: nil))
        #expect(gewaehlt?.exerciseId == "e1")
    }

    @Test func einGeraetOhneUebungGibtNichts() {
        let station = Self.station(uebungen: [])
        #expect(ZirkelAuswahl.uebung(station: station, uebungId: nil,
                                     bootstrap: Self.bootstrap(letzte: nil)) == nil)
    }

    // MARK: - Testdaten

    private static func station(uebungen: [String]) -> Station {
        let liste = uebungen.map {
            #"{"id":"\#($0)","name":"Übung \#($0)","volumeKind":"reps","targetMin":8,"targetMax":12}"#
        }.joined(separator: ",")
        let json = """
        {"id":"m1","studioId":"s1","label":"Gerät m1",
         "locationNote":null,"status":"active","tokenHashes":["h-m1"],"visitCount":0,
         "equipmentModel":{"id":"em-m1","name":"Modell","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[\(liste)]}
        """
        return Station(maschine: GeraetTestdaten.dekodiere(json))
    }

    private static func bootstrap(letzte: String?) -> BootstrapResponse {
        BootstrapResponse(
            member: .init(displayName: nil), studios: [], machines: [], calibrations: [],
            lastSets: letzte.map {
                [BootstrapResponse.LastSet(machineId: "m1", exerciseId: $0, load: 40, secondaryLoad: nil,
                                           volume: 10, rir: nil, performedAt: "2026-09-01T10:00:00Z")]
            } ?? [])
    }
}
