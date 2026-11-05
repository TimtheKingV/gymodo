import Testing
@testable import FitnessMember

struct MuskelHinweiseTests {
    private func haeufigkeit(
        _ gruppen: [MuskelHauptgruppe: Int], einheiten: Int = 10, muskeln: [String: Int] = [:]
    ) -> Haeufigkeit {
        Haeufigkeit(einheiten: einheiten, jeMuskel: muskeln, jeGruppe: gruppen)
    }

    /// Alle sechs Gruppen auf 6, einzelne ueberschrieben (Mittel bleibt nah an 6).
    private func mit(_ ueberschrieben: [MuskelHauptgruppe: Int]) -> Haeufigkeit {
        var gruppen = Dictionary(uniqueKeysWithValues: MuskelHauptgruppe.angezeigt.map { ($0, 6) })
        for (k, v) in ueberschrieben { gruppen[k] = v }
        return haeufigkeit(gruppen)
    }

    @Test func startsatzOhneNachholbedarf() {
        #expect(MuskelHinweise.startsatz(mit([:])) == "Du trainierst alle Gruppen ähnlich oft.")
    }

    @Test func startsatzMitEinerGruppe() {
        #expect(MuskelHinweise.startsatz(mit([.rumpf: 0])) == "Rumpf kommt zu kurz.")
    }

    @Test func startsatzMitZweiGruppen() {
        #expect(MuskelHinweise.startsatz(mit([.rumpf: 0, .beine: 1])) == "Rumpf und Beine kommen zu kurz.")
        #expect(MuskelHinweise.startsatz(mit([.rumpf: 0, .beine: 0])) == "Beine und Rumpf kommen zu kurz.")
    }

    @Test func startsatzMitDreiGruppenNenntNurDieZweiSchwaechsten() {
        let h = mit([.rumpf: 0, .beine: 0, .brust: 1])
        #expect(MuskelHinweise.startsatz(h) == "Beine und Rumpf kommen zu kurz.")
    }

    @Test func startsatzNichtAuswertbar() {
        let h = haeufigkeit([:], einheiten: 2)
        #expect(MuskelHinweise.startsatz(h) == "Für die Analyse braucht es noch ein paar Trainings.")
    }

    @Test func gruppenhinweisNenntSchwaechstenAuswertbarenMuskel() {
        let namen = ["upper_back": "Oberer Rücken"]
        let zwei = mit([.ruecken: 3]).mitMuskeln(["lats": 8, "upper_back": 2, "erectors": 6])
        #expect(MuskelHinweise.gruppenhinweis(gruppe: .ruecken, in: zwei, namen: namen)
            == "Oberer Rücken kam in 28 Tagen 2× dran. Eine Übung dafür würde dein Training abrunden.")
        let null = mit([.ruecken: 3]).mitMuskeln(["lats": 6, "erectors": 6])
        #expect(MuskelHinweise.gruppenhinweis(gruppe: .ruecken, in: null, namen: namen)
            == "Oberer Rücken kam in 28 Tagen nicht dran. Eine Übung dafür würde dein Training abrunden.")
        #expect(MuskelHinweise.gruppenhinweis(gruppe: .ruecken, in: null, namen: [:])
            == "upper_back kam in 28 Tagen nicht dran. Eine Übung dafür würde dein Training abrunden.")
    }

    @Test func gruppenhinweisNenntAuchRueckenstreckerMitNurEinerKataloguebung() {
        let h = mit([:]).mitMuskeln(["lats": 6, "upper_back": 6, "erectors": 0])
        #expect(MuskelHinweise.gruppenhinweis(gruppe: .ruecken, in: h, namen: ["erectors": "Rückenstrecker"])
            == "Rückenstrecker kam in 28 Tagen nicht dran. Eine Übung dafür würde dein Training abrunden.")
    }

    @Test func gruppenhinweisNilWennNurTibialisUndFibularisFehlen() {
        let h = mit([:]).mitMuskeln([
            "quads": 6, "hamstrings": 6, "glutes": 6, "calves": 6,
            "adductors": 6, "abductors": 6, "tibialis": 0, "fibularis": 0
        ])
        #expect(MuskelHinweise.gruppenhinweis(gruppe: .beine, in: h, namen: [:]) == nil)
    }

    @Test func brauchtTrainingsNurBeiAuswertbarerHaeufigkeitOhneFortschritt() {
        #expect(FortschrittsText.brauchtTrainings(.keinWert, auswertbar: true) == true)
        #expect(FortschrittsText.brauchtTrainings(.keinWert, auswertbar: false) == false)
        #expect(FortschrittsText.brauchtTrainings(.keinWert, auswertbar: true, ohneKraftuebung: true) == false)
        #expect(FortschrittsText.brauchtTrainings(.stabil, auswertbar: true) == false)
        #expect(FortschrittsText.brauchtTrainings(.wert(5), auswertbar: true) == false)
        #expect(FortschrittsText.brauchtTrainingsText == "braucht noch Trainings")
    }
}

private extension Haeufigkeit {
    func mitMuskeln(_ muskeln: [String: Int]) -> Haeufigkeit {
        Haeufigkeit(einheiten: einheiten, jeMuskel: muskeln, jeGruppe: jeGruppe)
    }
}
