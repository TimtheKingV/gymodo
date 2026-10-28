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

    @Test("Eine hohe Zeile erreicht die aeussersten Plaetze, Vorschau und Drop stimmen")
    func hoheZeileErreichtDieEnden() {
        #expect(PlanReihenfolge.zielIndex(von: 2, versatz: -1000, hoehen: [60, 60, 200]) == 0)
        #expect(PlanReihenfolge.zielIndex(von: 0, versatz: 1000, hoehen: [200, 60, 60]) == 2)
        // Schon ein Stueck weniger als bis ganz nach oben reicht, die erste Zeile zu passieren.
        #expect(PlanReihenfolge.zielIndex(von: 2, versatz: -(60 + 60), hoehen: [60, 60, 200]) == 0)
        #expect(PlanReihenfolge.begrenzt(-1000, von: 2, hoehen: [60, 60, 200]) == -120)
        #expect(PlanReihenfolge.begrenzt(1000, von: 0, hoehen: [200, 60, 60]) == 120)
    }

    @Test("Angezeigter Versatz ist begrenzt und stimmt mit dem Ziel ueberein")
    func begrenzterVersatz() {
        let h: [CGFloat] = [60, 80, 200, 70]
        // Weit ueber den Rand gezogen: angezeigt wird nur bis zur Kante.
        #expect(PlanReihenfolge.begrenzt(-500, von: 2, hoehen: h) == -140)
        #expect(PlanReihenfolge.begrenzt(500, von: 2, hoehen: h) == 70)
        #expect(PlanReihenfolge.begrenzt(-30, von: 2, hoehen: h) == -30)
        // Roh und begrenzt landen am selben Ziel.
        for roh: CGFloat in [-500, -140, -30, 30, 70, 500] {
            #expect(PlanReihenfolge.zielIndex(von: 2, versatz: roh, hoehen: h)
                    == PlanReihenfolge.zielIndex(von: 2, versatz: PlanReihenfolge.begrenzt(roh, von: 2, hoehen: h), hoehen: h))
        }
    }

    @Test("Trennlinien gehoeren zum Platz der Zeile")
    func trennlinien() {
        #expect(PlanReihenfolge.plaetze([80, 60]) == [81, 61])
    }

    @Test("Ansage nach einer Verschiebung")
    func ansage() {
        #expect(PlanReihenfolge.ansage(.hoch, neuerIndex: 1, anzahl: 6) == "Nach oben verschoben, Position 2 von 6")
        #expect(PlanReihenfolge.ansage(.runter, neuerIndex: 5, anzahl: 6) == "Nach unten verschoben, Position 6 von 6")
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
