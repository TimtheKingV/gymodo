import Foundation
import Testing
@testable import FitnessMember

struct HaeufigkeitTests {
    private let jetzt = Date(timeIntervalSince1970: 1_792_000_000)

    private let muskeln: [String: [GeraetMuskel]] = [
        "bank": [GeraetMuskel(key: "pectorals", name: "Brust", role: .primary),
                 GeraetMuskel(key: "triceps", name: "Trizeps", role: .secondary)],
        "rudern": [GeraetMuskel(key: "lats", name: "Lats", role: .primary),
                   GeraetMuskel(key: "upper_back", name: "Oberer Ruecken", role: .primary)],
        "kern": [GeraetMuskel(key: "deep_core", name: "Tiefer Kern", role: .primary)],
        // Wie im Katalog: Cardio-Uebungen tragen Hauptmuskeln.
        "laufband": [GeraetMuskel(key: "quads", name: "Quads", role: .primary),
                     GeraetMuskel(key: "calves", name: "Waden", role: .secondary)],
    ]

    private func block(_ exerciseId: String, saetze: Int, cardioSaetze: Int = 0) -> SessionSummary.Block {
        let kraft = (0..<saetze).map {
            SessionSummary.Block.Set(setIndex: $0, load: 50, secondaryLoad: nil, volume: 10, rir: nil,
                                     problemFlag: false, problemReason: nil, performedAt: "2026-10-01T10:00:00Z")
        }
        let cardio = (0..<cardioSaetze).map {
            SessionSummary.Block.Set(setIndex: saetze + $0, load: nil, secondaryLoad: nil, volume: nil, rir: nil,
                                     problemFlag: false, problemReason: nil, performedAt: "2026-10-01T10:00:00Z",
                                     cardio: CardioWerte(zeit: 600, strecke: 2000))
        }
        return SessionSummary.Block(
            machineId: nil, machineLabel: "M", exerciseId: exerciseId, exerciseName: exerciseId,
            loadUnit: .kg, secondaryUnit: nil, volumeKind: .reps, sets: kraft + cardio)
    }

    private func session(tageZurueck: Double = 1, startedAt: String? = nil, _ bloecke: [SessionSummary.Block]) -> SessionSummary {
        let start = startedAt ?? ISO8601DateFormatter().string(from: jetzt.addingTimeInterval(-tageZurueck * 86_400))
        return SessionSummary(id: UUID().uuidString, startedAt: start, completedAt: nil, completedReason: nil,
                              machineCount: bloecke.count, setCount: bloecke.reduce(0) { $0 + $1.sets.count },
                              blocks: bloecke)
    }

    private func rechne(_ sessions: [SessionSummary]) -> Haeufigkeit {
        Haeufigkeit.berechne(sessions: sessions, muskeln: muskeln, jetzt: jetzt)
    }

    @Test func hauptmuskelZaehltEineEinheitPoSession() {
        let h = rechne([session([block("bank", saetze: 2)])])
        #expect(h.jeMuskel["pectorals"] == 1)
        #expect(h.jeGruppe[.brust] == 1)
    }

    @Test func unterstuetzenderMuskelBrauchtZweiSaetze() {
        #expect(rechne([session([block("bank", saetze: 1)])]).jeMuskel["triceps"] == nil)
        #expect(rechne([session([block("bank", saetze: 2)])]).jeMuskel["triceps"] == 1)
        #expect(rechne([session([block("bank", saetze: 1), block("bank", saetze: 1)])]).jeMuskel["triceps"] == 1)
    }

    @Test func gruppeZaehltDieEinheitEinmalAuchBeiMehrerenMuskeln() {
        let h = rechne([session([block("rudern", saetze: 3)])])
        #expect(h.jeGruppe[.ruecken] == 1)
        #expect(h.jeMuskel["lats"] == 1)
        #expect(h.jeMuskel["upper_back"] == 1)
    }

    @Test func nurDieLetzten28TageZaehlen() {
        #expect(rechne([session(tageZurueck: 27, [block("bank", saetze: 2)])]).einheiten == 1)
        #expect(rechne([session(tageZurueck: 29, [block("bank", saetze: 2)])]).einheiten == 0)
    }

    @Test func unbekannteUebungenZaehlenNicht() {
        let h = rechne([session([block("unbekannt", saetze: 5)])])
        #expect(h.jeMuskel.isEmpty)
        #expect(h.jeGruppe.isEmpty)
        #expect(h.einheiten == 1)
    }

    @Test func cardioSaetzeZaehlenNichtFuerMuskeln() {
        let h = rechne([session([block("laufband", saetze: 0, cardioSaetze: 3), block("bank", saetze: 2)])])
        #expect(h.jeMuskel["quads"] == nil)
        #expect(h.jeMuskel["calves"] == nil)
        #expect(h.jeGruppe[.beine] == nil)
        #expect(h.jeGruppe[.brust] == 1)
        #expect(h.einheiten == 1)
    }

    @Test func gemischterBlockZaehltNurDieKraftsaetze() {
        // Ein Kraftsatz + zwei Cardio-Saetze: Hauptmuskel ja, Nebenmuskel (braucht zwei) nein.
        let h = rechne([session([block("laufband", saetze: 1, cardioSaetze: 2)])])
        #expect(h.jeMuskel["quads"] == 1)
        #expect(h.jeMuskel["calves"] == nil)
        let bank = rechne([session([block("bank", saetze: 1, cardioSaetze: 4)])])
        #expect(bank.jeMuskel["triceps"] == nil)
    }

    @Test func reineCardioEinheitZaehltNichtZurDatenreife() {
        let cardio = session([block("laufband", saetze: 0, cardioSaetze: 2)])
        let kraft = session([block("bank", saetze: 2)])
        #expect(rechne([cardio]).einheiten == 0)
        #expect(rechne([cardio, cardio, kraft]).einheiten == 1)
        #expect(rechne([cardio, kraft, kraft]).istAuswertbar == false)
    }

    @Test func unlesbaresDatumWirdUebersprungen() {
        #expect(rechne([session(startedAt: "kaputt", [block("bank", saetze: 2)])]).einheiten == 0)
    }

    @Test func auswertbarAbDreiEinheiten() {
        let eine = session([block("bank", saetze: 2)])
        #expect(rechne([eine, eine]).istAuswertbar == false)
        #expect(rechne([eine, eine, eine]).istAuswertbar == true)
    }

    @Test func seltenerMuskelSchluesselUnbekannterSchluesselZaehltNicht() {
        let h = rechne([session([block("kern", saetze: 3)])])
        #expect(h.jeMuskel["deep_core"] == nil)
        #expect(h.jeGruppe.isEmpty)
    }
}
