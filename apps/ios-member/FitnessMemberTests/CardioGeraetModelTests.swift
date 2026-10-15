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
            station: Station.testCardio("m1", werte: [.zeit, .strecke, .watt]),
            uebungId: "e1", token: nil, bootstrap: bootstrap, loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            enqueue: enqueue,
            // Die Testmaschine hat keine Uebung, also gaelte .reps; ein echtes
            // Cardio-Geraet hat Sekunden oder Meter und damit Satzziel 1.
            satzZiel: { 1 })
    }

    private func kraftModell() -> GeraetModel {
        GeraetModel(
            station: Station(maschine: GeraetTestdaten.maschine),
            uebungId: "e1", token: nil, bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
            loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            enqueue: { _ in })
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
}
