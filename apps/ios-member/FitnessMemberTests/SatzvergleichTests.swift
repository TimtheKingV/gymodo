import Foundation
import Testing
@testable import FitnessMember

/// Der Fortschritt im Trainingsdetail (Testnotiz 06.10., #20): jeder Satz
/// gegen den Durchschnitt desselben Satzes aus den bis zu fuenf vorherigen
/// Trainings dieser Uebung, die Richtung nach kg x Wdh., rechts je Uebung
/// das Gesamtvolumen gegen dessen Durchschnitt.
struct SatzvergleichTests {
    private func satz(_ index: Int, _ kg: Double, _ wdh: Int) -> SessionSummary.Block.Set {
        SessionSummary.Block.Set(setIndex: index, load: kg, secondaryLoad: nil, volume: wdh, rir: nil,
                                 problemFlag: false, problemReason: nil,
                                 performedAt: "2026-10-01T10:00:00Z")
    }

    private func block(_ saetze: [(Double, Int)], uebung: String = "e1",
                       einheit: LoadUnit = .kg, umfang: VolumeKind = .reps) -> SessionSummary.Block {
        SessionSummary.Block(
            machineId: "m1", machineLabel: "Kabelzug", exerciseId: uebung, exerciseName: "Kabelzug hoch",
            loadUnit: einheit, secondaryUnit: nil, volumeKind: umfang,
            sets: saetze.enumerated().map { satz($0.offset + 1, $0.element.0, $0.element.1) })
    }

    private func einheit(_ id: String, tag: Int, _ bloecke: [SessionSummary.Block]) -> SessionSummary {
        SessionSummary(id: id, startedAt: String(format: "2026-09-%02dT10:00:00Z", tag),
                       completedAt: String(format: "2026-09-%02dT11:00:00Z", tag),
                       completedReason: "manual", machineCount: 1,
                       setCount: bloecke.flatMap(\.sets).count, blocks: bloecke)
    }

    @Test func vergleichtJedenSatzMitDemDurchschnittDesselbenSatzes() {
        // Vorher zweimal: Satz 1 je 5 kg x 8, Satz 2 je 7,5 kg x 11.
        let vorher = [
            einheit("a", tag: 1, [block([(5, 8), (7.5, 11)])]),
            einheit("b", tag: 3, [block([(5, 8), (7.5, 11)])]),
        ]
        let heute = einheit("c", tag: 5, [block([(7.5, 10), (7.5, 10)])])

        let vergleich = Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: vorher + [heute])

        // Das Beispiel aus der Notiz: "+2,5 kg +2 Wdh" nach oben,
        // "±0 kg −1 Wdh" nach unten.
        #expect(vergleich?.saetze[0] == .init(deltaKg: 2.5, deltaWdh: 2, trend: .hoch))
        #expect(vergleich?.saetze[1] == .init(deltaKg: 0, deltaWdh: -1, trend: .runter))
        #expect(vergleich?.basis == 2)
    }

    @Test func derPfeilFolgtDemVolumenNichtDemGewicht() {
        // 10 Wdh. x 10 kg ist mehr als 5 Wdh. x 18 kg (Beispiel aus der Notiz).
        let vorher = [einheit("a", tag: 1, [block([(18, 5)])])]
        let heute = einheit("b", tag: 2, [block([(10, 10)])])

        let vergleich = Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: vorher + [heute])

        #expect(vergleich?.saetze[0]?.trend == .hoch)
        #expect(vergleich?.saetze[0]?.deltaKg == -8)
    }

    @Test func nimmtHoechstensDieFuenfJuengstenVorherigenTrainings() {
        // Sechs vorherige; das aelteste (1 kg) darf nicht mitzaehlen.
        var vorher = [einheit("alt", tag: 1, [block([(1, 10)])])]
        for tag in 2...6 { vorher.append(einheit("v\(tag)", tag: tag, [block([(10, 10)])])) }
        let heute = einheit("heute", tag: 8, [block([(10, 10)])])
        // Ein spaeteres Training zaehlt nie als "vorher".
        let spaeter = einheit("spaeter", tag: 9, [block([(50, 10)])])

        let vergleich = Satzvergleich.fuer(block: heute.blocks[0], in: heute,
                                           verlauf: vorher + [heute, spaeter])

        #expect(vergleich?.basis == 5)
        #expect(vergleich?.saetze[0] == .init(deltaKg: 0, deltaWdh: 0, trend: .gleich))
        #expect(vergleich?.gesamt == .gleich)
    }

    @Test func einSatzOhneGegenstueckBekommtKeinenVergleich() {
        let vorher = [einheit("a", tag: 1, [block([(10, 10)])])]
        let heute = einheit("b", tag: 2, [block([(10, 10), (10, 8)])])

        let vergleich = Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: vorher + [heute])

        #expect(vergleich?.saetze[1] == nil)
        // Der zusaetzliche Satz zaehlt aber im Gesamtvolumen mit.
        #expect(vergleich?.gesamt == .hoch)
    }

    @Test func gesamttrendVergleichtDieSummeMitIhremDurchschnitt() {
        // Vorher 2 x 10 kg x 10 = 200; heute 3 x 10 kg x 6 = 180.
        let vorher = [einheit("a", tag: 1, [block([(10, 10), (10, 10)])])]
        let heute = einheit("b", tag: 2, [block([(10, 6), (10, 6), (10, 6)])])

        let vergleich = Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: vorher + [heute])

        #expect(vergleich?.gesamt == .runter)
    }

    @Test func ohneVorherigesTrainingGibtEsNichtsZuVergleichen() {
        let heute = einheit("b", tag: 2, [block([(10, 10)])])
        #expect(Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: [heute]) == nil)
    }

    @Test func nurKilogrammMalWiederholungen() {
        // Laufband (km/h x Sekunden): "mehr Gewicht" gibt es dort nicht.
        let laufband = block([(8.5, 1200)], einheit: .kmh, umfang: .seconds)
        let vorher = [einheit("a", tag: 1, [laufband])]
        let heute = einheit("b", tag: 2, [laufband])
        #expect(Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: vorher + [heute]) == nil)
    }

    @Test func andereUebungenZaehlenNicht() {
        let vorher = [einheit("a", tag: 1, [block([(10, 10)], uebung: "e2")])]
        let heute = einheit("b", tag: 2, [block([(10, 10)])])
        #expect(Satzvergleich.fuer(block: heute.blocks[0], in: heute, verlauf: vorher + [heute]) == nil)
    }

    @Test func textMitVorzeichen() {
        #expect(Satzvergleich.kgText(2.5) == "+2,5 kg")
        #expect(Satzvergleich.kgText(0) == "±0 kg")
        #expect(Satzvergleich.kgText(-1.5) == "−1,5 kg")
        #expect(Satzvergleich.wdhText(2) == "+2 Wdh.")
        #expect(Satzvergleich.wdhText(-1) == "−1 Wdh.")
        #expect(Satzvergleich.wdhText(0) == "±0 Wdh.")
        #expect(Satzvergleich.wdhText(0.4) == "+0,4 Wdh.")
    }
}
