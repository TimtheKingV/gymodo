import Foundation
import SwiftUI
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

    // MARK: - Beliebige Eintraege (Testnotiz 17.10., #2)

    /// Der Uebungsfortschritt auf Home hat selbst keine Muskeln; die
    /// Gruppierung ordnet ueber eine Nachschlagefunktion.
    @Test func eintraegeOhneEigeneMuskelnGruppierenUeberDieNachschlagefunktion() {
        struct Zeile: Identifiable { let id: String }
        let muskeln: [String: [GeraetMuskel]] = [
            "squat": [GeraetMuskel(key: "quads", name: "Quads", role: .primary)],
            "bank": [GeraetMuskel(key: "pectorals", name: "Brust", role: .primary)],
            "squat2": [GeraetMuskel(key: "glutes", name: "Gluteus", role: .primary)],
        ]
        let zeilen = ["squat", "bank", "squat2", "fremd"].map(Zeile.init)
        let abschnitte = UebungsGruppierung.abschnitte(zeilen, muskeln: { muskeln[$0.id] ?? [] })
        #expect(abschnitte.map(\.gruppe) == [.brust, .beine, .weitere])
        #expect(abschnitte[1].eintraege.map(\.id) == ["squat", "squat2"])
        #expect(UebungsGruppierung.vorhandeneGruppen(zeilen, muskeln: { muskeln[$0.id] ?? [] })
                == [.brust, .beine, .weitere])
        let nurBeine = UebungsGruppierung.abschnitte(zeilen, muskeln: { muskeln[$0.id] ?? [] }, nur: .beine)
        #expect(nurBeine.map(\.gruppe) == [.beine])
    }

    @Test func dieUeberschriftNenntMitFilterAuchDieAnzahl() {
        #expect(MuskelAbschnitte<GeraetUebung, EmptyView>.kopf(gruppe: .beine, anzahl: 3, gefiltert: false) == "BEINE")
        #expect(MuskelAbschnitte<GeraetUebung, EmptyView>.kopf(gruppe: .beine, anzahl: 1, gefiltert: true) == "BEINE · 1 ÜBUNG")
        #expect(MuskelAbschnitte<GeraetUebung, EmptyView>.kopf(gruppe: .beine, anzahl: 3, gefiltert: true) == "BEINE · 3 ÜBUNGEN")
    }
}
