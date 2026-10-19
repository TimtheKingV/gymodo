import Foundation
import Testing
@testable import FitnessMember

/// Testnotiz 14.10., 18:45 #7: Cardio-Werte in der App.
struct CardioTests {
    @Test func dieReihenfolgeIstDieDesServers() {
        #expect(CardioWert.allCases.map(\.rawValue) == ["zeit", "strecke", "stufe", "stufenanzahl", "kmh", "steigung", "watt", "frequenz", "kcal"])
    }

    @Test func werteLassenSichJeSchluesselSetzen() {
        var w = CardioWerte()
        w[.zeit] = 510
        w[.kmh] = 10.5
        #expect(w.zeit == 510)
        #expect(w.kmh == 10.5)
        #expect(!w.istLeer)
        w[.zeit] = nil
        w[.kmh] = nil
        #expect(w.istLeer)
    }

    /// Review Focus 5: ein Satz ohne load (Cardio) bricht weder Bootstrap noch Verlauf.
    @Test func lastSetMitLoadNullDekodiert() throws {
        let json = #"{"machineId":"m","exerciseId":"e","load":null,"secondaryLoad":null,"volume":null,"rir":null,"performedAt":"2026-10-15T10:00:00Z","cardio":{"zeit":510,"strecke":2000}}"#
        let s = try JSONDecoder().decode(BootstrapResponse.LastSet.self, from: Data(json.utf8))
        #expect(s.load == nil)
        #expect(s.cardio?.strecke == 2000)
    }

    @Test func alterVerlaufOhneCardioDekodiert() throws {
        let json = #"{"setIndex":1,"load":40,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:00:00Z"}"#
        let s = try JSONDecoder().decode(SessionSummary.Block.Set.self, from: Data(json.utf8))
        #expect(s.load == 40)
        #expect(s.cardio == nil)
    }

    /// Final-Review D: jede Antwort, die einen Cardio-Satz traegt, dekodiert "load":null.
    @Test func recordedSetMitLoadNullDekodiert() throws {
        let json = #"{"id":"s","studioId":"st","userId":"u","sessionId":"se","machineId":"m","equipmentModelId":"em","exerciseId":"e","setIndex":1,"load":null,"secondaryLoad":null,"volume":null,"cardio":{"zeit":510,"watt":150},"rir":null,"problemFlag":false,"problemReason":null,"volumeSource":"eingegeben","volumeCounted":null,"performedAt":"2026-10-15T10:00:00Z"}"#
        let s = try JSONDecoder().decode(RecordedSet.self, from: Data(json.utf8))
        #expect(s.load == nil)
        #expect(s.volume == nil)
        #expect(s.cardio == CardioWerte(zeit: 510, watt: 150))
    }

    @Test func historienEintragMitLoadNullDekodiert() throws {
        let json = #"{"performedOn":"2026-10-15","load":null,"secondaryLoad":null,"volume":[],"cardio":{"zeit":510,"strecke":2000}}"#
        let h = try JSONDecoder().decode(TagContextResponse.HistoryEntry.self, from: Data(json.utf8))
        #expect(h.load == nil)
        #expect(h.volume.isEmpty)
        #expect(h.cardio == CardioWerte(zeit: 510, strecke: 2000))
    }

    @Test func verlaufssatzMitLoadNullDekodiert() throws {
        let json = #"{"setIndex":1,"load":null,"secondaryLoad":null,"volume":null,"cardio":{"zeit":600,"kmh":10.5},"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-10-15T10:00:00Z"}"#
        let s = try JSONDecoder().decode(SessionSummary.Block.Set.self, from: Data(json.utf8))
        #expect(s.load == nil)
        #expect(s.volume == nil)
        #expect(s.cardio == CardioWerte(zeit: 600, kmh: 10.5))
    }

