import Foundation
import Testing
@testable import FitnessMember

/// Das Modell der einen Karte fuer Training und Planeinheit.
struct EinheitKarteModellTests {
    private func muskel(_ key: String, _ rolle: GeraetMuskel.Rolle = .primary) -> GeraetMuskel {
        GeraetMuskel(key: key, name: key, role: rolle)
    }

    private func katalog() -> [String: [GeraetMuskel]] {
        [
            "bankdruecken": [muskel("pectorals"), muskel("triceps", .secondary)],
            "trizepsdruecken": [muskel("triceps")],
        ]
    }

    private func block(_ uebung: String, saetze: Int) -> SessionSummary.Block {
        let sets = (0..<saetze).map {
            SessionSummary.Block.Set(
                setIndex: $0, load: 50, secondaryLoad: nil, volume: 10, rir: nil,
                problemFlag: false, problemReason: nil, performedAt: "2026-09-08T16:10:00Z",
                cardio: nil)
        }
        return SessionSummary.Block(
            machineId: "m-\(uebung)", machineLabel: uebung, exerciseId: uebung,
            exerciseName: uebung, loadUnit: .kg, secondaryUnit: nil, volumeKind: .reps, sets: sets)
    }

    private func plan() -> Trainingsplan {
        let positionen = [("druecken", "bankdruecken", 6), ("arme", "trizepsdruecken", 2)]
            .enumerated().map { i, p in
                """
                {"key":"A\(i)","baustein":"\(p.0)","rolle":"pflicht","exerciseId":"\(p.1)",
                 "modelId":"em-m","typ":"mehrgelenk","saetze":\(p.2),"wdhVon":8,"wdhBis":12,
                 "reserveVon":1,"reserveBis":3,"pauseSek":90,"aufwaermsatz":false,"dauerMin":null,
                 "hauptmuskeln":[]}
                """
            }.joined(separator: ",")
        let json = """
        {"planId":"p1","studioId":"s1","version":1,"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":{},
         "einheiten":[{"key":"A","geschaetzteMinuten":50,"positionen":[\(positionen)]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    private var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.locale = Locale(identifier: "de_DE")
        return k
    }

    @Test func trainingModellTitelUndZeilen() {
        let teil = SessionSummary(
            id: "s1", startedAt: "2026-09-08T16:04:00Z", completedAt: "2026-09-08T16:51:00Z",
            completedReason: "manual", machineCount: 2, setCount: 8,
            blocks: [block("bankdruecken", saetze: 6), block("trizepsdruecken", saetze: 2)])
        let modell = EinheitKarteModell.training(Trainingskarte(teile: [teil]), muskeln: katalog())

        #expect(modell.art == .training)
        #expect(modell.titel == "Brust, Trizeps")
        #expect(modell.zeilen.count == 2)
        #expect(modell.zustand == .erledigt)
        #expect(modell.tag == nil)
        #expect(modell.stufen["pectorals"] == .stark)
    }

    @Test func laufendErsetztZeilen() {
        let plan = plan()
        let modell = EinheitKarteModell.einheit(
            plan.einheiten[0], namen: EinheitNamen(plan: plan, muskeln: katalog()), muskeln: katalog(),
            tag: nil, zustand: .geplant)
        let laufend = EinheitKarteModell.laufend(modell, fortschritt: "4 von 7 · noch ca. 35 Min")

        #expect(laufend.zeilen == ["4 von 7 · noch ca. 35 Min"])
        #expect(laufend.titel == modell.titel)
        #expect(laufend.stufen == modell.stufen)
        #expect(EinheitKarteModell.laufend(modell, fortschritt: nil) == modell)
    }

    @Test func einheitModell() {
        let plan = plan()
        let namen = EinheitNamen(plan: plan, muskeln: katalog())
        let modell = EinheitKarteModell.einheit(
            plan.einheiten[0], namen: namen, muskeln: katalog(),
            tag: "Freitag, 6. Nov", zustand: .geplant)

        #expect(modell.art == .einheit)
        #expect(modell.titel == "Brust, Trizeps")
        #expect(modell.zeilen == ["2 Übungen · ca. 50 Min"])
        #expect(modell.tag == "Freitag, 6. Nov")
        #expect(modell.zustand == .geplant)
        #expect(modell.stufen["pectorals"] == .stark)
    }

    @Test func erledigteEinheitZeigtErledigt() {
        let plan = plan()
        let modell = EinheitKarteModell.einheit(
            plan.einheiten[0], namen: EinheitNamen(plan: plan, muskeln: katalog()),
            muskeln: katalog(), tag: nil, zustand: .erledigt)

        #expect(modell.zeilen == ["2 Übungen · ca. 50 Min"])
        #expect(EinheitKarteModell.zustandsText(.erledigt, kalender: kalender) == "Erledigt")
    }

    @Test func verpasstText() {
        let freitag = kalender.date(from: DateComponents(year: 2026, month: 11, day: 6))!
        #expect(EinheitKarteModell.zustandsText(.verpasst(verschobenAuf: freitag), kalender: kalender)
            == "verpasst · verschoben auf Fr")
        #expect(EinheitKarteModell.zustandsText(.verpasst(verschobenAuf: nil), kalender: kalender)
            == "verpasst")
        #expect(EinheitKarteModell.zustandsText(.geplant, kalender: kalender) == nil)
    }

    @Test func ueberzeileGeplant() {
        let freitag = kalender.date(from: DateComponents(year: 2026, month: 11, day: 6))!
        #expect(ProfilKopf.ueberzeile(geplantAm: freitag, kalender: kalender)
            == "GEPLANT · FREITAG, 6. NOV")
        #expect(ProfilKopf.ueberzeile(trainiertAm: freitag, kalender: kalender)
            == "FREITAG, 6. NOV")
        #expect(ProfilKopf.startKnopfText(istGeplanterTag: true) == "Training starten")
        #expect(ProfilKopf.startKnopfText(istGeplanterTag: false) == "Jetzt starten (vorziehen)")
    }
}
