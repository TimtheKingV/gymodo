import Foundation
import Testing
@testable import FitnessMember

/// Die Eingabe am Cardio-Geraet (Testnotiz 14.10., 18:45 #7).
@MainActor
struct CardioGeraetModelTests {
    private func cardioModell(enqueue: @escaping (PendingSetWrite) -> Void = { _ in }) -> GeraetModel {
        let bootstrap: BootstrapResponse = GeraetTestdaten.dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],
         "calibrations":[],"lastSets":[{"machineId":"m1","exerciseId":"e1","load":null,"secondaryLoad":null,
           "volume":null,"rir":null,"performedAt":"2026-09-20T10:00:00Z",
           "cardio":{"zeit":600,"strecke":2100,"stufe":7}}]}
        """)
        return GeraetModel(
            station: Station.testCardio("m1", werte: [.zeit, .strecke, .watt], uebungen: Self.rudern),
            uebungId: "e1", token: nil, bootstrap: bootstrap, loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            enqueue: enqueue)
    }

    /// Wie am echten Cardio-Geraet: Sekunden, damit Satzziel 1 gilt.
    private static let rudern = """
    {"id":"e1","name":"Rudern","volumeKind":"seconds","targetMin":600,"targetMax":1200},
    {"id":"e2","name":"Intervall","volumeKind":"meters","targetMin":500,"targetMax":2000}
    """

    private func kraftModell() -> GeraetModel {
        GeraetModel(
            station: Station(maschine: GeraetTestdaten.maschine),
            uebungId: "e1", token: nil, bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
            loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            enqueue: { _ in })
    }

    @Test func derLetzteSatzTextNenntCardioWerteOderNichts() {
        let modell = cardioModell()
        #expect(modell.letzterSatzText(fuer: "e1") == "10:00 · 2,1 km · Stufe 7")
        // Keine Historie an e2: nil, nicht "Noch nie" mit falscher Zahl.
        #expect(modell.letzterSatzText(fuer: "e2") == nil)
    }

    @Test func derRueckblickNenntDieCardioWerteDesLetztenSatzes() {
        #expect(cardioModell().rueckblick?.zuletzt == "10:00 · 2,1 km · Stufe 7")
    }

    @Test func vorbelegtMitDemLetztenMalNurMitWertenDesGeraets() {
        let modell = cardioModell()
        #expect(modell.istCardio)
        #expect(modell.cardioListe == [.zeit, .strecke, .watt])
        #expect(modell.cardio == CardioWerte(zeit: 600, strecke: 2100))   // stufe faellt weg
    }

    @Test func sichernSchicktCardioOhneLoad() async {
        var gesendet: [PendingSetWrite] = []
        let modell = cardioModell(enqueue: { gesendet.append($0) })
        modell.cardioSetzen(.watt, 150)
        await modell.satzSichern(problemFlag: false, problemReason: nil)
        #expect(gesendet.first?.body.cardio == CardioWerte(zeit: 600, strecke: 2100, watt: 150))
        #expect(gesendet.first?.body.load == nil)
        #expect(gesendet.first?.body.volume == nil)
        #expect(modell.phase == .abschluss)
    }

    /// Review Focus 3.
    @Test func weitererSatzBehaeltDieEbenGesichertenWerte() async {
        let modell = cardioModell()
        modell.cardioSetzen(.zeit, 900)
        await modell.satzSichern(problemFlag: false, problemReason: nil)
        modell.weitererSatz()
        #expect(modell.cardio.zeit == 900)
    }

    @Test func ohneWertKeinSichern() {
        let modell = cardioModell()
        for wert in modell.cardioListe { modell.cardioSetzen(wert, nil) }
        #expect(!modell.kannSichern)
    }

    @Test func kraftBleibtBeiDenRaedern() {
        let modell = kraftModell()
        #expect(!modell.istCardio)
        #expect(modell.kannSichern)
    }

    @Test func leereWerteWerdenAuchOhneKnopfNichtGesichert() async {
        var gesendet: [PendingSetWrite] = []
        let modell = cardioModell(enqueue: { gesendet.append($0) })
        for wert in modell.cardioListe { modell.cardioSetzen(wert, nil) }
        await modell.satzSichern(problemFlag: true, problemReason: nil)
        #expect(gesendet.isEmpty)
        #expect(modell.satzAbgelehnt != nil)
        #expect(await modell.satzSichernVorAbschluss() == false)
        #expect(gesendet.isEmpty)
    }

    @Test func weitererSatzAmCardioGeraetOhnePause() async {
        let modell = cardioModell()
        await modell.satzSichern(problemFlag: false, problemReason: nil)
        #expect(modell.phase == .abschluss)
        modell.weitererSatz()
        #expect(modell.phase == .eingabe)
    }

    /// Im Zirkel rueckt auch ein Cardio-Geraet weiter: statt der
    /// Abschlussfrage meldet es den Satz an die Zirkel-Ebene.
    @Test func imZirkelMeldetAuchDasCardioGeraetDenSatz() async {
        let modell = cardioModell()
        var aufrufe = 0
        modell.beiZirkelSatzGesichert = { aufrufe += 1 }
        await modell.satzSichern(problemFlag: false, problemReason: nil)
        #expect(aufrufe == 1)
        #expect(modell.phase == .eingabe)
    }

    @Test func uebungWechselnBelegtCardioNeuVor() {
        let modell = cardioModell()
        modell.cardioSetzen(.zeit, 900)
        modell.uebungWechseln(zu: "e2")
        // e2 hat keinen letzten Satz: leer statt der Werte der Vorgaengeruebung.
        #expect(modell.cardio == CardioWerte())
        modell.uebungWechseln(zu: "e1")
        #expect(modell.cardio == CardioWerte(zeit: 600, strecke: 2100))
    }

    @Test func zeitHinweise() {
        let leer = CardioEingabe.zeit(stunden: 0, minuten: 0, sekunden: 0)
        #expect(CardioWertSheet.hinweis(wert: .zeit, ergebnis: leer, teile: (0, 0, 0)) == nil)
        let zuGross = CardioEingabe.zeit(stunden: 0, minuten: 75, sekunden: 0)
        #expect(CardioWertSheet.hinweis(wert: .zeit, ergebnis: zuGross, teile: (0, 75, 0))?.contains("59") == true)
        let watt = CardioEingabe.zahl("99999", fuer: .watt)
        #expect(CardioWertSheet.hinweis(wert: .watt, ergebnis: watt, teile: (0, 0, 0)) != nil)
    }
}
