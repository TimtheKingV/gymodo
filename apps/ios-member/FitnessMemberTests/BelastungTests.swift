import Foundation
import Testing
@testable import FitnessMember

/// Der Swift-Spiegel von packages/domain/src/belastung.ts. Die erwarteten
/// Zeichenketten stehen dort in belastung.test.ts ein zweites Mal -- bis auf
/// das Minuszeichen, das iOS typografisch schreibt (U+2212).
struct BelastungTests {
    // MARK: - Einheiten

    @Test func dieEinheitNebenDemRadIstKurz() {
        #expect(LoadUnit.kg.kurz == "kg")
        #expect(LoadUnit.watt.kurz == "W")
        #expect(LoadUnit.level.kurz == "Level")
        #expect(LoadUnit.kmh.kurz == "km/h")
        #expect(LoadUnit.pct.kurz == "%")
        #expect(LoadUnit.rpm.kurz == "U/min")
    }

    @Test func nachkommastellenFolgenDerRastungDerEinheit() {
        #expect(LoadUnit.kg.nachkommastellen == 1)
        #expect(LoadUnit.kmh.nachkommastellen == 1)
        #expect(LoadUnit.pct.nachkommastellen == 1)
        #expect(LoadUnit.watt.nachkommastellen == 0)
        #expect(LoadUnit.level.nachkommastellen == 0)
        #expect(LoadUnit.rpm.nachkommastellen == 0)
    }

    @Test func derReglerDerNebenbelastungHatEinenNamen() {
        #expect(LoadUnit.pct.reglername == "Neigung")
        #expect(LoadUnit.rpm.reglername == "Trittfrequenz")
        #expect(LoadUnit.kmh.reglername == "Tempo")
        #expect(LoadUnit.level.reglername == "Stufe")
        #expect(LoadUnit.watt.reglername == "Leistung")
        #expect(LoadUnit.kg.reglername == "Gewicht")
    }

    @Test func dieUmfangsartNebenDemRadIstKurz() {
        #expect(VolumeKind.reps.kurz == "Wdh.")
        #expect(VolumeKind.seconds.kurz == "min")
        #expect(VolumeKind.meters.kurz == "m")
    }

    @Test func dasUmfangsradHatFuerVoiceOverEinenNamen() {
        #expect(VolumeKind.reps.radname == "Wiederholungen")
        #expect(VolumeKind.seconds.radname == "Dauer")
        #expect(VolumeKind.meters.radname == "Strecke")
    }