    @Test func lokalerCardioSatzUebersteht() throws {
        let satz = LokalerSatz(
            id: UUID(), setIndex: 1, load: nil, secondaryLoad: nil, volume: nil,
            cardio: CardioWerte(zeit: 510, strecke: 2000), rir: nil, problemFlag: false,
            problemReason: nil, performedAt: Date(timeIntervalSince1970: 1_792_000_000))
        let daten = try JSONEncoder().encode(satz)
        let zurueck = try JSONDecoder().decode(LokalerSatz.self, from: daten)
        #expect(zurueck == satz)
        #expect(zurueck.load == nil)
        #expect(zurueck.cardio?.strecke == 2000)
    }

    @Test func modellOhneCardioWerteIstKraft() throws {
        // Ein Server von vor E2 schickt das Feld nicht.
        #expect(Station.testGeraet("m").equipmentModel.cardioWerte.isEmpty)
    }

    @Test func modellMitCardioWerteIgnoriertUnbekannte() throws {
        let station = Station.testCardio("c", werte: [.zeit, .kmh])
        #expect(station.equipmentModel.cardioWerte == [.zeit, .kmh])
        let json = #"{"id":"t","name":"T","manufacturer":null,"photoPath":null,"category":"cardio","loadUnit":"level","loadStep":1,"loadMin":1,"loadMax":null,"settingDefinitions":[],"exercises":[],"cardioWerte":["zeit","zukunft","watt"]}"#
        let typ = try JSONDecoder().decode(BootstrapResponse.Catalog.EquipmentType.self, from: Data(json.utf8))
        #expect(typ.cardioWerte == [.zeit, .watt])
        #expect(Station(typ: typ, studioId: nil).equipmentModel.cardioWerte == [.zeit, .watt])
    }

    @Test func setWriteSchicktCardioOhneLoad() throws {
        let body = SetWrite(machineId: "m", exerciseId: "e", setIndex: 1, load: nil, volume: nil,
                            cardio: CardioWerte(zeit: 510))
        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        #expect(json.contains(#""cardio":{"zeit":510}"#))
        #expect(!json.contains(#""load""#))
    }

    @Test func alteWarteschlangeMitLoadDekodiert() throws {
        let json = #"{"machineId":"m","exerciseId":"e","setIndex":1,"load":5,"volume":1200,"problemFlag":false,"volumeSource":"eingegeben"}"#
        let body = try JSONDecoder().decode(SetWrite.self, from: Data(json.utf8))
        #expect(body.load == 5)
        #expect(body.cardio == nil)
    }

    @Test func dieZeileFolgtDerFestenReihenfolge() {
        let w = CardioWerte(zeit: 510, strecke: 2000, stufe: 5, watt: 142)
        #expect(Zahlformat.cardio(w) == "8:30 · 2,0 km · Stufe 5 · 142 W")
        #expect(Zahlformat.cardioGesprochen(w) == "8 Minuten 30 Sekunden, 2,0 Kilometer, Stufe 5, 142 Watt")
    }

    @Test func einzelneWerte() {
        #expect(Zahlformat.cardioWert(.zeit, 3900) == "1:05:00")
        #expect(Zahlformat.cardioWert(.strecke, 850) == "850 m")
        #expect(Zahlformat.cardioWert(.strecke, 12_340) == "12,3 km")
        #expect(Zahlformat.cardioWert(.kmh, 10.5) == "10,5 km/h")
        #expect(Zahlformat.cardioWert(.steigung, -2) == "−2,0 %")
        #expect(Zahlformat.cardioWert(.frequenz, 85) == "85 /min")
        #expect(Zahlformat.cardioWert(.kcal, 310) == "310 kcal")
    }

