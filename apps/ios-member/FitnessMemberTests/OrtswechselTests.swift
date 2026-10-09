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

    // MARK: - Satzschutz: ein Geraet gehoert nicht in eine Einheit anderswo

    @Test func einGeraetImStudioDerEinheitIstErlaubt() {
        #expect(Ortswechsel.satzKonflikt(station: .testGeraet("m1", studioId: "a"),
                                         offeneEinheit: einheit(ort: .studio("a"))) == nil)
        // Ohne Einheit oder ohne Ort setzt der erste Satz den Ort.
        #expect(Ortswechsel.satzKonflikt(station: .testGeraet("m1", studioId: "a"),
                                         offeneEinheit: nil) == nil)
        #expect(Ortswechsel.satzKonflikt(station: .testGeraet("m1", studioId: "a"),
                                         offeneEinheit: einheit(ort: nil)) == nil)
    }

    /// Der Server weist den Satz sicher ab (die Einheit traegt ein anderes
    /// Studio) -- er darf gar nicht erst geschrieben werden.
    @Test func einGeraetAusEinemAnderenStudioIstEinKonflikt() {
        #expect(Ortswechsel.satzKonflikt(station: .testGeraet("m1", studioId: "b"),
                                         offeneEinheit: einheit(ort: .studio("a"))) == .studio("a"))
        #expect(Ortswechsel.satzKonflikt(station: .testGeraet("m1", studioId: "b"),
                                         offeneEinheit: einheit(ort: .freiesTraining)) == .freiesTraining)
    }

    /// Ein Typ nimmt den Ort der Einheit an; der Server nimmt ihn dort an.
    @Test func einTypIstNieEinKonflikt() {
        #expect(Ortswechsel.satzKonflikt(station: .testTyp("t1", studioId: "b"),
                                         offeneEinheit: einheit(ort: .studio("a"))) == nil)
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

    private func satz(_ sut: WorkoutSessionStore, studioId: String?) {
        _ = sut.satzSichern(station: studioId.map { .testGeraet("m1", studioId: $0) } ?? .testTyp("t1", studioId: nil), exerciseId: "e1",
                            einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                            problemFlag: false, problemReason: nil, jetzt: jetzt)
    }

    @Test func derErsteSatzMerktSichDenOrtUndSpeichertIhn() {
        let (sut, v) = store()
        satz(sut, studioId: "a")
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == .studio("a"))
        let neu = WorkoutSessionStore(fileStore: SessionFileStore(directory: v))
        #expect(neu.aktiveSession(jetzt: jetzt)?.ort == .studio("a"))
    }

    @Test func spaetereSaetzeUeberschreibenDenOrtNicht() {
        let (sut, _) = store()
        satz(sut, studioId: "a")
        satz(sut, studioId: "b")
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == .studio("a"))
    }

    @Test func eineStationOhneStudioMachtDieEinheitZumFreienTraining() {
        let (sut, _) = store()
        satz(sut, studioId: nil)
        #expect(sut.aktiveSession(jetzt: jetzt)?.ort == .freiesTraining)
    }
}
