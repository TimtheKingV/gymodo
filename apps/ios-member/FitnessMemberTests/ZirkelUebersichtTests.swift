import Foundation
import Testing
@testable import FitnessMember

/// Die gemeinsame Zirkel-Uebersicht am Ende (Spec Mini-Zirkel 21.10.,
/// Entscheidung 7 und Annahme "eine Uebersicht fuer alle Uebungen und
/// Runden"). Die Zeilen kommen aus den Bloecken der Einheit, nicht aus dem
/// Schrittzaehler des Zirkels: was gesichert ist, steht da -- auch nach
/// "Zirkel beenden" mitten in der Runde.
@MainActor
struct ZirkelUebersichtTests {

    private let start = Date(timeIntervalSince1970: 1_757_930_400)
    private let namen = ["e1": "Bizeps-Curls", "e2": "Seitheben", "e3": "Schrägbankdrücken"]

    private func uebung(_ n: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:m\(n)", exerciseId: "e\(n)", token: nil)
    }

    private func zirkel(_ anzahl: Int = 3, runden: Int = 2) -> Zirkel {
        Zirkel(uebungen: (1...anzahl).map(uebung), runden: runden, uebungspause: 20, rundenpause: 90)
    }

    private func satz(_ index: Int, load: Double, volume: Int, minuten: Double = 0) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, load: load, volume: volume, rir: nil,
                    problemFlag: false, problemReason: nil, performedAt: start.addingTimeInterval(minuten * 60))
    }

    private func name(_ uebung: ZirkelUebung) -> String { namen[uebung.exerciseId] ?? "" }

    /// Je Uebung eine Zeile in der Reihenfolge des Zirkels, je gesichertem
    /// Satz ein Text -- ueber alle Runden, nicht nur die letzte.
    @Test func dreiUebungenZweiRundenErgebenJeZweiSaetze() {
        let bloecke = [
            // Absichtlich in anderer Reihenfolge als im Zirkel: die Einheit
            // ordnet nach dem ersten Satz, die Uebersicht nach dem Zirkel.
            LokalerBlock(machineId: "m3", exerciseId: "e3", saetze: [satz(1, load: 30, volume: 8),
                                                                    satz(2, load: 32.5, volume: 8)]),
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, load: 14, volume: 10),
                                                                    satz(2, load: 14, volume: 9)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, load: 8, volume: 15),
                                                                    satz(2, load: 8, volume: 12)]),
        ]
        let zeilen = ZirkelUebersicht.zeilen(zirkel: zirkel(), bloecke: bloecke, name: name)
        #expect(zeilen == [
            ZirkelZeile(uebungsname: "Bizeps-Curls", saetze: ["14,0 kg × 10", "14,0 kg × 9"]),
            ZirkelZeile(uebungsname: "Seitheben", saetze: ["8,0 kg × 15", "8,0 kg × 12"]),
            ZirkelZeile(uebungsname: "Schrägbankdrücken", saetze: ["30,0 kg × 8", "32,5 kg × 8"]),
        ])
    }

    /// Eine uebersprungene Runde hinterlaesst keinen Satz -- sie fehlt
    /// einfach, ohne Platzhalter.
    @Test func eineUebersprungeneRundeFehltEinfach() {
        let bloecke = [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, load: 14, volume: 10),
                                                                    satz(2, load: 14, volume: 10)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, load: 8, volume: 15)]),
            LokalerBlock(machineId: "m3", exerciseId: "e3", saetze: [satz(1, load: 30, volume: 8),
                                                                    satz(2, load: 30, volume: 8)]),
        ]
        let zeilen = ZirkelUebersicht.zeilen(zirkel: zirkel(), bloecke: bloecke, name: name)
        #expect(zeilen.map(\.saetze.count) == [2, 1, 2])
        #expect(zeilen[1] == ZirkelZeile(uebungsname: "Seitheben", saetze: ["8,0 kg × 15"]))
    }

    /// Gleich beendet oder alles uebersprungen: jede Uebung steht trotzdem
    /// da, mit leerer Liste -- kein Absturz, keine verschwundene Zeile.
    @Test func ohneSaetzeStehtJedeUebungMitLeererListe() {
        let zeilen = ZirkelUebersicht.zeilen(zirkel: zirkel(), bloecke: [], name: name)
        #expect(zeilen == [
            ZirkelZeile(uebungsname: "Bizeps-Curls", saetze: []),
            ZirkelZeile(uebungsname: "Seitheben", saetze: []),
            ZirkelZeile(uebungsname: "Schrägbankdrücken", saetze: []),
        ])
    }

    /// Der Block einer Uebung kann aeltere Saetze tragen, wenn sie vor dem
    /// Zirkel schon einzeln lief. Die gehoeren nicht in die Zirkel-Uebersicht.
    @Test func saetzeVorDemZirkelZaehlenNicht() {
        let bloecke = [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, load: 20, volume: 12, minuten: 0),
                                                                    satz(2, load: 14, volume: 10, minuten: 10)]),
        ]
        let zeilen = ZirkelUebersicht.zeilen(zirkel: zirkel(2), bloecke: bloecke,
                                             seit: start.addingTimeInterval(5 * 60), name: name)
        #expect(zeilen == [
            ZirkelZeile(uebungsname: "Bizeps-Curls", saetze: ["14,0 kg × 10"]),
            ZirkelZeile(uebungsname: "Seitheben", saetze: []),
        ])
    }

    /// Beim Zirkel aus dem Einzelsatz beginnt der Zirkel mit genau diesem
    /// Satz (rundeBegann = dessen performedAt): er gehoert dazu.
    @Test func derSatzZumBeginnZaehltMit() {
        let bloecke = [LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, load: 14, volume: 10)])]
        let zeilen = ZirkelUebersicht.zeilen(zirkel: zirkel(2), bloecke: bloecke, seit: start, name: name)
        #expect(zeilen.first?.saetze == ["14,0 kg × 10"])
    }

    @Test func kopfUnterscheidetGeschafftUndBeendet() {
        var fertig = zirkel(2, runden: 2)
        for _ in 0..<4 { fertig.weiter() }
        #expect(ZirkelUebersicht.kopf(fertig) == "Zirkel geschafft")
        var abgebrochen = zirkel(2, runden: 2)
        abgebrochen.weiter()
        #expect(ZirkelUebersicht.kopf(abgebrochen) == "Zirkel beendet")
    }

    /// beenden() setzt den Zirkel auf nil. Was die Uebersicht braucht, wird
    /// vorher als Wert festgehalten und ueberlebt das Beenden.
    @Test func derAbschlussUeberlebtDasBeenden() {
        let ablauf = ZirkelAblauf()
        let beginn = start.addingTimeInterval(-60)
        ablauf.starten(zirkel(), jetzt: start, rundeBegann: beginn)
        ablauf.satzGesichert(jetzt: start)
        let abschluss = ablauf.abschluss
        ablauf.beenden()
        #expect(ablauf.abschluss == nil)
        #expect(abschluss?.zirkel.schritt == 1)
        #expect(abschluss?.zirkel.uebungen == [uebung(1), uebung(2), uebung(3)])
        #expect(abschluss?.begann == beginn)
    }

    @Test func ohneRundeBegannBeginntDerZirkelJetzt() {
        let ablauf = ZirkelAblauf()
        ablauf.starten(zirkel(), jetzt: start)
        #expect(ablauf.abschluss?.begann == start)
    }
}
