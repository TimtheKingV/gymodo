import Foundation
import Testing
@testable import FitnessMember

struct UebungsGruppierungTests {
    private func uebung(_ id: String, _ muskeln: [(String, GeraetMuskel.Rolle)]) -> GeraetUebung {
        GeraetUebung(id: id, name: id, volumeKind: .reps, targetMin: 8, targetMax: 12, videoURL: nil,
                     muscles: muskeln.map { GeraetMuskel(key: $0.0, name: $0.0, role: $0.1) })
    }

    @Test func gruppenstehenInFesterReihenfolge() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("curl", [("biceps", .primary)]),
            uebung("squat", [("quads", .primary)]),
            uebung("bank", [("pectorals", .primary)]),
            uebung("press", [("deltoid_anterior", .primary)]),
            uebung("rudern", [("lats", .primary)]),
            uebung("crunch", [("abs", .primary)]),
        ])
        #expect(gruppen.map(\.gruppe) == [.brust, .ruecken, .schultern, .arme, .beine, .rumpf])
    }

    @Test func gleicheMuskelnStehenInnerhalbDerGruppeZusammen() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("hyper", [("erectors", .primary)]),
            uebung("rudern", [("lats", .primary)]),
            uebung("shrug", [("upper_back", .primary)]),
            uebung("pullover", [("lats", .primary)]),
            uebung("goodmorning", [("erectors", .primary)]),
        ])
        #expect(gruppen.count == 1)
        #expect(gruppen[0].uebungen.map(\.id) == ["rudern", "pullover", "shrug", "hyper", "goodmorning"])
    }

    @Test func armeSortierenBizepsVorTrizepsVorUnterarm() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("handgelenk", [("forearms", .primary)]),
            uebung("dips", [("triceps", .primary)]),
            uebung("curl", [("biceps", .primary)]),
        ])
        #expect(gruppen[0].uebungen.map(\.id) == ["curl", "dips", "handgelenk"])
    }

    @Test func hauptmuskelEntscheidetNichtDerUnterstuetzende() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("bank", [("triceps", .secondary), ("pectorals", .primary)]),
        ])
        #expect(gruppen.map(\.gruppe) == [.brust])
    }

    @Test func ersterDarstellbarerHauptmuskelZaehlt() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("mix", [("deep_core", .primary), ("hamstrings", .primary), ("abs", .primary)]),
        ])
        #expect(gruppen.map(\.gruppe) == [.beine])
    }

    @Test func ohneHauptrolleZaehltDerErsteBekannteMuskel() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("x", [("calves", .secondary)]),
        ])
        #expect(gruppen.map(\.gruppe) == [.beine])
    }

    @Test func ohneMuskelnOderMitUnbekanntenKommenSieUnterWeitere() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("leer", []),
            uebung("fremd", [("deep_core", .primary)]),
            uebung("curl", [("biceps", .primary)]),
        ])
        #expect(gruppen.map(\.gruppe) == [.arme, .weitere])
        #expect(gruppen[1].uebungen.map(\.id) == ["leer", "fremd"])
    }

    @Test func leereGruppenEntfallenUndEingabereihenfolgeBleibtBeiGleichemMuskel() {
        let gruppen = UebungsGruppierung.gruppieren([
            uebung("b", [("biceps", .primary)]),
            uebung("a", [("biceps", .primary)]),
        ])
        #expect(gruppen.count == 1)
        #expect(gruppen[0].uebungen.map(\.id) == ["b", "a"])
    }

    @Test func nurAbSechsUebungenGibtEsDenSchalter() {
        #expect(UebungsGruppierung.bietetSchalterAn(uebungsanzahl: 5) == false)
        #expect(UebungsGruppierung.bietetSchalterAn(uebungsanzahl: 6) == true)
    }
}
