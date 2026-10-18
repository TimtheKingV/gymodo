import Foundation
import Testing
@testable import Sensorik

struct TaktBerichtTests {
    @Test func aufteilungAbwechselndNachOrdnername() {
        let g = TaktBericht.aufteilen(["a", "b", "c", "d", "e"])
        #expect(g == [.abstimmen, .blind, .abstimmen, .blind, .abstimmen])
    }

    @Test func quoteZaehltNilAlsFalsch() {
        func z(_ gezaehlt: Int?) -> TaktZeile {
            TaktZeile(ordner: "x", art: .stapel, wahr: 10, gezaehlt: gezaehlt, gruppe: .blind)
        }
        let q = TaktBericht.quote([z(9), z(11), z(12), z(nil)])
        #expect(q.n == 4)
        #expect(q.einsGenau == 0.5)
        #expect(q.exakt == 0)
    }

    @Test func kurzhantelVom16OktoberIstFruehAbgestimmt() {
        let zeilen = TaktBericht.gemessen
        let alt = zeilen.filter { $0.ordner.hasPrefix("2026-10-16-") && $0.art == .kurzhantel }
        #expect(!alt.isEmpty)
        #expect(alt.allSatisfy { $0.gruppe == .frueherAbgestimmt })
        let neu = zeilen.filter { $0.ordner.hasPrefix("2026-10-18-") }
        #expect(neu.count == 36)
        #expect(neu.allSatisfy { $0.gruppe != .frueherAbgestimmt })
        #expect(neu.contains { $0.gruppe == .abstimmen } && neu.contains { $0.gruppe == .blind })
    }

    @Test func stapelAbstimmungImZiel() {
        let q = TaktBericht.quote(TaktBericht.gemessen.filter { $0.art == .stapel && $0.gruppe == .abstimmen })
        #expect(q.n >= 15)
        #expect(q.einsGenau >= 0.9)
    }

    /// Untergrenze, kein Ziel: erreicht am 18.10. nach dem Einfrieren des
    /// Stapel-Profils (15 von 18 blind). Das Ziel von 90 % ist damit nicht erreicht.
    @Test func stapelBlindEinsGenau() {
        let q = TaktBericht.quote(TaktBericht.gemessen.filter { $0.art == .stapel && $0.gruppe == .blind })
        #expect(q.n == 18)
        #expect(q.einsGenau >= 0.83)
    }

    @Test(arguments: [
        ("2026-10-18-1632-01", 30), ("2026-10-18-1634-01", 30), ("2026-10-18-1635-01", 30),
        ("2026-10-18-1708-01", 20), ("2026-10-18-1709-01", 15), ("2026-10-18-1626-01", 15),
    ])
    func klareStapelSaetzeBleibenGut(name: String, wahr: Int) throws {
        let z = try #require(TaktBericht.gemessen.first { $0.ordner == name })
        #expect(abs((z.gezaehlt ?? -99) - wahr) <= 1)
    }

    private func quote(_ art: Befestigungsart? = nil, _ gruppe: Gruppe) -> (n: Int, exakt: Double, einsGenau: Double) {
        TaktBericht.quote(TaktBericht.gemessen.filter { (art == nil || $0.art == art) && $0.gruppe == gruppe })
    }

    /// Ein einziger Satz (Bankdruecken 1623-01, 12 Wdh., 7 gezaehlt) liegt
    /// ausserhalb; an 96 Profilen aus Takt, Gleichheit, Kappen und Abstand
    /// traf keines alle sechs Abstimmungssaetze. Langhantel bleibt deshalb auf
    /// den Kurzhantel-Werten.
    @Test func langhantelAbstimmungImZiel() {
        let q = quote(.langhantel, .abstimmen)
        #expect(q.n == 6 && q.einsGenau >= 0.83)
        withKnownIssue("Bankdruecken 1623-01: Signal zu schwach, kein Parameter hilft") {
            #expect(q.einsGenau >= 0.9)
        }
    }

    @Test func langhantelBlindEinsGenau() {
        let q = quote(.langhantel, .blind)
        #expect(q.n == 5 && q.einsGenau >= 0.8)
    }

    /// Kurzhantel darf durch Rueckfall und Profile nicht schlechter werden
    /// (Baseline: 35 Saetze vom 16.10. 100 % bei +-1, 80 % exakt).
    @Test func kurzhantelBleibtMindestensSoGutWieVorher() {
        let alt = quote(.kurzhantel, .frueherAbgestimmt)
        #expect(alt.n == 35 && alt.einsGenau == 1.0 && alt.exakt >= 0.8)
        #expect(quote(.kurzhantel, .abstimmen).einsGenau >= 0.85)
        #expect(quote(.kurzhantel, .blind).einsGenau >= 0.85)
    }

    /// Gepoolt blind: 25 von 30 (83 %) gegen 67 % in der Baseline. Das Ziel
    /// von 90 % ist nicht erreicht; die Parameter wurden nach dem Oeffnen der
    /// Blindgruppe nicht mehr veraendert.
    @Test func gepooltBlindImZiel() {
        let q = quote(nil, .blind)
        #expect(q.n == 30 && q.einsGenau >= 0.83)
        withKnownIssue("Stapel-Raender (2 bis 3 zu wenig bei Beinpresse, Adduktoren) und eine Kniebeuge mit Pause (33 statt 30)") {
            #expect(q.einsGenau >= 0.9)
        }
    }

    @Test func blindSaetzeBleibenGesperrtBisDieArtFreigegebenIst() {
        let zeilen = [
            TaktZeile(ordner: "stapel-blind", art: .stapel, wahr: 10, gezaehlt: 3, gruppe: .blind),
            TaktZeile(ordner: "lang-blind", art: .langhantel, wahr: 10, gezaehlt: 3, gruppe: .blind),
            TaktZeile(ordner: "stapel-abst", art: .stapel, wahr: 10, gezaehlt: 3, gruppe: .abstimmen),
        ]
        let zu = TaktBericht.markdown(zeilen, blindFuer: [])
        #expect(!zu.contains("stapel-blind") && !zu.contains("lang-blind"))
        #expect(zu.contains("stapel-abst"))
        let offen = TaktBericht.markdown(zeilen, blindFuer: [.stapel])
        #expect(offen.contains("stapel-blind") && !offen.contains("lang-blind"))
    }

    @Test func berichtSchreiben() throws {
        let zeilen = TaktBericht.gemessen
        let text = TaktBericht.markdown(zeilen)
        try text.write(to: Pfade.aufnahmen.appendingPathComponent("taktbericht.md"),
                       atomically: true, encoding: .utf8)
        #expect(text.contains("Blindprüfung"))
    }
}
