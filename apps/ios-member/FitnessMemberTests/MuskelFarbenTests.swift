import SwiftUI
import Testing
@testable import FitnessMember

struct MuskelFarbenTests {
    private let h = Haeufigkeit(
        einheiten: 10,
        jeMuskel: ["lats": 8, "upper_back": 8, "pectorals": 0],
        jeGruppe: [.brust: 1, .ruecken: 8, .schultern: 4, .arme: 4, .beine: 4, .rumpf: 4])

    @Test func farbeJeStatus() {
        #expect(MuskelFarben.farbe(.nachholbedarf) == DesignSystem.Color.warn)
        #expect(MuskelFarben.farbe(.ok) == DesignSystem.Color.accentPressed)
        #expect(MuskelFarben.farbe(.viel) == DesignSystem.Color.accent)
        #expect(MuskelFarben.farbe(.kaumUebungen) == DesignSystem.Color.muskelInaktiv)
        #expect(MuskelFarben.farbe(.keineAuswertung) == DesignSystem.Color.muskelInaktiv)
    }

    @Test func detailZeigtNurDieGruppeHervorgehoben() {
        let farben = MuskelFarben.farben(gruppe: .ruecken, h: h, nurGruppe: true)
        #expect(farben["pectorals"] == DesignSystem.Color.line)
        let lats = Ausgewogenheit.status(muskel: "lats", gruppe: .ruecken, in: h)
        #expect(farben["lats"] == MuskelFarben.farbe(lats))
    }

    @Test func startansichtFaerbtJedenMuskelNachSeinerGruppe() {
        let farben = MuskelFarben.farbenAlle(h)
        let brust = Ausgewogenheit.status(muskel: "pectorals", gruppe: .brust, in: h)
        #expect(farben["pectorals"] == MuskelFarben.farbe(brust))
        #expect(farben["lats"] != nil)
    }

    @Test func detailAnsichten() {
        #expect(MuskelHauptgruppe.ruecken.detailAnsichten == [.hinten])
        #expect(MuskelHauptgruppe.brust.detailAnsichten == [.vorne])
        #expect(MuskelHauptgruppe.rumpf.detailAnsichten == [.vorne])
        for g in [MuskelHauptgruppe.schultern, .arme, .beine, .weitere, .mehrere] {
            #expect(g.detailAnsichten == [.vorne, .hinten])
        }
    }
}
