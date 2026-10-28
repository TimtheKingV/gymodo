import CoreGraphics
import Testing
@testable import FitnessMember

struct PlanReihenfolgeTests {
    @Test("Aktionen fehlen an den Enden, die unmoegliche entfaellt")
    func aktionenAnDenEnden() {
        #expect(PlanReihenfolge.aktionen(index: 0, anzahl: 4) == [.runter])
        #expect(PlanReihenfolge.aktionen(index: 1, anzahl: 4) == [.hoch, .runter])
        #expect(PlanReihenfolge.aktionen(index: 3, anzahl: 4) == [.hoch])
        #expect(PlanReihenfolge.aktionen(index: 0, anzahl: 1).isEmpty)
    }

    @Test("Aktionsnamen und Zielindex")
    func aktionsnamen() {
        #expect(PlanReihenfolge.Richtung.hoch.name == "Nach oben verschieben")
        #expect(PlanReihenfolge.Richtung.runter.name == "Nach unten verschieben")
        #expect(PlanReihenfolge.Richtung.hoch.ziel(von: 2) == 1)
        #expect(PlanReihenfolge.Richtung.runter.ziel(von: 2) == 3)
    }

    @Test("Zielindex aus dem Versatz der gezogenen Zeile")
    func zielindex() {
        let h = [CGFloat](repeating: 80, count: 4)
        #expect(PlanReihenfolge.zielIndex(von: 0, versatz: 0, hoehen: h) == 0)
        #expect(PlanReihenfolge.zielIndex(von: 0, versatz: 30, hoehen: h) == 0)
        #expect(PlanReihenfolge.zielIndex(von: 0, versatz: 88, hoehen: h) == 1)
        #expect(PlanReihenfolge.zielIndex(von: 0, versatz: 1000, hoehen: h) == 3)
        #expect(PlanReihenfolge.zielIndex(von: 2, versatz: -88, hoehen: h) == 1)
        #expect(PlanReihenfolge.zielIndex(von: 2, versatz: -1000, hoehen: h) == 0)
        // Ungleiche Hoehen: die schmale Zeile 1 (Mitte bei 120) liegt unter der gezogenen Mitte 40+100.
        #expect(PlanReihenfolge.zielIndex(von: 0, versatz: 100, hoehen: [80, 80, 200]) == 1)
    }

    @Test("Verschiebung der uebrigen Zeilen macht Platz")
    func verschiebung() {
        // Zeile 0 wandert auf 2: Zeilen 1 und 2 ruecken um ihre Hoehe hoch.
        #expect(PlanReihenfolge.verschiebung(index: 1, von: 0, ziel: 2, hoehe: 80) == -80)
        #expect(PlanReihenfolge.verschiebung(index: 2, von: 0, ziel: 2, hoehe: 80) == -80)
        #expect(PlanReihenfolge.verschiebung(index: 3, von: 0, ziel: 2, hoehe: 80) == 0)
        // Zeile 3 wandert auf 1: Zeilen 1 und 2 ruecken nach unten.
        #expect(PlanReihenfolge.verschiebung(index: 1, von: 3, ziel: 1, hoehe: 80) == 80)
        #expect(PlanReihenfolge.verschiebung(index: 2, von: 3, ziel: 1, hoehe: 80) == 80)
        #expect(PlanReihenfolge.verschiebung(index: 0, von: 3, ziel: 1, hoehe: 80) == 0)
    }

    @Test("Auswahlzweck einer Route und im Pfad")
    func auswahlzweck() {
        #expect(GeraetRoute.planErsatz(positionKey: "A0").auswahlzweck == .ersatz)
        #expect(GeraetRoute.planHinzufuegen.auswahlzweck == .hinzufuegen)
        #expect(GeraetRoute.kategorie(.freihantel).auswahlzweck == nil)
        #expect(GeraetRoute.auswahlzweck(im: []) == nil)
        #expect(GeraetRoute.auswahlzweck(im: [.planHinzufuegen, .kategorie(.freihantel)]) == .hinzufuegen)
        #expect(GeraetRoute.auswahlzweck(im: [.planErsatz(positionKey: "A0"), .kategorie(.freihantel)]) == .ersatz)
    }
}
