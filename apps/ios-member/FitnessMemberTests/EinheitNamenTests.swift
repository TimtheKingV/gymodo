import Foundation
import Testing
@testable import FitnessMember

/// Die Namen der Planeinheiten: aus den Muskeln, mit Schwerpunkt bei
/// gleichnamigen, mechanisch ohne Katalog.
struct EinheitNamenTests {
    private func muskel(_ key: String, _ rolle: GeraetMuskel.Rolle = .primary) -> GeraetMuskel {
        GeraetMuskel(key: key, name: key, role: rolle)
    }

    private func katalog() -> [String: [GeraetMuskel]] {
        [
            "bankdruecken": [muskel("pectorals"), muskel("triceps", .secondary)],
            "trizepsdruecken": [muskel("triceps")],
            "rudern": [muskel("lats"), muskel("upper_back"), muskel("biceps", .secondary)],
            "beinpresse": [muskel("quads"), muskel("glutes")],
            "kreuzheben": [muskel("glutes"), muskel("hamstrings"), muskel("lower_back")],
        ]
    }

    /// Eine Position: (Baustein, Uebung, Saetze).
    private func einheit(_ key: String, _ positionen: [(String, String, Int)]) -> String {
        let liste = positionen.enumerated().map { i, p in
            """
            {"key":"\(key)\(i)","baustein":"\(p.0)","rolle":"pflicht","exerciseId":"\(p.1)",
             "modelId":"em-m","typ":"mehrgelenk","saetze":\(p.2),"wdhVon":8,"wdhBis":12,
             "reserveVon":1,"reserveBis":3,"pauseSek":90,"aufwaermsatz":false,"dauerMin":null,
             "hauptmuskeln":[]}
            """
        }.joined(separator: ",")
        return #"{"key":"\#(key)","geschaetzteMinuten":45,"positionen":[\#(liste)]}"#
    }

    private func plan(_ einheiten: [String]) -> Trainingsplan {
        let json = """
        {"planId":"p1","studioId":"s1","version":1,"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":[],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":0,"anfaengerUebergang":false,"alternativen":{},
         "einheiten":[\(einheiten.joined(separator: ","))]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    @Test func nameAusMuskeln() {
        let plan = plan([einheit("A", [
            ("druecken", "bankdruecken", 6), ("arme", "trizepsdruecken", 2)])])
        let namen = EinheitNamen(plan: plan, muskeln: katalog())

        #expect(namen.name("A") == "Brust, Trizeps")
    }

    @Test func gleicheNamenBekommenSchwerpunkt() {
        let plan = plan([
            einheit("A", [("beine_knie", "beinpresse", 4), ("ziehen", "rudern", 2), ("druecken", "bankdruecken", 2)]),
            einheit("B", [("beine_huefte", "kreuzheben", 4), ("ziehen", "rudern", 2), ("druecken", "bankdruecken", 2)]),
        ])
        let namen = EinheitNamen(plan: plan, muskeln: katalog())

        #expect(namen.name("A") == "Ganzkörper · Schwerpunkt Beine, Knie")
        #expect(namen.name("B") == "Ganzkörper · Schwerpunkt Beine, Hüfte")
    }

    @Test func gleicherSchwerpunktBehaeltDenBuchstaben() {
        let positionen = [("beine_knie", "beinpresse", 4), ("ziehen", "rudern", 2), ("druecken", "bankdruecken", 2)]
        let namen = EinheitNamen(plan: plan([einheit("A", positionen), einheit("B", positionen)]), muskeln: katalog())

        #expect(namen.name("A") == "Ganzkörper · Schwerpunkt Beine, Knie (A)")
        #expect(namen.name("B") == "Ganzkörper · Schwerpunkt Beine, Knie (B)")
    }

    @Test func ohneKatalogMechanisch() {
        let plan = plan([
            einheit("A", [("druecken", "bankdruecken", 3)]),
            einheit("OK_A", [("druecken", "bankdruecken", 3)]),
            einheit("UK_A", [("beine_knie", "beinpresse", 3)]),
        ])
        let namen = EinheitNamen(plan: plan, muskeln: [:])

        #expect(namen.name("A") == "Einheit A")
        #expect(namen.name("OK_A") == "Oberkörper A")
        #expect(namen.name("UK_A") == "Unterkörper A")
    }

    @Test func unbekannterKey() {
        let plan = plan([einheit("A", [("druecken", "bankdruecken", 3)])])

        #expect(EinheitNamen(plan: plan, muskeln: katalog()).name("Z") == "Einheit Z")
    }

    @Test func strukturTextOhneBuchstaben() {
        for struktur in ["gk_ab", "gk_abc"] {
            let text = PlanStrukturText.text(struktur)
            #expect(!text.contains("A und B"))
            #expect(!text.contains("Nach A"))
        }
        #expect(PlanStrukturText.text("gk_ab")
                == "Ganzkörper, zwei Einheiten im Wechsel. Die nächste folgt der letzten, egal an welchem Tag.")
        #expect(PlanStrukturText.text("gk_abc")
                == "Ganzkörper, drei Einheiten im Wechsel. Die nächste folgt der letzten, egal an welchem Tag.")
    }

    /// Im Fliesstext steht ein Name mit Komma in Anfuehrung, der mechanische nicht.
    @Test func zitiertImFliesstext() {
        let plan = plan([
            einheit("A", [("druecken", "bankdruecken", 6), ("arme", "trizepsdruecken", 2)]),
            einheit("B", [("ziehen", "rudern", 3)]),
        ])
        let namen = EinheitNamen(plan: plan, muskeln: katalog())
        #expect(namen.zitiert("A") == "„Brust, Trizeps“")
        #expect(EinheitNamen(plan: plan, muskeln: [:]).zitiert("A") == "Einheit A")
        #expect(EinheitNamen(bootstrap: nil).zitiert("OK_A") == "Oberkörper A")

        let abschluss = PlanAnzeige.abschluss(
            einheitKey: "B", zustand: AblaufZustand(positionen: [], ungeplanteGesehen: []),
            naechsteEinheitKey: "A", namen: namen)
        #expect(abschluss.naechstes == "Nächstes Mal ist „Brust, Trizeps“ dran.")
    }
}