    /// Testnotiz 18.10., #5: Anzahl Stufen am Treppensteiger.
    @Test func anzahlStufenAmTreppensteiger() throws {
        var w = CardioWerte()
        w[.stufenanzahl] = 120
        #expect(w.stufenanzahl == 120)
        #expect(Zahlformat.cardioWert(.stufenanzahl, 120) == "120 Stufen")
        #expect(Zahlformat.cardioGesprochen(w) == "120 Stufen")
        #expect(Zahlformat.cardioTeile(.stufenanzahl, 120).einheit == "Stufen")
        #expect(CardioWert.stufenanzahl.name == "Anzahl Stufen")
        #expect(CardioWert.stufenanzahl.bereich == 1...10_000)
        // Der Schluessel auf dem Draht ist der des Servers.
        let json = try JSONEncoder().encode(w)
        #expect(String(decoding: json, as: UTF8.self).contains("\"stufenanzahl\":120"))
        if case .failure = CardioEingabe.zahl("0", fuer: .stufenanzahl) {} else { Issue.record("0 Stufen muessen abgelehnt werden") }
        if case .failure = CardioEingabe.zahl("12,5", fuer: .stufenanzahl) {} else { Issue.record("halbe Stufen muessen abgelehnt werden") }
        #expect((try CardioEingabe.zahl("120", fuer: .stufenanzahl).get()) == 120)
    }

    @Test func zahlOhneEinheitFuerDasEingabefeld() {
        #expect(Zahlformat.cardioZahl(.kmh, 10.5) == "10,5")
        #expect(Zahlformat.cardioZahl(.steigung, -2) == "−2,0")
        #expect(Zahlformat.cardioZahl(.watt, 142) == "142")
    }

    /// Review Focus 4.
    @Test func eingabeMitKommaPunktUndGrenzen() {
        #expect(CardioEingabe.zahl("10,5", fuer: .kmh) == .success(10.5))
        #expect(CardioEingabe.zahl("10.5", fuer: .kmh) == .success(10.5))
        #expect(CardioEingabe.zahl("", fuer: .kmh) == .failure(.leer))
        #expect(CardioEingabe.zahl("abc", fuer: .watt) == .failure(.keineZahl))
        #expect(CardioEingabe.zahl("51", fuer: .kmh) == .failure(.ausserhalb("Höchstens 50 km/h.")))
        #expect(CardioEingabe.zahl("142,5", fuer: .watt) == .failure(.keineZahl))
        #expect(CardioEingabe.zahl("-11", fuer: .steigung) == .failure(.ausserhalb("Mindestens −10 %.")))
        #expect(CardioEingabe.zahl("nan", fuer: .kmh) == .failure(.keineZahl))
    }

    @Test func zeitHinUndZurueck() {
        #expect(CardioEingabe.zeit(stunden: 0, minuten: 8, sekunden: 30) == .success(510))
        #expect(CardioEingabe.zeit(stunden: 0, minuten: 0, sekunden: 0) == .failure(.ausserhalb("Mindestens 1 Sekunde.")))
        #expect(CardioEingabe.zeit(stunden: 0, minuten: 8, sekunden: 60) == .failure(.keineZahl))
        let t = CardioEingabe.zeitTeile(3900)
        #expect(t.h == 1 && t.m == 5 && t.s == 0)
    }

    /// Testnotiz 15.10., #2: Stunden springen nach einer Ziffer (auch bei 0),
    /// Minuten nach zwei, Sekunden nie.
    @Test func cursorSpringtNachDerRegel() {
        #expect(!CardioEingabe.springt(von: .stunden, text: ""))
        #expect(CardioEingabe.springt(von: .stunden, text: "0"))
        #expect(CardioEingabe.springt(von: .stunden, text: "1"))
        #expect(!CardioEingabe.springt(von: .minuten, text: "1"))
        #expect(CardioEingabe.springt(von: .minuten, text: "12"))
        #expect(!CardioEingabe.springt(von: .sekunden, text: "59"))
    }