    @Test func eineUnbekannteEinheitIstEinDekodierfehlerUndKeinStillesKilogramm() {
        // Der Check-Constraint aus Migration 0045 kennt genau sechs
        // Einheiten; eine siebte braucht ohnehin ein App-Update. Ein
        // stilles "kg" schriebe "8,5 kg" an ein Laufband.
        let json = Data(#"["mph"]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([LoadUnit].self, from: json)
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([VolumeKind].self, from: Data(#"["steps"]"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([Kategorie].self, from: Data(#"["mobility"]"#.utf8))
        }
    }

    @Test func dieSechsEinheitenDekodierenAusIhremServernamen() throws {
        let json = Data(#"["kg","watt","level","kmh","pct","rpm"]"#.utf8)
        #expect(try JSONDecoder().decode([LoadUnit].self, from: json) == LoadUnit.allCases)
    }

    // MARK: - Belastung

    @Test func belastungOhneEinheit() {
        #expect(Zahlformat.belastung(80, .kg) == "80,0")
        #expect(Zahlformat.belastung(82.5, .kg) == "82,5")
        #expect(Zahlformat.belastung(120, .watt) == "120")
        #expect(Zahlformat.belastung(8, .level) == "8")
        #expect(Zahlformat.belastung(8.5, .kmh) == "8,5")
        #expect(Zahlformat.belastung(6, .pct) == "6,0")
        #expect(Zahlformat.belastung(85, .rpm) == "85")
    }

    @Test func kilogrammSiehtAusWieDasBisherigeGewicht() {
        // Die Gegenprobe aus Spec Abschnitt 9: die Beinpresse ist nach dem
        // Umbau Zeichen fuer Zeichen dieselbe.
        for kg in [0, 5, 80, 82.5, 200] as [Double] {
            #expect(Zahlformat.belastung(kg, .kg) == Zahlformat.gewicht(kg))
            #expect(Zahlformat.belastungMitEinheit(kg, .kg) == Zahlformat.gewichtMitEinheit(kg))
            #expect(Zahlformat.belastungGesprochen(kg, .kg) == Zahlformat.gewichtGesprochen(kg))
        }
    }

    @Test func belastungMitEinheit() {
        #expect(Zahlformat.belastungMitEinheit(80, .kg) == "80,0 kg")
        #expect(Zahlformat.belastungMitEinheit(120, .watt) == "120 W")
        #expect(Zahlformat.belastungMitEinheit(8, .level) == "Level 8")
        #expect(Zahlformat.belastungMitEinheit(8.5, .kmh) == "8,5 km/h")
        #expect(Zahlformat.belastungMitEinheit(6, .pct) == "6,0 %")
        #expect(Zahlformat.belastungMitEinheit(85, .rpm) == "85 U/min")
    }

    @Test func belastungDeltaTraegtImmerEinVorzeichen() {
        #expect(Zahlformat.belastungDelta(2.5, .kg) == "+2,5 kg")
        #expect(Zahlformat.belastungDelta(-10, .watt) == "−10 W")
        #expect(Zahlformat.belastungDelta(0.5, .kmh) == "+0,5 km/h")
        #expect(Zahlformat.belastungDelta(-0.5, .pct) == "−0,5 %")
        #expect(Zahlformat.belastungDelta(5, .rpm) == "+5 U/min")
        #expect(Zahlformat.belastungDelta(0, .kg) == "+0,0 kg")
    }

    @Test func einLevelDeltaStelltDasWortNach() {
        // "Level 8" ist eine Stufe, "+1 Level" eine Aenderung um eine Stufe.
        #expect(Zahlformat.belastungDelta(1, .level) == "+1 Level")
        #expect(Zahlformat.belastungDelta(-2, .level) == "−2 Level")
    }

    @Test func belastungGesprochenIstEineZeichenketteMitAusgeschriebenerEinheit() {
        #expect(Zahlformat.belastungGesprochen(80, .kg) == "80,0 Kilogramm")
        #expect(Zahlformat.belastungGesprochen(120, .watt) == "120 Watt")
        #expect(Zahlformat.belastungGesprochen(8, .level) == "Level 8")
        #expect(Zahlformat.belastungGesprochen(8.5, .kmh) == "8,5 Kilometer pro Stunde")
        #expect(Zahlformat.belastungGesprochen(6, .pct) == "6,0 Prozent")
        #expect(Zahlformat.belastungGesprochen(85, .rpm) == "85 Umdrehungen pro Minute")
    }

    @Test func einSatzGesprochen() {
        #expect(Zahlformat.satzGesprochen(80, .kg, neben: nil, nil, umfang: 10, .reps)
                == "80,0 Kilogramm, 10 Wiederholungen")
        #expect(Zahlformat.satzGesprochen(8.5, .kmh, neben: 6, .pct, umfang: 1200, .seconds)
                == "8,5 Kilometer pro Stunde bei 6,0 Prozent, 20 Minuten")
    }

    // MARK: - Umfang

    @Test func umfangOhneEinheit() {
        #expect(Zahlformat.umfang(12, .reps) == "12")
        #expect(Zahlformat.umfang(1200, .seconds) == "20:00")
        #expect(Zahlformat.umfang(750, .seconds) == "12:30")
        #expect(Zahlformat.umfang(30, .seconds) == "0:30")
        #expect(Zahlformat.umfang(5400, .seconds) == "90:00")
        #expect(Zahlformat.umfang(2000, .meters) == "2.000")
        #expect(Zahlformat.umfang(20000, .meters) == "20.000")
        #expect(Zahlformat.umfang(500, .meters) == "500")
    }

    @Test func umfangMitEinheit() {
        #expect(Zahlformat.umfangMitEinheit(12, .reps) == "12 Wdh.")
        #expect(Zahlformat.umfangMitEinheit(1200, .seconds) == "20:00 min")
        #expect(Zahlformat.umfangMitEinheit(2000, .meters) == "2.000 m")
    }

    @Test func umfangGesprochen() {
        #expect(Zahlformat.umfangGesprochen(1, .reps) == "1 Wiederholung")
        #expect(Zahlformat.umfangGesprochen(12, .reps) == "12 Wiederholungen")
        #expect(Zahlformat.umfangGesprochen(1200, .seconds) == "20 Minuten")
        #expect(Zahlformat.umfangGesprochen(60, .seconds) == "1 Minute")
        #expect(Zahlformat.umfangGesprochen(30, .seconds) == "30 Sekunden")
        #expect(Zahlformat.umfangGesprochen(750, .seconds) == "12 Minuten 30 Sekunden")
        #expect(Zahlformat.umfangGesprochen(2000, .meters) == "2 Kilometer")
        #expect(Zahlformat.umfangGesprochen(2500, .meters) == "2,5 Kilometer")
        #expect(Zahlformat.umfangGesprochen(750, .meters) == "750 Meter")
    }

    @Test func korridorMitEinheitSagtAuchBeiWiederholungenWasGezaehltWird() {
        #expect(Zahlformat.korridorMitEinheit(8, 12, .reps) == "8 – 12 Wdh.")
        #expect(Zahlformat.korridorMitEinheit(900, 1200, .seconds) == "15 – 20 min")
        #expect(Zahlformat.korridorMitEinheit(2000, 5000, .meters) == "2.000 – 5.000 m")
    }

    // MARK: - Ein Satz in einer Zeile

    @Test func dieNebenbelastungStehtNurWennWertUndEinheitDaSind() {
        #expect(Zahlformat.belastungMitNebenbelastung(8.5, .kmh, neben: 6, .pct) == "8,5 km/h · 6,0 %")
        #expect(Zahlformat.belastungMitNebenbelastung(8, .level, neben: 85, .rpm) == "Level 8 · 85 U/min")
        #expect(Zahlformat.belastungMitNebenbelastung(80, .kg, neben: nil, nil) == "80,0 kg")
        // Halb gesetzt gibt es laut Constraint nicht -- dann lieber keine
        // Zahl als eine ohne Einheit.
        #expect(Zahlformat.belastungMitNebenbelastung(8.5, .kmh, neben: 6, nil) == "8,5 km/h")
        #expect(Zahlformat.belastungMitNebenbelastung(8.5, .kmh, neben: nil, .pct) == "8,5 km/h")
    }

    @Test func malUmfangBrauchtBeiZeitUndStreckeDieEinheit() {
        #expect(Zahlformat.malUmfang(11, .reps) == "× 11")
        #expect(Zahlformat.malUmfang(1200, .seconds) == "× 20:00 min")
        #expect(Zahlformat.malUmfang(2000, .meters) == "× 2.000 m")
    }

    @Test func einSatzInEinerZeile() {
        // Die Beinpresse Zeichen fuer Zeichen wie vor dem Umbau.
        #expect(Zahlformat.satz(77.5, .kg, neben: nil, nil, umfang: 11, .reps) == "77,5 kg × 11")
        #expect(Zahlformat.satz(8.5, .kmh, neben: 6, .pct, umfang: 1200, .seconds)
                == "8,5 km/h · 6,0 % × 20:00 min")
        #expect(Zahlformat.satz(6, .level, neben: nil, nil, umfang: 2000, .meters) == "Level 6 × 2.000 m")
    }

    @Test func korridorNenntDieVorgabeInDerEinheitDerUebung() {
        #expect(Zahlformat.korridor(8, 12, .reps) == "8 – 12")
        // Minuten ohne Sekunden: ein Korridor ist eine Vorgabe, keine
        // Stoppuhr (formatVolumeRange in belastung.ts).
        #expect(Zahlformat.korridor(900, 1200, .seconds) == "15 – 20 min")
        #expect(Zahlformat.korridor(2000, 5000, .meters) == "2.000 – 5.000 m")
    }
}
