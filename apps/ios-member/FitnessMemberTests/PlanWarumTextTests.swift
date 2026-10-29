import Foundation
import Testing
@testable import FitnessMember

/// Die Textbausteine hinter "Warum so?" (Trainingsplan Etappe 5): drei
/// Abschnitte, Aufteilung aus Struktur und Gruenden des Plans, Gewicht und
/// Wiederholungen fuer alle Plaene gleich.
@Suite("PlanWarumText")
struct PlanWarumTextTests {
    /// Alle Codes, die `trainingsplan-generator.ts` erzeugt, ohne `struktur_*`.
    static let generatorCodes = [
        "zeit_uebungen", "zeit_saetze_reduziert", "zeit_ergaenzung_entfallen",
        "zeit_aufwaermen_entfallen", "zeit_budget_nicht_ausgeschoepft",
        "fokus_brust", "fokus_ruecken", "fokus_schultern", "fokus_arme", "fokus_po",
        "fokus_beine", "fokus_bauch", "fokus_zweiter_entfallen",
        "abnehmen_cardio_zone", "abnehmen_cardio_gekuerzt", "abnehmen_kein_cardio_geraet",
        "abnehmen_alltag", "bauch_kein_fettabbau", "anfaenger_reserve",
        "beschwerden_meiden", "beschwerden_vorsichtig", "kraft_tage_auf_eins",
    ]

    static func aufteilung(_ struktur: String, _ gruende: [String]) -> [String] {
        PlanWarumText.abschnitte(struktur: struktur, gruende: gruende)[0].absaetze
    }

    @Test func dreiAbschnitte() {
        for gruende in [[], ["zeit_uebungen"]] {
            let titel = PlanWarumText.abschnitte(struktur: "gk_ab", gruende: gruende).map(\.titel)
            #expect(titel == ["Aufteilung", "Gewicht", "Wiederholungen"])
        }
    }

    @Test func leereGruende() {
        #expect(Self.aufteilung("gk_ab", []) == [PlanStrukturText.text("gk_ab")])
    }

    @Test func unbekannteStruktur() {
        #expect(Self.aufteilung("xyz", []).first == PlanStrukturText.text("xyz"))
    }

    @Test func unbekannterCode() {
        let absaetze = Self.aufteilung(
            "gk_ab", ["struktur_ganzkoerper_ab", "zeit_neuer_code", "fokus_xyz", "zeit_uebungen"])
        #expect(absaetze.count == 2)
        #expect(!absaetze.contains { $0.contains("struktur_") || $0.contains("zeit_neuer") })
    }

    @Test func mehrereGruende() {
        let absaetze = Self.aufteilung(
            "gk_ab", ["fokus_po", "fokus_arme", "beschwerden_meiden", "beschwerden_vorsichtig", "fokus_po"])
        #expect(absaetze.count == 5)
        #expect(absaetze[1].contains("Po"))
        #expect(absaetze[2].contains("Arme"))
        #expect(absaetze[3] != absaetze[4])
    }

    @Test func alleGeneratorCodes() {
        for code in Self.generatorCodes {
            #expect(Self.aufteilung("gk_ab", [code]).count == 2, "Code ohne Satz: \(code)")
        }
        let alle = PlanWarumText.abschnitte(struktur: "gk_ab", gruende: Self.generatorCodes)
            .flatMap(\.absaetze)
        #expect(!alle.contains { $0.contains("_") })
    }

    /// Der Plan kommt aus dem Katalog, nicht aus dem Studio: kein Satz nennt
    /// "dein Studio" (die Codes bleiben lesbar, nur die Woerter aendern sich).
    @Test func keinSatzNenntDeinStudio() {
        for code in Self.generatorCodes {
            let absaetze = Self.aufteilung("gk_ab", [code])
            #expect(!absaetze.contains { $0.contains("Studio") }, "Satz nennt das Studio: \(code)")
        }
    }

    /// Review: bei einem gemeldeten Problem steigt das Gewicht nicht, sinkt aber
    /// auch nicht; gesenkt wird erst nach zwei schwachen Trainings, gesteigert
    /// nur mit Luft im letzten Satz (`berechnePlanGewicht`).
    @Test func gewichtTextEntsprichtDerRegel() {
        let gewicht = PlanWarumText.abschnitte(struktur: "gk_ab", gruende: [])[1].absaetze.joined(separator: " ")
        #expect(!gewicht.contains("meldest ein Problem, wird es leichter"))
        #expect(gewicht.contains("Meldest du ein Problem, steigt es nicht"))
        #expect(gewicht.contains("zwei Trainings hintereinander"))
        #expect(gewicht.contains("Luft im letzten Satz"))
    }

    /// Review: `fokus_<bereich>` heisst nur, dass der Schwerpunkt in einer
    /// Einheit unterkam (Ober-/Unterkoerper trennen die Bereiche).
    @Test func schwerpunktSatzVersprichtNichtJedesTraining() {
        let satz = Self.aufteilung("ober_unter", ["fokus_po"])[1]
        #expect(!satz.contains("in jedem Training"))
        #expect(satz.contains("in den passenden Trainings"))
    }

    /// Review: `fokus_arme` und `fokus_zweiter_entfallen` koennen zusammen
    /// vorkommen (zweiter Schwerpunkt passt nur in eine Einheit).
    @Test func zweiterSchwerpunktWidersprichtErstemNicht() {
        let absaetze = Self.aufteilung("gk_ab", ["fokus_po", "fokus_arme", "fokus_zweiter_entfallen"])
        #expect(!absaetze.contains { $0.contains("gilt nur der erste") })
        #expect(absaetze[3].contains("nicht in jedes Training"))
    }

    @Test func gewichtUndWiederholungen() {
        let abschnitte = PlanWarumText.abschnitte(struktur: "gk_ab", gruende: [])
        let gewicht = abschnitte[1].absaetze.joined(separator: " ")
        let wdh = abschnitte[2].absaetze.joined(separator: " ")
        #expect(gewicht.contains("Schätzung"))
        #expect(gewicht.contains("Nach jedem Training"))
        #expect(wdh.contains("8–12") && wdh.contains("10–15"))
        #expect(wdh.contains("drei Wiederholungen mehr"))
    }
}