    /// Testnotiz 15.10., #3: Kilometer und Meter.
    @Test func streckeAusKilometerUndMeter() {
        #expect(CardioEingabe.strecke(kilometer: 2, meter: 500) == .success(2500))
        #expect(CardioEingabe.strecke(kilometer: 0, meter: 850) == .success(850))
        #expect(CardioEingabe.strecke(kilometer: 0, meter: 0) == .failure(.ausserhalb("Mindestens 1 m.")))
        #expect(CardioEingabe.strecke(kilometer: 1, meter: 1000) == .failure(.keineZahl))
        #expect(CardioEingabe.strecke(kilometer: 201, meter: 0) == .failure(.ausserhalb("Höchstens 200 km.")))
        #expect(CardioEingabe.strecke(kilometer: Int.max, meter: 0) == .failure(.ausserhalb("Höchstens 200 km.")))
        let t = CardioEingabe.streckeTeile(12_300)
        #expect(t.km == 12 && t.m == 300)
    }

    /// Testnotiz 15.10., #4: Zahl und Einheit getrennt, auch leer.
    @Test func kachelTeileTragenDieEinheit() {
        #expect(Zahlformat.cardioTeile(.zeit, 510) == ("8:30", "min"))
        #expect(Zahlformat.cardioTeile(.zeit, 3900) == ("1:05:00", "h"))
        #expect(Zahlformat.cardioTeile(.zeit, nil) == ("–", "min"))
        #expect(Zahlformat.cardioTeile(.strecke, 850) == ("850", "m"))
        #expect(Zahlformat.cardioTeile(.strecke, 2500) == ("2,5", "km"))
        #expect(Zahlformat.cardioTeile(.kmh, 10.5) == ("10,5", "km/h"))
        #expect(Zahlformat.cardioTeile(.watt, nil) == ("–", "W"))
    }

    /// Final-Review E: riesige Stunden duerfen nicht ueberlaufen (Trap).
    @Test func zeitMitRiesigenStundenIstAusserhalb() {
        #expect(CardioEingabe.zeit(stunden: 24, minuten: 0, sekunden: 0) == .success(86_400))
        #expect(CardioEingabe.zeit(stunden: 25, minuten: 0, sekunden: 0) == CardioEingabe.zeit(stunden: 24, minuten: 0, sekunden: 1))
        #expect(CardioEingabe.zeit(stunden: Int.max, minuten: 59, sekunden: 59) == CardioEingabe.zeit(stunden: 24, minuten: 0, sekunden: 1))
        if case .failure(.ausserhalb) = CardioEingabe.zeit(stunden: Int.max, minuten: 0, sekunden: 0) {} else {
            Issue.record("Erwartet: ausserhalb")
        }
    }

    @Test func minusZeichenUndRundreise() {
        #expect(CardioEingabe.zahl("−2,5", fuer: .steigung) == .success(-2.5))
        #expect(CardioEingabe.zahl("-2,5", fuer: .steigung) == .success(-2.5))
        #expect(CardioEingabe.zahl("–2,5", fuer: .steigung) == .success(-2.5))
        for (w, x) in [(CardioWert.steigung, -2.0), (.steigung, 7.5), (.kmh, 10.5), (.watt, 142), (.kcal, 1500), (.strecke, 2000)] {
            #expect(CardioEingabe.zahl(Zahlformat.cardioZahl(w, x), fuer: w) == .success(x))
        }
    }

    @Test func tausenderpunktUndFremdzeichen() {
        #expect(CardioEingabe.zahl("1.000", fuer: .watt) == .success(1000))
        #expect(CardioEingabe.zahl("12.345", fuer: .strecke) == .success(12345))
        #expect(CardioEingabe.zahl("1.000", fuer: .kmh) == .success(1))
        #expect(CardioEingabe.zahl("1e3", fuer: .watt) == .failure(.keineZahl))
        #expect(CardioEingabe.zahl("0x10", fuer: .watt) == .failure(.keineZahl))
        #expect(CardioEingabe.zahl("1-2", fuer: .watt) == .failure(.keineZahl))
    }
}
