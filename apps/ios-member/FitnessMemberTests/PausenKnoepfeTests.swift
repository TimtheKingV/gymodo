import Testing
@testable import FitnessMember

/// Welche Knoepfe der eine Pausen-Screen in welchem Modus zeigt (UX-Paket 2,
/// Abschnitt 2.1).
struct PausenKnoepfeTests {

    @Test func frei() {
        let knoepfe = PausenKnoepfe.fuer(.frei(naechsterSatz: 3, kannZirkel: true))
        #expect(knoepfe.haupt == "Satz 3 starten")
        #expect(knoepfe.abschliessen == "Übung abschließen")
        #expect(knoepfe.zirkelBeginnen)
        #expect(!knoepfe.ueberspringen)
        #expect(!knoepfe.erweitern)
        #expect(!knoepfe.zirkelBeenden)
    }

    @Test func freiOhneZirkel() {
        let knoepfe = PausenKnoepfe.fuer(.frei(naechsterSatz: 2, kannZirkel: false))
        #expect(!knoepfe.zirkelBeginnen)
    }

    @Test func plan() {
        let knoepfe = PausenKnoepfe.fuer(.plan(naechsterSatz: 2))
        #expect(knoepfe.haupt == "Satz 2 starten")
        #expect(knoepfe.abschliessen == "Nächste Übung")
        #expect(!knoepfe.zirkelBeginnen)
        #expect(!knoepfe.ueberspringen)
        #expect(!knoepfe.erweitern)
        #expect(!knoepfe.zirkelBeenden)
    }

    @Test func zirkel() {
        let knoepfe = PausenKnoepfe.fuer(.zirkel(naechsteUebung: "Beinpresse", kannErweitern: true))
        #expect(knoepfe.haupt == "Beinpresse starten")
        #expect(knoepfe.abschliessen == nil)
        #expect(knoepfe.ueberspringen)
        #expect(knoepfe.erweitern)
        #expect(knoepfe.zirkelBeenden)
        #expect(!knoepfe.zirkelBeginnen)
    }

    @Test func zirkelOhneErweitern() {
        let knoepfe = PausenKnoepfe.fuer(.zirkel(naechsteUebung: "Beinpresse", kannErweitern: false))
        #expect(!knoepfe.erweitern)
    }

    /// "± kg" statt "Gewicht" -- die Einheit kommt vom Geraet.
    @Test func gewichtTitel() {
        #expect(PausenKnoepfe.gewichtTitel(.kg) == "± kg")
        #expect(PausenKnoepfe.gewichtTitel(.kmh) == "± km/h")
    }
}
