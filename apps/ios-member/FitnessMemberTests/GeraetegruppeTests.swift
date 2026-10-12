import Foundation
import Testing
@testable import FitnessMember

/// Unter welcher Kachel ein Geraet in "Geraet waehlen" steht (Testnotiz
/// 12.10., #3-#5). Der Server loest die Gruppe auf; die App faellt nur
/// zurueck, wenn er (noch) keine oder eine unbekannte liefert.
struct GeraetegruppeTests {

    private func modell(gruppe: String?, kategorie: String = "kraft", retired: Bool? = nil) -> BootstrapResponse.EquipmentModel {
        let gruppeJSON = gruppe.map { ",\"equipmentGroup\":\"\($0)\"" } ?? ""
        let retiredJSON = retired.map { ",\"retired\":\($0)" } ?? ""
        return GeraetTestdaten.dekodiere("""
        {"id":"em1","name":"Kabelzug","manufacturer":null,"photoPath":null,
         "category":"\(kategorie)","loadUnit":"kg","loadStep":2.5,"loadMin":0,"loadMax":null,
         "settingDefinitions":[]\(gruppeJSON)\(retiredJSON)}
        """)
    }

    @Test func dieKachelnStehenInFesterReihenfolge() {
        #expect(Geraetegruppe.allCases == [
            .geraete, .freihantel, .kabelzug, .cardio, .eigengewicht, .kettlebell, .gummiband,
        ])
        #expect(Geraetegruppe.allCases.map(\.titel) == [
            "Geräte", "Freihantel", "Kabelzug", "Cardio", "Eigengewicht", "Kettlebell", "Gummiband",
        ])
    }

    @Test func dieGruppeKommtVomServer() {
        #expect(Geraetegruppe.fuer(modell(gruppe: "kabelzug")) == .kabelzug)
    }

    /// Ein Server vor Migration 0051 liefert kein Feld -- die Liste soll
    /// dann aussehen wie vorher: Kraft unter Geraete, Cardio unter Cardio.
    @Test func ohneGruppeEntscheidetDieKategorie() {
        #expect(Geraetegruppe.fuer(modell(gruppe: nil)) == .geraete)
        #expect(Geraetegruppe.fuer(modell(gruppe: nil, kategorie: "cardio")) == .cardio)
    }

    /// Eine Gruppe, die erst ein spaeterer Server kennt, darf den ganzen
    /// Bootstrap nicht unlesbar machen -- deshalb liest das DTO Text.
    @Test func eineUnbekannteGruppeFaelltAufDieKategorieZurueck() {
        #expect(Geraetegruppe.fuer(modell(gruppe: "yoga")) == .geraete)
    }

    @Test func abgeloestNurWennDerServerEsSagt() {
        #expect(modell(gruppe: nil).abgeloest == false)
        #expect(modell(gruppe: nil, retired: false).abgeloest == false)
        #expect(modell(gruppe: nil, retired: true).abgeloest == true)
    }
}
