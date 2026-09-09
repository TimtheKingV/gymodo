import Foundation
import Testing
@testable import FitnessMember

/// Reine Ableitung, ohne Netz oder View: Blockzeile (lokal, sofort da) +
/// Blockvorschlag (vom Server, kommt spaeter) -> AbschlussZeile.
struct TrainingAbschlussZeilenTests {
    private func block(_ machineId: String = "m1", _ exerciseId: String = "e1",
                       gewicht: Double? = 80, saetze: Int = 3, gemeldet: Bool = false) -> Blockzeile {
        Blockzeile(machineId: machineId, exerciseId: exerciseId,
                   gewichtKg: gewicht, satzAnzahl: saetze, problemGemeldet: gemeldet)
    }

    private func vorschlag(_ machineId: String = "m1", _ exerciseId: String = "e1",
                           delta: Double? = nil, reasonCode: String) -> Blockvorschlag {
        Blockvorschlag(machineId: machineId, exerciseId: exerciseId,
                       resultWeightKg: nil, deltaKg: delta, reasonCode: reasonCode, algoVersion: "v1")
    }

    @Test func korridorObenErreichtZeigtDasPositiveDelta() {
        let anzeige = VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaKg: 2.5)
        #expect(anzeige == .delta(2.5))
        #expect(anzeige.text == "+2,5 kg")
    }

    @Test func korridorUntenVerfehltZeigtDasNegativeDeltaMitMinuszeichen() {
        let anzeige = VorschlagsAnzeige(reasonCode: "korridor_unten_verfehlt", deltaKg: -2.5)
        #expect(anzeige == .delta(-2.5))
        #expect(anzeige.text == "-2,5 kg")
    }

    @Test func imKorridorHeisstGewichtHalten() {
        let anzeige = VorschlagsAnzeige(reasonCode: "im_korridor", deltaKg: nil)
        #expect(anzeige == .halten)
        #expect(anzeige.text == "Gewicht halten")
    }

    @Test func problemGemeldetHeisstKeinVorschlag() {
        let anzeige = VorschlagsAnzeige(reasonCode: "problem_gemeldet", deltaKg: nil)
        #expect(anzeige == .keiner)
        #expect(anzeige.text == "Kein Vorschlag")
    }

    // Die uebrigen drei reasonCodes zeigt das Artboard nicht -- sie fallen
    // alle auf "Kein Vorschlag", weil sieben Formulierungen fuer dieselbe
    // Aussage niemandem helfen (Aufgabenbrief).
    @Test(arguments: ["kein_verlauf", "daten_uneindeutig", "geraetegrenze_erreicht", "irgendwas_unbekanntes"])
    func unbekannteOderNichtVorgeseheneReasonCodesFallenAufKeinVorschlag(reasonCode: String) {
        #expect(VorschlagsAnzeige(reasonCode: reasonCode, deltaKg: nil) == .keiner)
    }

    @Test func einKorridorCodeOhneDeltaFaelltEbenfallsAufKeinVorschlag() {
        // Defensiv: sollte der Server einen Korridor-Code ohne deltaKg
        // schicken, zeigt der Screen lieber "Kein Vorschlag" als nichts
        // oder eine falsche Zahl.
        #expect(VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaKg: nil) == .keiner)
    }

    @Test func einFehlenderVorschlagZeigtKeinVorschlagStattZuVerschwinden() {
        let zeilen = AbschlussZeile.zeilen(bloecke: [block()], vorschlaege: [])

        #expect(zeilen.count == 1)
        #expect(zeilen[0].anzeige == .keiner)
    }

    @Test func jederBlockBekommtSeinenEigenenVorschlagUeberMachineUndExercise() {
        let bloecke = [
            block("m1", "e1"),
            block("m2", "e2"),
        ]
        let vorschlaege = [
            vorschlag("m2", "e2", reasonCode: "im_korridor"),
            vorschlag("m1", "e1", delta: 2.5, reasonCode: "korridor_oben_erreicht"),
        ]

        let zeilen = AbschlussZeile.zeilen(bloecke: bloecke, vorschlaege: vorschlaege)

        #expect(zeilen.count == 2)
        #expect(zeilen[0].block.machineId == "m1")
        #expect(zeilen[0].anzeige == .delta(2.5))
        #expect(zeilen[1].block.machineId == "m2")
        #expect(zeilen[1].anzeige == .halten)
    }

    @Test func dieReihenfolgeFolgtDenLokalenBloeckenNichtDerServerantwort() {
        let bloecke = [block("m1", "e1"), block("m2", "e2"), block("m3", "e3")]
        // Server liefert absichtlich in anderer Reihenfolge.
        let vorschlaege = [
            vorschlag("m3", "e3", reasonCode: "im_korridor"),
            vorschlag("m1", "e1", reasonCode: "im_korridor"),
        ]

        let zeilen = AbschlussZeile.zeilen(bloecke: bloecke, vorschlaege: vorschlaege)

        #expect(zeilen.map(\.block.machineId) == ["m1", "m2", "m3"])
    }
}
