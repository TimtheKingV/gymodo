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
        // Gemeinsamer Massstab (Testnotiz 18.10., #2): Mittel der Gruppen 25/6 ~ 4,2,
        // lats und upper_back mit 8 liegen darueber -> viel, wie die Gruppe Ruecken.
        // erectors ist selten.
        #expect(farben["lats"] == DesignSystem.Color.accent)
        #expect(farben["upper_back"] == DesignSystem.Color.accent)
        #expect(farben["erectors"] == DesignSystem.Color.muskelInaktiv)
    }

    @Test func trainingskarteFaerbtStarkSchwachUndLaesstDenRestWeg() {
        let farben = MuskelFarben.farben(
            profil: TrainingsProfil(
                titel: "Brust", stufen: ["pectorals": .stark, "triceps": .schwach]))

        #expect(farben["pectorals"] == DesignSystem.Color.accent)
        #expect(farben["triceps"] == DesignSystem.Color.accentPressed)
        // Fehlt: MuskelFigur malt den Muskel dann in muskelInaktiv.
        #expect(farben["quads"] == nil)
    }

    @Test func startansichtFaerbtJedenMuskelNachDemStatusSeinerGruppe() {
        // Mittel 25/6 ~ 4,2: Brust 1 = Nachholbedarf, Ruecken 8 = viel, Rest ok.
        // Innerhalb des Rumpfs liegt abs weit vor obliques -- auf der Startansicht egal.
        let h = Haeufigkeit(
            einheiten: 10,
            jeMuskel: ["lats": 8, "upper_back": 1, "pectorals": 1, "abs": 4, "obliques": 0],
            jeGruppe: [.brust: 1, .ruecken: 8, .schultern: 4, .arme: 4, .beine: 4, .rumpf: 4])
        let farben = MuskelFarben.farbenAlle(h)
        #expect(farben["pectorals"] == DesignSystem.Color.warn)
        #expect(farben["lats"] == DesignSystem.Color.accent)
        #expect(farben["upper_back"] == DesignSystem.Color.accent)
        #expect(farben["abs"] == DesignSystem.Color.accentPressed)
        #expect(farben["obliques"] == DesignSystem.Color.accentPressed)
        #expect(farben["erectors"] == DesignSystem.Color.muskelInaktiv)
        #expect(farben["serratus_anterior"] == DesignSystem.Color.muskelInaktiv)
    }

    @Test func startansichtRumpfMitNachholbedarfFaerbtBeideBauchmuskelnOrange() {
        let h = Haeufigkeit(
            einheiten: 10,
            jeMuskel: ["abs": 1, "obliques": 0],
            jeGruppe: [.brust: 6, .ruecken: 6, .schultern: 6, .arme: 6, .beine: 6, .rumpf: 1])
        let farben = MuskelFarben.farbenAlle(h)
        #expect(farben["abs"] == DesignSystem.Color.warn)
        #expect(farben["obliques"] == DesignSystem.Color.warn)
        #expect(farben["pectorals"] == DesignSystem.Color.accentPressed)
    }

    @Test func startansichtOhneAuswertungIstGrau() {
        let h = Haeufigkeit(einheiten: 5, jeMuskel: [:], jeGruppe: [:])
        #expect(MuskelFarben.farbenAlle(h).values.allSatisfy { $0 == DesignSystem.Color.muskelInaktiv })
        #expect(MuskelFarben.farbenAlle(h).count == MuskelHauptgruppe.angezeigt.flatMap(\.muskelSchluessel).count)
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
