import Foundation
import Testing
@testable import FitnessMember

/// Reine Ableitung, ohne Netz oder View: Blockzeile (lokal, sofort da) +
/// Blockvorschlag (vom Server, kommt spaeter) -> AbschlussZeile.
struct TrainingAbschlussZeilenTests {
    private func block(_ machineId: String = "m1", _ exerciseId: String = "e1",
                       gewicht: Double? = 80, saetze: Int = 3, gemeldet: Bool = false) -> Blockzeile {
        Blockzeile(machineId: machineId, exerciseId: exerciseId,
                   belastung: gewicht, nebenbelastung: nil, loadUnit: .kg, secondaryUnit: nil,
                   volumeKind: .reps, satzAnzahl: saetze, problemGemeldet: gemeldet)
    }

    private func vorschlag(_ machineId: String = "m1", _ exerciseId: String = "e1",
                           delta: Double? = nil, reasonCode: String) -> Blockvorschlag {
        Blockvorschlag(machineId: machineId, exerciseId: exerciseId,
                       resultLoad: nil, deltaLoad: delta, secondaryLoad: nil,
                       loadUnit: .kg, secondaryUnit: nil, reasonCode: reasonCode, algoVersion: "v1")
    }

    private func kg(_ wert: Double) -> Vorschlagsdelta {
        Vorschlagsdelta(wert: wert, einheit: .kg, nebenbelastung: nil, nebeneinheit: nil)
    }

