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
