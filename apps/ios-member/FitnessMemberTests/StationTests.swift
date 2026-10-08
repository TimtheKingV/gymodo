import Foundation
import Testing
@testable import FitnessMember

struct StationTests {
    private let typJson = """
    {"id":"em1","name":"Beinpresse","manufacturer":"Technogym","photoPath":null,
     "category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
     "settingDefinitions":[],
     "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
    """
    private let typJson2 = """
    {"id":"em2","name":"Kabelzug","manufacturer":null,"photoPath":null,
     "category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":2.5,"loadMax":100.0,
     "settingDefinitions":[],"exercises":[]}
    """

    private var typ: BootstrapResponse.Catalog.EquipmentType { GeraetTestdaten.dekodiere(typJson) }

    private func bootstrap(status: String = "active") -> BootstrapResponse {
        let m = GeraetTestdaten.maschine
        let maschine: BootstrapResponse.Machine = GeraetTestdaten.dekodiere("""
        {"id":"\(m.id)","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"\(status)","tokenHashes":["h1"],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
        let katalog: BootstrapResponse.Catalog = GeraetTestdaten.dekodiere("""
        {"studioId":"s1","equipmentTypes":[\(typJson),\(typJson2)]}
        """)
        return BootstrapResponse(
            member: .init(displayName: nil), studios: [], machines: [maschine],
            calibrations: [], lastSets: [], catalog: katalog)
    }

    @Test func schluesselWieAufDemServer() {
        #expect(Station.schluessel(machineId: "m1", equipmentModelId: "em1") == "geraet:m1")
        #expect(Station.schluessel(machineId: nil, equipmentModelId: "em1") == "typ:em1")
        #expect(Station(maschine: GeraetTestdaten.maschine).schluessel == "geraet:m1")
        #expect(Station(maschine: GeraetTestdaten.maschine).id == "geraet:m1")
        #expect(Station(typ: typ, studioId: "s1").schluessel == "typ:em1")
    }

    @Test func geraetGewinntUeberDenTyp() {
        // Dasselbe Modell em1 als Geraet und als Typ: der Schluessel nennt das Geraet.
        let station = Station(maschine: GeraetTestdaten.maschine)
        #expect(station.machineId == "m1")
        #expect(station.equipmentModelId == "em1")
        #expect(station.studioId == "s1")
        #expect(station.label == "Gerät 7")
        #expect(station.gesperrt == false)
        let s = bootstrap().station(schluessel: "geraet:m1", studioId: "andere")
        #expect(s?.machineId == "m1")
        #expect(s?.studioId == "s1")
    }

    @Test func gesperrtesGeraetIstGesperrt() {
        let s = bootstrap(status: "maintenance").station(schluessel: "geraet:m1", studioId: nil)
        #expect(s?.gesperrt == true)
    }

    @Test func typStationHatKeineMachineIdUndKeinenToken() {
        let station = Station(typ: typ, studioId: "s1")
        #expect(station.machineId == nil)
        #expect(station.tokenHashes.isEmpty)
        #expect(station.gesperrt == false)
        #expect(station.label == "Beinpresse")
        #expect(station.studioId == "s1")
        #expect(station.equipmentModelId == "em1")
        #expect(station.equipmentModel.catalogModelId == nil)
        #expect(station.exercises.map(\.id) == ["e1"])
        #expect(Station(typ: typ, studioId: nil).studioId == nil)
    }

    @Test func bootstrapFindetGeraetUndTypUndNilFuerUnbekanntes() {
        let b = bootstrap()
        #expect(b.station(schluessel: "geraet:m1", studioId: nil)?.machineId == "m1")
        let typStation = b.station(schluessel: "typ:em2", studioId: "s1")
        #expect(typStation?.label == "Kabelzug")
        #expect(typStation?.studioId == "s1")
        #expect(b.station(schluessel: "typ:em2", studioId: nil)?.studioId == nil)
        #expect(b.station(schluessel: "geraet:nix", studioId: "s1") == nil)
        #expect(b.station(schluessel: "typ:nix", studioId: "s1") == nil)
        #expect(b.station(schluessel: "quatsch", studioId: "s1") == nil)
    }

    @Test func ohneKatalogGibtEsKeineTypStation() {
        let b = BootstrapResponse(
            member: .init(displayName: nil), studios: [], machines: [],
            calibrations: [], lastSets: [])
        #expect(b.station(schluessel: "typ:em1", studioId: "s1") == nil)
    }
}
