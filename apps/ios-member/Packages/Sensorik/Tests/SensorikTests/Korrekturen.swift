import Foundation
@testable import Sensorik

/// data/sensoraufnahmen/korrekturen.json (gymodo.sensorkorrektur/1). Liegt im
/// Testziel, weil nur die Offline-Pruefung die Wahrheit braucht -- die App
/// kennt keine Korrekturen.
struct Korrekturen: Decodable {
    struct Eintrag: Decodable {
        let was: String
        let befestigung: String?
        let befestigungsart: Befestigungsart?
        let repsWahr: Int?
        let fuerZaehler: Bool
        let grund: String?
    }

    let format: String
    let aufnahmen: [String: Eintrag]

    static func laden() throws -> Korrekturen {
        let daten = try Data(contentsOf: Pfade.aufnahmen.appendingPathComponent("korrekturen.json"))
        let k = try JSONDecoder().decode(Korrekturen.self, from: daten)
        guard k.format == "gymodo.sensorkorrektur/1" else {
            throw SensorAufnahmeLeser.Fehler.unbekanntesFormat(k.format)
        }
        return k
    }
}
