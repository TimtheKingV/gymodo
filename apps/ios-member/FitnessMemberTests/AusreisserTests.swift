import Koerperbild
import Testing
@testable import FitnessMember

@Suite struct AusreisserTests {
    private let senkenZuerst = Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken)

    /// n Wiederholungen im Takt; `aenderungen` ueberschreibt einzelne (1-basiert).
    private func rueckblick(_ n: Int, _ aenderungen: [Int: (hin: Tempourteil, rueck: Tempourteil)] = [:],
                            unbewertet: Set<Int> = []) -> Koerperbild.Rueckblick {
        Koerperbild.Rueckblick(urteile: (1...n).map { i in
            let u = aenderungen[i]
            return Wiederholungsurteil(anteilInBahn: 1, imTakt: unbewertet.contains(i) ? nil : u == nil,
                                       hin: u?.hin ?? .imTempo, rueck: u?.rueck ?? .imTempo)
        })
    }

    @Test func zweiZuSchnellBeimSenken() {
        let r = rueckblick(8, [4: (.zuSchnell, .imTempo), 7: (.zuSchnell, .imTempo)])
        #expect(Ausreisser.satz(rueckblick: r, tempo: senkenZuerst)
                == "Bei Wdh. 4 und 7 warst du beim Senken zu schnell. Lass dir die vollen 3 Sekunden.")
    }

    @Test func eineZuLangsamBeimHeben() {
        // Rueckweg = Ablassen = Heben bei senkenZuerst.
        let r = rueckblick(5, [4: (.imTempo, .zuLangsam)])
        #expect(Ausreisser.satz(rueckblick: r, tempo: senkenZuerst)
                == "Bei Wdh. 4 warst du beim Heben zu langsam. Zügiger, etwa 2 Sekunden.")
    }

    @Test func dreiUndMehrMitKommaUndUnd() {
        let r = rueckblick(8, [2: (.zuSchnell, .imTempo), 4: (.zuSchnell, .imTempo), 7: (.zuSchnell, .imTempo)])
        #expect(Ausreisser.satz(rueckblick: r, tempo: senkenZuerst)
                == "Bei Wdh. 2, 4 und 7 warst du beim Senken zu schnell. Lass dir die vollen 3 Sekunden.")
    }

    @Test func reihenfolgeRueckVorHinUndHebenZuerstUebersetzt() {
        // Beginnt mit Heben: Hinweg = Heben, Rueckweg = Senken. Rueck zu schnell geht vor Hin zu schnell.
        let hebenZuerst = Uebungstempo(senken: 2.5, halten: 0, heben: 1.5, beginntMit: .heben)
        let r = rueckblick(6, [2: (.zuSchnell, .imTempo), 5: (.imTempo, .zuSchnell)])
        #expect(Ausreisser.satz(rueckblick: r, tempo: hebenZuerst)
                == "Bei Wdh. 5 warst du beim Senken zu schnell. Lass dir die vollen 2,5 Sekunden.")
    }

    @Test func keineAusreisserWennAlleBewertetSind() {
        #expect(Ausreisser.satz(rueckblick: rueckblick(8), tempo: senkenZuerst) == "Alle Wiederholungen im Takt.")
    }

    @Test func ohneAusreisserAberNichtAlleBewertetKeinSatz() {
        #expect(Ausreisser.satz(rueckblick: rueckblick(5, unbewertet: [1, 2]), tempo: senkenZuerst) == nil)
    }
}
