import Foundation

/// Spiegel von packages/domain/src/station.ts: ein QR-Geraet (bootstrap.machines)
/// oder ein Gymtavo-Geraetetyp (bootstrap.catalog), jeweils mit Ort. Ein
/// Modell fuer beide Arten, damit Liste, Geraetescreen und lokale Bloecke
/// nicht zwischen zwei Formen unterscheiden muessen.
struct Station: Hashable, Sendable, Identifiable {
    enum Art: Hashable, Sendable {
        case geraet(machineId: String)
        case typ(equipmentModelId: String)
    }

    let art: Art
    /// nil = Freies Training (kein Studio).
    let studioId: String?
    /// Geraetelabel bzw. Typname.
    let label: String
    let equipmentModel: BootstrapResponse.EquipmentModel
    let exercises: [BootstrapResponse.Exercise]
    /// Leer am Typ: ohne Geraet gibt es keinen QR-Token.
    let tokenHashes: [String]
    /// status != "active"; am Typ immer false.
    let gesperrt: Bool

    var id: String { schluessel }

    var schluessel: String {
        Station.schluessel(machineId: machineId, equipmentModelId: equipmentModelId)
    }

    var machineId: String? {
        if case .geraet(let machineId) = art { return machineId }
        return nil
    }

    var equipmentModelId: String { equipmentModel.id }
}

extension Station {
    init(maschine: BootstrapResponse.Machine) {
        art = .geraet(machineId: maschine.id)
        studioId = maschine.studioId
        label = maschine.label
        equipmentModel = maschine.equipmentModel
        exercises = maschine.exercises
        tokenHashes = maschine.tokenHashes
        gesperrt = maschine.status != "active"
    }

    /// Der Typ wird zum EquipmentModel umgebaut (ohne catalogModelId: der Typ
    /// ist selbst der Katalogeintrag), damit beide Arten dieselbe Form haben.
    init(typ: BootstrapResponse.Catalog.EquipmentType, studioId: String?) {
        art = .typ(equipmentModelId: typ.id)
        self.studioId = studioId
        label = typ.name
        equipmentModel = BootstrapResponse.EquipmentModel(
            id: typ.id, name: typ.name, manufacturer: typ.manufacturer,
            photoPath: typ.photoPath, category: typ.category, loadUnit: typ.loadUnit,
            loadStep: typ.loadStep, loadMin: typ.loadMin, loadMax: typ.loadMax,
            secondaryUnit: typ.secondaryUnit, secondaryStep: typ.secondaryStep,
            secondaryMin: typ.secondaryMin, secondaryMax: typ.secondaryMax,
            settingDefinitions: typ.settingDefinitions, catalogModelId: nil)
        exercises = typ.exercises
        tokenHashes = []
        gesperrt = false
    }

    /// Ein Geraet gewinnt immer ueber seinen Typ -- wie in station.ts.
    static func schluessel(machineId: String?, equipmentModelId: String) -> String {
        if let machineId { return "geraet:\(machineId)" }
        return "typ:\(equipmentModelId)"
    }
}

extension BootstrapResponse {
    /// Das Geraet bringt seinen eigenen Ort mit; `studioId` gilt nur fuer
    /// "typ:"-Schluessel, weil ein Typ keinen eigenen Ort hat.
    func station(schluessel: String, studioId: String?) -> Station? {
        if let id = schluessel.dropPrefix("geraet:") {
            return machines.first { $0.id == id }.map(Station.init(maschine:))
        }
        if let id = schluessel.dropPrefix("typ:") {
            return catalog?.equipmentTypes.first { $0.id == id }
                .map { Station(typ: $0, studioId: studioId) }
        }
        return nil
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
