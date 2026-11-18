import Foundation
import Testing
@testable import FitnessMember

/// "Welche Übung?" im Mini-Zirkel (Testnotiz 10.11., #14): Favorit und
/// Untertitel kommen wie im freien Training aus der Historie an der Station,
/// nicht nur aus den Saetzen von heute.
struct ZirkelUebungswahlTests {

    /// 10.11.2026, 12:00 UTC.
    private let jetzt = Date(timeIntervalSince1970: 1_794_312_000)

    private func uebung(_ id: String) -> GeraetUebung {
        GeraetUebung(id: id, name: "Übung \(id)", volumeKind: .reps, targetMin: 8, targetMax: 12, videoURL: nil)
    }

    private func bootstrap(lastSets: [BootstrapResponse.LastSet] = [],
                           lastTypeSets: [BootstrapResponse.LastTypeSet] = []) -> BootstrapResponse {
        BootstrapResponse(member: .init(displayName: nil), studios: [], machines: [], calibrations: [],
                          lastSets: lastSets, lastTypeSets: lastTypeSets)
    }

    private func typsatz(_ modell: String, _ uebung: String, load: Double = 10,
                         am datum: String = "2026-11-07T10:00:00Z") -> BootstrapResponse.LastTypeSet {
        BootstrapResponse.LastTypeSet(equipmentModelId: modell, exerciseId: uebung, load: load, secondaryLoad: nil,
                                      volume: 10, rir: nil, performedAt: datum)
    }

    private func geraetesatz(_ maschine: String, _ uebung: String) -> BootstrapResponse.LastSet {
        BootstrapResponse.LastSet(machineId: maschine, exerciseId: uebung, load: 40, secondaryLoad: nil, volume: 10,
                                  rir: nil, performedAt: "2026-11-07T10:00:00Z")
    }

    @Test func typsatzMachtFavorit() {
        let station = Station.testTyp("t1")
        let daten = bootstrap(lastTypeSets: [typsatz("t1", "e1")])
        let mit = ZirkelUebungswahl.untertitel(uebung("e1"), station: station, bloecke: [],
                                               bootstrap: daten, jetzt: jetzt)
        #expect(mit.text == "vor 3 Tagen · 10,0 kg")
        #expect(mit.hatHistorie)
        let ohne = ZirkelUebungswahl.untertitel(uebung("e2"), station: station, bloecke: [],
                                                bootstrap: daten, jetzt: jetzt)
        #expect(ohne.text == "Noch nie · Ziel 8 – 12 Wdh.")
        #expect(!ohne.hatHistorie)
    }

    @Test func geraetesatzZaehltNurAmGeraet() {
        // Ein Geraetesatz zaehlt nicht fuer einen Typ mit gleicher Kennung.
        let amTyp = ZirkelUebungswahl.untertitel(uebung("e1"), station: .testTyp("t1"), bloecke: [],
                                                 bootstrap: bootstrap(lastSets: [geraetesatz("t1", "e1")]),
                                                 jetzt: jetzt)
        #expect(!amTyp.hatHistorie)
        let amGeraet = ZirkelUebungswahl.untertitel(uebung("e1"), station: .testGeraet("g1"), bloecke: [],
                                                    bootstrap: bootstrap(lastSets: [geraetesatz("g1", "e1")]),
                                                    jetzt: jetzt)
        #expect(amGeraet.hatHistorie)
        #expect(amGeraet.text == "vor 3 Tagen · 40,0 kg")
    }

    @Test func heuteGehtVor() {
        let station = Station.testGeraet("g1")
        let satz = LokalerSatz(id: UUID(), setIndex: 1, load: 12.5, volume: 10, rir: nil,
                               problemFlag: false, problemReason: nil, performedAt: jetzt)
        let block = LokalerBlock(machineId: "g1", exerciseId: "e1", saetze: [satz])
        let ergebnis = ZirkelUebungswahl.untertitel(uebung("e1"), station: station, bloecke: [block],
                                                    bootstrap: nil, jetzt: jetzt)
        #expect(ergebnis.text == "Heute · \(TrainingTab.blockzeile(block))")
        #expect(ergebnis.hatHistorie)
    }

    @Test func alterTexte() {
        #expect(UebungsHistorie.alter(tage: 0) == "heute")
        #expect(UebungsHistorie.alter(tage: 1) == "vor 1 Tag")
        #expect(UebungsHistorie.alter(tage: 8) == "vor 8 Tagen")
    }
}
