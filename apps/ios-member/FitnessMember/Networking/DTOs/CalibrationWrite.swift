import Foundation

/// Anfrage-Rumpf fuer POST /api/v1/me/calibrations.
///
/// Die Form von settingValues haengt vom Geraetemodell ab -- deshalb
/// JSONValue statt eines festen Typs, wie schon beim Lesen in
/// BootstrapResponse.Calibration.
struct CalibrationWrite: Encodable, Equatable {
    var machineId: String
    var exerciseId: String
    var settingValues: [String: JSONValue]
    var schemaVersion: Int
    /// "self" oder "trainer_assisted". Der Schalter "Ein Trainer war dabei"
    /// setzt nur die Quelle -- recorded_by bleibt serverseitig null, weil
    /// die Insert-Policy user_id = auth.uid() erzwingt.
    var source: String
}

struct RecordedCalibration: Decodable, Equatable {
    let id: String
    let machineId: String
    let exerciseId: String
    let settingValues: JSONValue
    let schemaVersion: Int
    let source: String
    let createdAt: String
}