    @Test func korridorObenErreichtZeigtDasPositiveDelta() {
        let anzeige = VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaLoad: 2.5, loadUnit: .kg)
        #expect(anzeige == .delta(kg(2.5)))
        #expect(anzeige.text == "+2,5 kg")
    }

    @Test func korridorUntenVerfehltZeigtDasNegativeDeltaMitMinuszeichen() {
        let anzeige = VorschlagsAnzeige(reasonCode: "korridor_unten_verfehlt", deltaLoad: -2.5, loadUnit: .kg)
        #expect(anzeige == .delta(kg(-2.5)))
        #expect(anzeige.text == "−2,5 kg")
    }

    // MARK: - Einheit und Nebenbelastung (Cardio Schnitt 3)

    @Test(arguments: [
        (LoadUnit.kg, 2.5, "+2,5 kg", "Vorschlag plus 2,5 Kilogramm"),
        (.watt, 10, "+10 W", "Vorschlag plus 10 Watt"),
        (.level, -1, "−1 Level", "Vorschlag minus Level 1"),
        (.kmh, 0.5, "+0,5 km/h", "Vorschlag plus 0,5 Kilometer pro Stunde"),
    ])
    func dasDeltaTraegtDieEinheitDesGeraets(einheit: LoadUnit, delta: Double, text: String, gesprochen: String) {
        let anzeige = VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaLoad: delta, loadUnit: einheit)
        #expect(anzeige.text == text)
        #expect(anzeige.gesprochen == gesprochen)
    }

    @Test func dasLaufbandNenntDieNeigungBeiDerDerVorschlagGilt() {
        let anzeige = VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaLoad: 0.5, loadUnit: .kmh,
                                        secondaryLoad: 6, secondaryUnit: .pct)
        #expect(anzeige == .delta(Vorschlagsdelta(wert: 0.5, einheit: .kmh, nebenbelastung: 6, nebeneinheit: .pct)))
        #expect(anzeige.text == "+0,5 km/h bei 6,0 %")
        // Auf dem Screen zweizeilig: die Zahl gross, die Neigung darunter.
        #expect(anzeige.zahl == "+0,5 km/h")
        #expect(anzeige.zusatz == "bei 6,0 %")
        #expect(VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaLoad: 2.5, loadUnit: .kg).zusatz == nil)
        #expect(anzeige.gesprochen == "Vorschlag plus 0,5 Kilometer pro Stunde bei 6,0 Prozent")
    }

    @Test func haltenSagtWelcherReglerGemeintIst() {
        #expect(VorschlagsAnzeige(reasonCode: "im_korridor", deltaLoad: nil, loadUnit: .kg).text == "Gewicht halten")
        #expect(VorschlagsAnzeige(reasonCode: "im_korridor", deltaLoad: nil, loadUnit: .kmh).text == "Tempo halten")
        #expect(VorschlagsAnzeige(reasonCode: "im_korridor", deltaLoad: nil, loadUnit: .watt).gesprochen
                == "Vorschlag: Leistung halten")
    }

    @Test func dieZeileNimmtDieEinheitenAusDemVorschlag() {
        let laufband = Blockzeile(machineId: "m9", exerciseId: "e9", belastung: 8.5, nebenbelastung: 6,
                                  loadUnit: .kmh, secondaryUnit: .pct, volumeKind: .seconds,
                                  satzAnzahl: 1, problemGemeldet: false)
        let vorschlag = Blockvorschlag(machineId: "m9", exerciseId: "e9", resultLoad: 9, deltaLoad: 0.5,
                                       secondaryLoad: 6, loadUnit: .kmh, secondaryUnit: .pct,
                                       reasonCode: "korridor_oben_erreicht", algoVersion: "2.0.0")

        let zeilen = AbschlussZeile.zeilen(bloecke: [laufband], vorschlaege: [vorschlag])

        #expect(zeilen[0].anzeige.text == "+0,5 km/h bei 6,0 %")
    }

    @Test func derUntertitelNenntBelastungNebenbelastungUndSaetze() {
        let laufband = Blockzeile(machineId: "m9", exerciseId: "e9", belastung: 8.5, nebenbelastung: 6,
                                  loadUnit: .kmh, secondaryUnit: .pct, volumeKind: .seconds,
                                  satzAnzahl: 1, problemGemeldet: false)
        #expect(AbschlussZeile.untertitel(laufband) == "8,5 km/h · 6,0 % · 1 Satz")
        // Die Beinpresse wie vor dem Umbau.
        #expect(AbschlussZeile.untertitel(block()) == "80,0 kg · 3 Sätze")
        // Uneinheitliche Saetze: lieber keine Zahl als eine falsche.
        #expect(AbschlussZeile.untertitel(block(gewicht: nil)) == "3 Sätze")
    }

    @Test func imKorridorHeisstGewichtHalten() {
        let anzeige = VorschlagsAnzeige(reasonCode: "im_korridor", deltaLoad: nil, loadUnit: .kg)
        #expect(anzeige == .halten(.kg))
        #expect(anzeige.text == "Gewicht halten")
    }

    @Test func problemGemeldetHeisstKeinVorschlagMitGrund() {
        let anzeige = VorschlagsAnzeige(reasonCode: "problem_gemeldet", deltaLoad: nil, loadUnit: .kg)
        #expect(anzeige == .ohne(.problemGemeldet))
        #expect(anzeige.text == "Kein Vorschlag")
        #expect(anzeige.grund == "Du hast ein Problem gemeldet.")
    }

    // Testnotiz 06.10., #19 ("Woher kommen die Vorschlaege?"): statt eines
    // nackten "Kein Vorschlag" steht der Grund darunter. Vorher fielen alle
    // vier Codes stumm auf denselben Satz -- und liessen offen, ob die App
    // etwas falsch gemacht hat.
    @Test(arguments: [
        ("kein_verlauf", "Noch kein Verlauf an dieser Übung."),
        ("daten_uneindeutig", "Das Gewicht wechselte zwischen den Sätzen."),
        ("geraetegrenze_erreicht", "Die Grenze des Geräts ist erreicht."),
    ])
    func dieUebrigenReasonCodesNennenIhrenGrund(reasonCode: String, grund: String) {
        let anzeige = VorschlagsAnzeige(reasonCode: reasonCode, deltaLoad: nil, loadUnit: .kg)
        #expect(anzeige.text == "Kein Vorschlag")
        #expect(anzeige.grund == grund)
        #expect(anzeige.gesprochen == "Kein Vorschlag. \(grund)")
    }

    @Test func einUnbekannterReasonCodeBleibtOhneGrund() {
        let anzeige = VorschlagsAnzeige(reasonCode: "irgendwas_unbekanntes", deltaLoad: nil, loadUnit: .kg)
        #expect(anzeige == .keiner)
        #expect(anzeige.grund == nil)
    }

    @Test func einKorridorCodeOhneDeltaFaelltEbenfallsAufKeinVorschlag() {
        // Defensiv: sollte der Server einen Korridor-Code ohne deltaLoad
        // schicken, zeigt der Screen lieber "Kein Vorschlag" als nichts
        // oder eine falsche Zahl.
        #expect(VorschlagsAnzeige(reasonCode: "korridor_oben_erreicht", deltaLoad: nil, loadUnit: .kg) == .keiner)
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
        #expect(zeilen[0].anzeige == .delta(kg(2.5)))
        #expect(zeilen[1].block.machineId == "m2")
        #expect(zeilen[1].anzeige == .halten(.kg))
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

    /// Zwei Uebungen an DERSELBEN Maschine -- die Zuordnung darf nicht
    /// ueber machineId allein gehen. Genau diese Fehlerklasse hat in
    /// Sub-Projekt 2 einen Screen die Werte einer Uebung unter dem Namen
    /// einer anderen zeigen lassen; ein Vorschlag am falschen Block ist
    /// eine Zahl, die das Mitglied auflegt.
    @Test func zweiUebungenAnDerselbenMaschineBekommenJedeIhrenEigenenVorschlag() {
        let bloecke = [
            block("m1", "e1", gewicht: 80),
            block("m1", "e2", gewicht: 40),
        ]
        // Der Vorschlag der ZWEITEN Uebung steht zuerst: `first(where:)`
        // wuerde bei einem Vergleich allein ueber machineId hier den
        // falschen greifen -- und zwar fuer beide Zeilen denselben.
        let vorschlaege = [
            vorschlag("m1", "e2", delta: -2.5, reasonCode: "korridor_unten_verfehlt"),
            vorschlag("m1", "e1", delta: 2.5, reasonCode: "korridor_oben_erreicht"),
        ]

        let zeilen = AbschlussZeile.zeilen(bloecke: bloecke, vorschlaege: vorschlaege)

        #expect(zeilen.count == 2)
        #expect(zeilen[0].block.exerciseId == "e1")
        #expect(zeilen[0].anzeige == .delta(kg(2.5)))
        #expect(zeilen[1].block.exerciseId == "e2")
        #expect(zeilen[1].anzeige == .delta(kg(-2.5)))
    }

    /// Die Gegenprobe: dieselbe UEBUNG an zwei Maschinen. Auch hier
    /// entscheidet das Paar, nicht eine Haelfte davon.
    @Test func dieselbeUebungAnZweiMaschinenBleibtAuseinandergehalten() {
        let bloecke = [block("m1", "e1"), block("m2", "e1")]
        let vorschlaege = [
            vorschlag("m2", "e1", reasonCode: "im_korridor"),
            vorschlag("m1", "e1", delta: 2.5, reasonCode: "korridor_oben_erreicht"),
        ]

        let zeilen = AbschlussZeile.zeilen(bloecke: bloecke, vorschlaege: vorschlaege)

        #expect(zeilen[0].anzeige == .delta(kg(2.5)))
        #expect(zeilen[1].anzeige == .halten(.kg))
    }

    /// Und: zwei Bloecke an derselben Maschine haben verschiedene ids --
    /// sonst zeichnete ForEach in "Beim naechsten Mal" nur einen von
    /// beiden oder verwechselte sie beim Neuzeichnen.
    @Test func zweiBloeckeAnDerselbenMaschineHabenVerschiedeneIds() {
        let zeilen = AbschlussZeile.zeilen(
            bloecke: [block("m1", "e1"), block("m1", "e2")], vorschlaege: [])

        #expect(zeilen[0].id != zeilen[1].id)
    }

    /// Ein Typ-Block hat keine machineId; sein Vorschlag auch nicht. Beide
    /// finden ueber den Typ-Schluessel zueinander.
    @Test func einVorschlagOhneGeraetGehoertZumTypBlock() {
        let typBlock = Blockzeile(machineId: nil, equipmentModelId: "t1", exerciseId: "e1",
                                  belastung: 40, nebenbelastung: nil, loadUnit: .kg, secondaryUnit: nil,
                                  volumeKind: .reps, satzAnzahl: 3, problemGemeldet: false)
        let typVorschlag = Blockvorschlag(machineId: nil, equipmentModelId: "t1", exerciseId: "e1",
                                          resultLoad: nil, deltaLoad: 2.5, secondaryLoad: nil,
                                          loadUnit: .kg, secondaryUnit: nil,
                                          reasonCode: "korridor_oben_erreicht", algoVersion: "v1")
        let zeilen = AbschlussZeile.zeilen(bloecke: [typBlock, block("m1")], vorschlaege: [typVorschlag])
        #expect(zeilen[0].anzeige.text == "+2,5 kg")
        #expect(zeilen[1].anzeige.text != "+2,5 kg")
    }

    /// Der Name kommt ueber die Station: ein Typ-Block steht nicht in
    /// bootstrap.machines und bliebe sonst namenlos.
    @Test func dieZeileNenntDenTypNamenUeberDieStation() {
        #expect(AbschlussZeile.titel(station: .testTyp("t1", studioId: nil), uebung: nil) == "Typ t1")
        #expect(AbschlussZeile.titel(station: nil, uebung: nil) == "")
    }
}
