import Foundation
import Testing
@testable import FitnessMember

/// Was der Pausenscreen im Zirkel in Worten sagt (Spec Mini-Zirkel 21.10.,
/// Entscheidungen 5 und 6).
struct ZirkelPauseTextTests {

    private let start = Date(timeIntervalSince1970: 1_757_930_400)

    private func uebung(_ n: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:m\(n)", exerciseId: "e\(n)", token: nil)
    }

    private func satz(_ index: Int, load: Double, volume: Int) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, load: load, volume: volume, rir: nil,
                    problemFlag: false, problemReason: nil, performedAt: start)
    }

    @Test func kopfDerUebungspause() {
        #expect(ZirkelPauseText.kopf(runde: 1, runden: 3, rundenwechsel: false) == "Runde 1 von 3")
    }

    @Test func kopfDerRundenpause() {
        #expect(ZirkelPauseText.kopf(runde: 1, runden: 3, rundenwechsel: true) == "Runde 1 von 3 · Rundenpause")
    }

    @Test func startTitelNenntDieUebung() {
        #expect(ZirkelPauseText.startTitel(uebungsname: "Seitheben") == "Seitheben starten")
    }

    /// In der Rundenpause zaehlt der Zirkel schon die naechste Runde; der
    /// Kopf nennt die gerade geschaffte.
    @Test func kopfAusDemZirkelNenntInDerRundenpauseDieGeschaffteRunde() {
        var zirkel = Zirkel(uebungen: [uebung(1), uebung(2)], runden: 3, uebungspause: 20, rundenpause: 90)
        zirkel.weiter()
        #expect(ZirkelPauseText.kopf(zirkel) == "Runde 1 von 3")
        zirkel.weiter()
        #expect(ZirkelPauseText.kopf(zirkel) == "Runde 1 von 3 · Rundenpause")
        zirkel.weiter()
        #expect(ZirkelPauseText.kopf(zirkel) == "Runde 2 von 3")
    }

    /// "Danach: …" nur innerhalb der Runde: vor der Rundenpause kommt keine
    /// Uebung mehr, und die erste der naechsten Runde steht dann selbst
    /// unter "Als Nächstes".
    @Test func danachNurInnerhalbDerRunde() {
        var zirkel = Zirkel(uebungen: [uebung(1), uebung(2), uebung(3)], runden: 2, uebungspause: 20, rundenpause: 90)
        zirkel.weiter()
        #expect(zirkel.naechste == uebung(2))
        #expect(ZirkelPauseText.danach(zirkel) == uebung(3))
        zirkel.weiter()
        #expect(ZirkelPauseText.danach(zirkel) == nil)
        zirkel.weiter()
        // Rundenpause: als Naechstes Uebung 1, danach Uebung 2.
        #expect(ZirkelPauseText.danach(zirkel) == uebung(2))
    }

    /// Je Uebung der letzte Satz der Einheit; eine Uebung ohne Satz (in
    /// dieser Einheit uebersprungen) faellt weg statt "0 kg" zu zeigen.
    @Test func rundenzeilenNennenJeUebungDenLetztenSatz() {
        let zirkel = Zirkel(uebungen: [uebung(1), uebung(2), uebung(3)], runden: 3, uebungspause: 20, rundenpause: 90)
        let bloecke = [
            LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, load: 8, volume: 15)]),
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, load: 10, volume: 12), satz(2, load: 12.5, volume: 10)]),
        ]
        let namen = ["e1": "Bizeps-Curls", "e2": "Seitheben", "e3": "Schrägbankdrücken"]
        let zeilen = ZirkelPauseText.rundenzeilen(zirkel, bloecke: bloecke) { namen[$0.exerciseId] ?? "" }
        #expect(zeilen == ["Bizeps-Curls 12,5 kg × 10", "Seitheben 8,0 kg × 15"])
    }
}
