#if DEBUG
import Foundation

/// aufnahme.json im Format gymodo.sensoraufnahme/1 (Spec 6.3). Der Vertrag
/// zwischen Teilprojekt A (schreibt) und B (liest) -- Aenderungen hier sind
/// Formataenderungen und brauchen eine neue Kennung.
struct SensorAufnahmeDatei: Codable, Equatable {
    static let formatkennung = "gymodo.sensoraufnahme/1"

    enum Abschluss: String, Codable { case laeuft, gesichert, abgebrochen }

    struct Sensor: Codable, Equatable {
        var name: String
        var rateSollHz: Int
        var akkuProzent: Int?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(rateSollHz, forKey: .rateSollHz)
            try c.encode(akkuProzent, forKey: .akkuProzent)
        }
    }

    struct Geraet: Codable, Equatable {
        var model: String
        var os: String
        var appBuild: String
    }

    struct Kontext: Codable, Equatable {
        var machineId: String
        var machineName: String
        var exerciseId: String
        var exerciseName: String
        var sessionId: String?
        var setId: String?
        var setIndex: Int?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(machineId, forKey: .machineId)
            try c.encode(machineName, forKey: .machineName)
            try c.encode(exerciseId, forKey: .exerciseId)
            try c.encode(exerciseName, forKey: .exerciseName)
            try c.encode(sessionId, forKey: .sessionId)
            try c.encode(setId, forKey: .setId)
            try c.encode(setIndex, forKey: .setIndex)
        }
    }

    struct Label: Codable, Equatable {
        var weightKg: Double?
        /// Der am Rad bestaetigte Wert -- die Wahrheit, gegen die der
        /// Zaehler in B getestet wird.
        var reps: Int?
        var problemFlag: Bool?

        init(weightKg: Double? = nil, reps: Int? = nil, problemFlag: Bool? = nil) {
            self.weightKg = weightKg; self.reps = reps; self.problemFlag = problemFlag
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(weightKg, forKey: .weightKg)
            try c.encode(reps, forKey: .reps)
            try c.encode(problemFlag, forKey: .problemFlag)
        }
    }

    var format: String
    var startedAt: Date
    var endedAt: Date?
    var sensor: Sensor
    var geraet: Geraet
    var kontext: Kontext
    var label: Label
    var befestigung: String?
    var statistik: SensorStatistik.Ergebnis
    var abschluss: Abschluss

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(endedAt, forKey: .endedAt)
        try c.encode(sensor, forKey: .sensor)
        try c.encode(geraet, forKey: .geraet)
        try c.encode(kontext, forKey: .kontext)
        try c.encode(label, forKey: .label)
        try c.encode(befestigung, forKey: .befestigung)
        try c.encode(statistik, forKey: .statistik)
        try c.encode(abschluss, forKey: .abschluss)
    }
}

/// ratentest-<zeit>.json: dieselbe Statistik ohne Messwerte (Spec 7.2).
struct SensorRatentestDatei: Codable, Equatable {
    static let formatkennung = "gymodo.sensorratentest/1"

    var format: String
    var startedAt: Date
    var endedAt: Date
    var sensor: SensorAufnahmeDatei.Sensor
    var geraet: SensorAufnahmeDatei.Geraet
    var statistik: SensorStatistik.Ergebnis
}
#endif
