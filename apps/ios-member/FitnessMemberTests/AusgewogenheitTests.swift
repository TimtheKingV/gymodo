import Testing
@testable import FitnessMember

struct AusgewogenheitTests {
    private func haeufigkeit(
        gruppen: [Int], einheiten: Int = 10, muskeln: [String: Int] = [:]
    ) -> Haeufigkeit {
        var jeGruppe: [MuskelHauptgruppe: Int] = [:]
        for (gruppe, zahl) in zip(MuskelHauptgruppe.angezeigt, gruppen) { jeGruppe[gruppe] = zahl }
        return Haeufigkeit(einheiten: einheiten, jeMuskel: muskeln, jeGruppe: jeGruppe)
    }

    @Test func prozentBeiGleichmaessigerVerteilung() {
        #expect(Ausgewogenheit.prozent(haeufigkeit(gruppen: [6, 6, 6, 6, 6, 6])) == 100)
    }

    @Test func prozentBeiZweiVergessenenGruppen() {
        #expect(Ausgewogenheit.prozent(haeufigkeit(gruppen: [6, 6, 6, 6, 0, 0])) == 33)
    }

    @Test func prozentBeiLeichterAbweichung() {
        #expect(Ausgewogenheit.prozent(haeufigkeit(gruppen: [8, 6, 6, 4, 6, 6])) == 89)
    }

    @Test func prozentNilOhneDatenreife() {
        #expect(Ausgewogenheit.prozent(haeufigkeit(gruppen: [6, 6, 6, 6, 6, 6], einheiten: 2)) == nil)
        #expect(Ausgewogenheit.prozent(haeufigkeit(gruppen: [0, 0, 0, 0, 0, 0])) == nil)
    }

    @Test func statusGruppe() {
        // Mittel 6: Brust ist die Pruefgruppe, der Rest gleicht aus.
        func status(_ wert: Int) -> MuskelStatus {
            let rest = (36 - wert) / 5
            let h = haeufigkeit(gruppen: [wert, rest, rest, rest, rest, rest])
            return Ausgewogenheit.status(gruppe: .brust, in: h)
        }
        #expect(status(0) == .nachholbedarf)
        #expect(status(1) == .nachholbedarf)
        #expect(status(6) == .ok)
        let viel = haeufigkeit(gruppen: [10, 5, 5, 5, 5, 6]) // Mittel 6
        #expect(Ausgewogenheit.status(gruppe: .brust, in: viel) == .viel)
        let duenn = haeufigkeit(gruppen: [6, 6, 6, 6, 6, 6], einheiten: 2)
        #expect(Ausgewogenheit.status(gruppe: .brust, in: duenn) == .keineAuswertung)
    }

    @Test func statusGruppeMitZweiEinheiten() {
        let h = haeufigkeit(gruppen: [2, 8, 8, 6, 6, 6]) // Mittel 6
        #expect(Ausgewogenheit.status(gruppe: .brust, in: h) == .nachholbedarf)
    }

    @Test func statusMuskelVergleichtMitDerEigenenGruppe() {
        // Nicht selten im Ruecken: lats, upper_back -> Mittel 5, Schwellen 2,5 / 7,5.
        let h = haeufigkeit(gruppen: [6, 6, 6, 6, 6, 6], muskeln: ["lats": 8, "upper_back": 2])
        #expect(Ausgewogenheit.status(muskel: "upper_back", gruppe: .ruecken, in: h) == .nachholbedarf)
        #expect(Ausgewogenheit.status(muskel: "lats", gruppe: .ruecken, in: h) == .viel)
    }

    @Test func statusMuskelInGruppeMitDreiMuskeln() {
        // Schultern ohne rotator_cuff: 4, 4, 1 -> Mittel 3, Schwellen 1,5 / 4,5.
        let h = haeufigkeit(
            gruppen: [6, 6, 6, 6, 6, 6],
            muskeln: ["deltoid_anterior": 4, "deltoid_lateral": 4, "deltoid_posterior": 1]
        )
        #expect(Ausgewogenheit.status(muskel: "deltoid_posterior", gruppe: .schultern, in: h) == .nachholbedarf)
        #expect(Ausgewogenheit.status(muskel: "deltoid_anterior", gruppe: .schultern, in: h) == .ok)
        #expect(Ausgewogenheit.status(muskel: "deltoid_lateral", gruppe: .schultern, in: h) == .ok)
    }

    @Test func seltenerMuskelIstKaumUebungen() {
        let h = haeufigkeit(gruppen: [6, 6, 6, 6, 6, 6], muskeln: ["lats": 6, "upper_back": 6])
        #expect(Ausgewogenheit.status(muskel: "erectors", gruppe: .ruecken, in: h) == .kaumUebungen)
    }

    @Test func muskelnOhneHauptuebungSindSelten() {
        let h = haeufigkeit(gruppen: [6, 6, 6, 6, 6, 6], muskeln: ["pectorals": 6, "quads": 6])
        #expect(Ausgewogenheit.status(muskel: "tibialis", gruppe: .beine, in: h) == .kaumUebungen)
        #expect(Ausgewogenheit.status(muskel: "fibularis", gruppe: .beine, in: h) == .kaumUebungen)
        #expect(Ausgewogenheit.status(muskel: "serratus_anterior", gruppe: .brust, in: h) == .kaumUebungen)
    }
}
