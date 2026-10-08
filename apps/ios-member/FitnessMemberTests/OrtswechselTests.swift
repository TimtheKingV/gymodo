import Foundation
import Testing
@testable import FitnessMember

@MainActor
struct OrtswechselTests {
    private let jetzt = Date()

    private func einheit(ort: Ort?) -> LokaleSession {
        LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [], ort: ort)
    }

    @Test func ohneOffeneEinheitGiltSofort() {
        #expect(Ortswechsel.pruefen(ziel: .studio("a"), aktuell: .freiesTraining,
                                    offeneEinheit: nil) == .sofort)
    }

    @Test func amSelbenOrtGiltSofort() {
        #expect(Ortswechsel.pruefen(ziel: .studio("a"), aktuell: .freiesTraining,
                                    offeneEinheit: einheit(ort: .studio("a"))) == .sofort)
        #expect(Ortswechsel.pruefen(ziel: .freiesTraining, aktuell: .studio("a"),
                                    offeneEinheit: einheit(ort: .freiesTraining)) == .sofort)
    }

    @Test func amAnderenOrtMussErstBeendetWerden() {
        #expect(Ortswechsel.pruefen(ziel: .studio("b"), aktuell: .studio("a"),
                                    offeneEinheit: einheit(ort: .studio("a")))
                == .erstBeenden(laufenderOrt: .studio("a")))
        #expect(Ortswechsel.pruefen(ziel: .studio("a"), aktuell: .studio("a"),
                                    offeneEinheit: einheit(ort: .freiesTraining))
                == .erstBeenden(laufenderOrt: .freiesTraining))
    }

    // Eine Datei von vor dem Katalog kennt keinen Ort: die Einheit zaehlt
    // als am aktuellen Ort, sonst haette ein App-Update einen Dialog erzwungen.
    @Test func eineEinheitOhneOrtGiltAlsAmAktuellenOrt() {
        let alt = einheit(ort: nil)
        #expect(Ortswechsel.pruefen(ziel: .studio("a"), aktuell: .studio("a"),
                                    offeneEinheit: alt) == .sofort)
        #expect(Ortswechsel.pruefen(ziel: .studio("b"), aktuell: .studio("a"),
                                    offeneEinheit: alt)
                == .erstBeenden(laufenderOrt: .studio("a")))
    }

    @Test func alteSessionDateiOhneOrtDekodiert() throws {
        let json = """
        {"id":"\(UUID().uuidString)","startedAt":0,"bloecke":[]}
        """
        let s = try JSONDecoder().decode(LokaleSession.self, from: Data(json.utf8))
        #expect(s.ort == nil)
    }

    @Test func ortUeberlebtKodierenUndDekodieren() throws {
        let s = einheit(ort: .studio("a"))
        let zurueck = try JSONDecoder().decode(LokaleSession.self,
                                               from: JSONEncoder().encode(s))
        #expect(zurueck.ort == .studio("a"))
    }

    private func store() -> (WorkoutSessionStore, URL) {
        let v = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (WorkoutSessionStore(fileStore: SessionFileStore(directory: v)), v)
    }

    private func satz(_ sut: WorkoutSessionStore, ort: Ort?) {
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                            einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                            problemFlag: false, problemReason: nil, jetzt: jetzt, ort: ort)
    }

    @Test func derErsteSatzMerktSichDenOrtUndSpeichertIhn() {
        let (sut, v) = store()
        satz(sut, ort: .studio("a"))
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == .studio("a"))
        let neu = WorkoutSessionStore(fileStore: SessionFileStore(directory: v))
        #expect(neu.aktiveSession(jetzt: jetzt)?.ort == .studio("a"))
    }

    @Test func spaetereSaetzeUeberschreibenDenOrtNicht() {
        let (sut, _) = store()
        satz(sut, ort: .studio("a"))
        satz(sut, ort: .studio("b"))
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == .studio("a"))
    }

    @Test func einSatzOhneOrtLaesstDenOrtOffenUndSpaeterWirdErGesetzt() {
        let (sut, _) = store()
        satz(sut, ort: nil)
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == nil)
        satz(sut, ort: .freiesTraining)
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == .freiesTraining)
    }
}
