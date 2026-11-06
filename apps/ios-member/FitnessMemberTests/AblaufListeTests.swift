import Foundation
import Testing
@testable import FitnessMember

/// Die Ablauf-Liste im Pausen-Screen (UX-Paket 2, Task 2): Plan, Zirkel, frei.
struct AblaufListeTests {

    private let start = Date(timeIntervalSince1970: 1_757_930_400)

    // MARK: Bausteine

    private func satz(_ index: Int, load: Double = 20, volume: Int = 10, minuten: Double = 0) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, load: load, volume: volume, rir: nil,
                    problemFlag: false, problemReason: nil,
                    performedAt: start.addingTimeInterval(minuten * 60))
    }

    /// Einheit A mit sechs Positionen A0...A5 (Uebungen e0...e5).
    private func plan6() -> Trainingsplan {
        let positionen = (0..<6).map { n in
            """
            {"key":"A\(n)","baustein":"brust","rolle":"pflicht","exerciseId":"e\(n)",
             "modelId":"m-e\(n)","typ":"mehrgelenk","saetze":3,"wdhVon":10,"wdhBis":12,
             "reserveVon":1,"reserveBis":3,"pauseSek":120,"aufwaermsatz":false,"dauerMin":null,
             "hauptmuskeln":[]}
            """
        }.joined(separator: ",")
        let json = """
        {"planId":"p1","studioId":"s1","version":1,"regelVersion":"1.2.0","struktur":"gk_ab","gruende":[],
         "naechsteEinheitKey":"A","zuletztEinheitKey":null,"einheitenErledigt":0,"anfaengerUebergang":false,
         "alternativen":{},"einheiten":[{"key":"A","geschaetzteMinuten":45,"positionen":[\(positionen)]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    private func zustand(erledigt: Set<Int>) -> AblaufZustand {
        AblaufZustand(positionen: (0..<6).map { n in
            AblaufPosition(key: "A\(n)", exerciseId: "e\(n)", hauptmuskeln: [], cardio: false,
                           status: erledigt.contains(n) ? .erledigt : .offen, ersatzExerciseId: nil)
        }, ungeplanteGesehen: [])
    }

    private func planstellen(_ status: [PositionStatus]) -> [PlanAnzeige.Planstelle] {
        status.enumerated().map { n, status in
            PlanAnzeige.Planstelle(key: "A\(n)", geplant: "e\(n)", ersatz: nil, status: status,
                                   hauptmuskeln: [], cardio: false, vorgabe: nil)
        }
    }

    private func zeile(_ n: Int, _ stand: AblaufZeile.Stand) -> AblaufZeile {
        AblaufZeile(id: "z\(n)", name: "Z\(n)", detail: "", stand: stand, bildModellId: nil)
    }

    // MARK: Plan

    @Test func planReihenfolgeUndStand() {
        let zeilen = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: [0, 1]),
                                      ausgelassen: [], bloecke: [], aktuelleUebung: "e2", bootstrap: nil)
        #expect(zeilen.map(\.id) == ["A0", "A1", "A2", "A3", "A4", "A5"])
        #expect(zeilen.map(\.stand) == [.erledigt, .erledigt, .jetzt, .naechste, .offen, .offen])
        #expect(zeilen[3].detail == "3 × 10–12")
    }

    @Test func planOhneAusgelassene() {
        let zeilen = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: [0, 1]),
                                      ausgelassen: ["A4"], bloecke: [], aktuelleUebung: "e2", bootstrap: nil)
        #expect(zeilen.count == 5)
        #expect(!zeilen.map(\.id).contains("A4"))
    }

    @Test func planJetztZaehltMitDerPlanZaehlung() {
        let bloecke = [LokalerBlock(machineId: "m1", exerciseId: "e2", saetze: [satz(1, load: 12.5, volume: 10)]),
                       LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, load: 10, volume: 9, minuten: 3)])]
        let zeilen = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: [0, 1, 2]),
                                      ausgelassen: [], bloecke: bloecke, aktuelleUebung: "e2", bootstrap: nil)
        #expect(zeilen[2].stand == .jetzt)
        #expect(zeilen[2].detail == ZirkelPauseText.satzwerte(bloecke[1].saetze[0], bloecke[1]))
        #expect(!zeilen[2].detail.contains("Satz"))
    }

    @Test func naechstePlanstelleUeberspringtErledigteAktuelleUndAusgelassene() {
        // A0 erledigt, A1 aktuell, A2 ausgelassen, A3 offen -> A3.
        let stellen = planstellen([.erledigt, .offen, .offen, .offen])
        let naechste = AblaufListe.naechstePlanstelle(stellen: stellen, ausgelassen: ["A2"], aktuelleUebung: "e1")
        #expect(naechste?.key == "A3")
        #expect(AblaufListe.naechstePlanstelle(stellen: planstellen([.erledigt, .optional]), ausgelassen: [],
                                               aktuelleUebung: nil) == nil)
        // Getauschte Position zaehlt als offen.
        #expect(AblaufListe.naechstePlanstelle(stellen: planstellen([.erledigt, .getauscht]), ausgelassen: [],
                                               aktuelleUebung: "e0")?.key == "A1")
    }

    // MARK: Ausschnitt

    @Test func sichtbarZeigtZweiDarueberUndZweiDarunter() {
        let zeilen = [zeile(0, .erledigt), zeile(1, .erledigt), zeile(2, .erledigt), zeile(3, .erledigt),
                      zeile(4, .jetzt), zeile(5, .naechste), zeile(6, .offen)]
        // 7 Zeilen, jetzt an Index 4: 2...6.
        #expect(AblaufListe.sichtbar(zeilen, ausgeklappt: false).map(\.id) == ["z2", "z3", "z4", "z5", "z6"])
        #expect(AblaufListe.hatMehr(zeilen))
        #expect(AblaufListe.sichtbar(zeilen, ausgeklappt: true).count == 7)
    }

    @Test func sichtbarOhneJetztNimmtDieNaechste() {
        let zeilen = [zeile(0, .erledigt), zeile(1, .naechste), zeile(2, .offen)]
        #expect(AblaufListe.sichtbar(zeilen, ausgeklappt: false).count == 3)
        #expect(!AblaufListe.hatMehr(zeilen))
    }

    // MARK: Zirkel

    private func uebung(_ n: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:m\(n)", exerciseId: "e\(n)", token: nil)
    }

    @Test func zirkelRundenpause() {
        var zirkel = Zirkel(uebungen: [uebung(1), uebung(2), uebung(3)], runden: 3, uebungspause: 20, rundenpause: 90)
        zirkel.weiter(); zirkel.weiter(); zirkel.weiter()   // Runde 1 geschafft, Rundenwechsel
        #expect(zirkel.naechsterSchrittIstRundenwechsel)
        // Station 1 hat zwei Saetze im Block (verschiedene Werte), die
        // anderen je einen.
        var bloecke = (1...3).map { n in
            LokalerBlock(machineId: "m\(n)", exerciseId: "e\(n)", saetze: [satz(1, load: Double(n) * 10, volume: 12)])
        }
        bloecke[0] = LokalerBlock(machineId: "m1", exerciseId: "e1",
                                  saetze: [satz(1, load: 10, volume: 12), satz(2, load: 15, volume: 8, minuten: 2)])
        let zeilen = AblaufListe.zirkel(zirkel, bloecke: bloecke, seit: start.addingTimeInterval(-60),
                                        name: { "Name \($0.exerciseId)" }, bildModellId: { _ in nil })
        // Die neue Runde: ihre erste Station ist die naechste, der Rest offen.
        #expect(zeilen.map(\.stand) == [.naechste, .offen, .offen])
        let erster = ZirkelPauseText.satzwerte(bloecke[0].saetze[0], bloecke[0]) ?? "?"
        let letzter = ZirkelPauseText.satzwerte(bloecke[0].saetze[1], bloecke[0]) ?? "?"
        #expect(erster != letzter)
        // Nur der letzte Satz, genau einmal -- nicht beide, nicht doppelt.
        #expect(zeilen[0].detail == letzter)
        #expect(zeilen[0].detail.components(separatedBy: letzter).count == 2)
        #expect(!zeilen[0].detail.contains(erster))
    }

    @Test func zirkelMitteDerRundeZeigtGemachteStationErledigt() {
        var zirkel = Zirkel(uebungen: [uebung(1), uebung(2), uebung(3)], runden: 3, uebungspause: 20, rundenpause: 90)
        zirkel.weiter()   // Station 1 in Runde 1 gemacht
        let bloecke = [LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, load: 10, volume: 12)])]
        let zeilen = AblaufListe.zirkel(zirkel, bloecke: bloecke, seit: start.addingTimeInterval(-60),
                                        name: { $0.exerciseId }, bildModellId: { _ in nil })
        #expect(zeilen.map(\.stand) == [.erledigt, .naechste, .offen])
        #expect(zeilen[0].detail == ZirkelPauseText.satzwerte(bloecke[0].saetze[0], bloecke[0]))
    }

    @Test func zirkelAmGeraetIstDieStationJetzt() {
        var zirkel = Zirkel(uebungen: [uebung(1), uebung(2), uebung(3)], runden: 3, uebungspause: 20, rundenpause: 90)
        zirkel.weiter()   // an Station 2
        let zeilen = AblaufListe.zirkel(zirkel, bloecke: [], seit: nil, amGeraet: true,
                                        name: { $0.exerciseId }, bildModellId: { _ in nil })
        #expect(zeilen.map(\.stand) == [.erledigt, .jetzt, .offen])
    }

    @Test func zirkelAbgeschlosseneStationIstErledigt() {
        var zirkel = Zirkel(uebungen: [uebung(1), uebung(2)], runden: 2, uebungspause: 20, rundenpause: 90)
        for _ in 0..<4 { zirkel.weiter() }
        let zeilen = AblaufListe.zirkel(zirkel, bloecke: [], seit: nil,
                                        name: { $0.exerciseId }, bildModellId: { _ in nil })
        #expect(zeilen.map(\.stand) == [.erledigt, .erledigt])
    }

    // MARK: Frei

    @Test func freiEineUebung() {
        let block = LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [])
        let zeilen = AblaufListe.frei(bloecke: [block],
                                      aktuell: (stationSchluessel: block.stationSchluessel, exerciseId: "e1"),
                                      name: { _ in "Presse" })
        #expect(zeilen.map(\.stand) == [.jetzt])
        #expect(zeilen[0].detail == "")
        #expect(!AblaufListe.hatMehr(zeilen))
    }

    @Test func freiErledigteUndAktuelle() {
        let alt = LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1), satz(2, minuten: 2)])
        let jetzt = LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, minuten: 5)])
        let zeilen = AblaufListe.frei(bloecke: [alt, jetzt],
                                      aktuell: (stationSchluessel: jetzt.stationSchluessel, exerciseId: "e2"),
                                      name: { $0.exerciseId })
        #expect(zeilen.map(\.stand) == [.erledigt, .jetzt])
        #expect(zeilen[0].detail == "2 × " + (ZirkelPauseText.satzwerte(alt.saetze[0], alt) ?? "?"))
        #expect(zeilen[1].detail == ZirkelPauseText.satzwerte(jetzt.saetze[0], jetzt))
    }

    // MARK: Erledigt-Detail und Zusatzuebungen

    @Test func erledigtDetailKompaktUndMitAbweichungen() {
        let gleich = LokalerBlock(machineId: "m1", exerciseId: "e0",
                                  saetze: [satz(1, load: 30, volume: 11), satz(2, load: 30, volume: 11, minuten: 2),
                                           satz(3, load: 30, volume: 11, minuten: 4)])
        let zeilen = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: [0]),
                                      ausgelassen: [], bloecke: [gleich], aktuelleUebung: "e1", bootstrap: nil)
        let eins = ZirkelPauseText.satzwerte(gleich.saetze[0], gleich) ?? "?"
        #expect(zeilen[0].detail == "3 × \(eins)")

        let verschieden = LokalerBlock(machineId: "m1", exerciseId: "e0",
                                       saetze: [satz(1, load: 30, volume: 11), satz(2, load: 30, volume: 9, minuten: 2)])
        let z2 = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: [0]),
                                  ausgelassen: [], bloecke: [verschieden], aktuelleUebung: "e1", bootstrap: nil)
        let a = ZirkelPauseText.satzwerte(verschieden.saetze[0], verschieden) ?? "?"
        let b = ZirkelPauseText.satzwerte(verschieden.saetze[1], verschieden) ?? "?"
        #expect(z2[0].detail == "\(a) · \(b)")
    }

    @Test func zusatzuebungenStehenErledigtHinterDemPlan() {
        let extra = LokalerBlock(machineId: "m9", exerciseId: "x1", saetze: [satz(1, minuten: 1)])
        let zeilen = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: [0]),
                                      ausgelassen: [], bloecke: [extra], aktuelleUebung: "e1", bootstrap: nil)
        #expect(zeilen.count == 7)
        #expect(zeilen.last?.id == "zusatz:x1")
        #expect(zeilen.last?.stand == .erledigt)
        #expect(zeilen.last?.detail == ZirkelPauseText.satzwerte(extra.saetze[0], extra))
    }

    @Test func aktuelleZusatzuebungIstJetzt() {
        let extra = LokalerBlock(machineId: "m9", exerciseId: "x1", saetze: [satz(1, minuten: 1)])
        let zeilen = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: []),
                                      ausgelassen: [], bloecke: [extra], aktuelleUebung: "x1", bootstrap: nil)
        #expect(zeilen.last?.stand == .jetzt)
        #expect(zeilen.filter { $0.stand == .jetzt }.count == 1)
        // Ohne Satz (gerade erst geoeffnet) gibt es die Zeile trotzdem.
        let leer = AblaufListe.plan(plan: plan6(), einheitKey: "A", zustand: zustand(erledigt: []),
                                    ausgelassen: [], bloecke: [], aktuelleUebung: "x2", bootstrap: nil)
        #expect(leer.last?.id == "zusatz:x2")
        #expect(leer.last?.stand == .jetzt)
        #expect(leer.last?.detail == "")
    }
}
