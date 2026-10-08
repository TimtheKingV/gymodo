import Foundation
import Testing
@testable import FitnessMember

struct StudiosListeTests {
    private func studio(_ id: String, _ name: String) -> BootstrapResponse.Studio {
        BootstrapResponse.Studio(id: id, name: name, timezone: "Europe/Berlin")
    }

    @Test func ersteZeileIstImmerFreiesTraining() {
        let zeilen = StudiosListe.zeilen(studios: [studio("a", "Alpha")], ort: .studio("a"))
        #expect(zeilen.first?.ort == .freiesTraining)
        #expect(zeilen.first?.name == "Freies Training")
        #expect(StudiosListe.zeilen(studios: [], ort: .freiesTraining).count == 1)
    }

    @Test func studiosFolgenAlphabetisch() {
        let zeilen = StudiosListe.zeilen(
            studios: [studio("c", "Zeta"), studio("a", "alpha"), studio("b", "Beta")],
            ort: .freiesTraining)
        #expect(zeilen.map(\.name) == ["Freies Training", "alpha", "Beta", "Zeta"])
    }

    @Test func haekchenFolgtDemOrt() {
        let studios = [studio("a", "Alpha"), studio("b", "Beta")]
        #expect(StudiosListe.zeilen(studios: studios, ort: .studio("b")).map(\.istAktiv)
                == [false, false, true])
        #expect(StudiosListe.zeilen(studios: studios, ort: .freiesTraining).map(\.istAktiv)
                == [true, false, false])
    }

    @Test func verlassenNurBeiStudios() {
        let zeilen = StudiosListe.zeilen(studios: [studio("a", "Alpha")], ort: .freiesTraining)
        #expect(zeilen.map(\.darfVerlassen) == [false, true])
    }

    @Test func fusstext() {
        #expect(StudiosListe.fusstext
                == "Tippen wechselt. Ein Gerätecode aus einem anderen Studio macht dich dort zum Mitglied.")
    }

    @Test func ortsnameFuerDialog() {
        let studios = [studio("a", "Alpha")]
        #expect(StudiosListe.name(fuer: .studio("a"), studios: studios) == "Alpha")
        #expect(StudiosListe.name(fuer: .freiesTraining, studios: studios) == "Freies Training")
        #expect(StudiosListe.name(fuer: .studio("x"), studios: studios) == "Studio")
    }
}
