import Foundation

/// aufnahme.json im Format gymodo.sensoraufnahme/1 (Spec 6.3). Der Vertrag
/// zwischen Teilprojekt A (schreibt) und B (liest) -- Aenderungen hier sind
/// Formataenderungen und brauchen eine neue Kennung.
public struct SensorAufnahmeDatei: Codable, Equatable, Sendable {
    public static let formatkennung = "gymodo.sensoraufnahme/1"

    public enum Abschluss: String, Codable, Sendable { case laeuft, gesichert, abgebrochen }

    public struct Sensor: Codable, Equatable, Sendable {
        public var name: String
        public var rateSollHz: Int
        public var akkuProzent: Int?

        public init(name: String, rateSollHz: Int, akkuProzent: Int?) {
            self.name = name; self.rateSollHz = rateSollHz; self.akkuProzent = akkuProzent
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(rateSollHz, forKey: .rateSollHz)
            try c.encode(akkuProzent, forKey: .akkuProzent)
        }
    }

    public struct Geraet: Codable, Equatable, Sendable {
        public var model: String
        public var os: String
        public var appBuild: String

        public init(model: String, os: String, appBuild: String) {
            self.model = model; self.os = os; self.appBuild = appBuild
        }
    }

    public struct Kontext: Codable, Equatable, Sendable {
        /// nil am Geraetetyp ohne Geraet; dann nennt equipmentModelId die Station.
        public var machineId: String?
        public var machineName: String
        public var exerciseId: String
        public var exerciseName: String
        public var sessionId: String?
        public var setId: String?
        public var setIndex: Int?
        /// Fehlt in Aufnahmen von vor den Stationen -- optional, damit sie
        /// weiter dekodieren (synthetisiert: decodeIfPresent).
        public var equipmentModelId: String? = nil

        public init(machineId: String?, machineName: String, exerciseId: String, exerciseName: String,
                    sessionId: String?, setId: String?, setIndex: Int?, equipmentModelId: String? = nil) {
            self.machineId = machineId; self.machineName = machineName
            self.exerciseId = exerciseId; self.exerciseName = exerciseName
            self.sessionId = sessionId; self.setId = setId; self.setIndex = setIndex
            self.equipmentModelId = equipmentModelId
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(machineId, forKey: .machineId)
            try c.encode(equipmentModelId, forKey: .equipmentModelId)
            try c.encode(machineName, forKey: .machineName)
            try c.encode(exerciseId, forKey: .exerciseId)
            try c.encode(exerciseName, forKey: .exerciseName)
            try c.encode(sessionId, forKey: .sessionId)
            try c.encode(setId, forKey: .setId)
            try c.encode(setIndex, forKey: .setIndex)
        }
    }

    public struct Label: Codable, Equatable, Sendable {
        public var weightKg: Double?
        /// Der am Rad bestaetigte Wert -- die Wahrheit, gegen die der
        /// Zaehler in B getestet wird.
        public var reps: Int?
        public var problemFlag: Bool?

        public init(weightKg: Double? = nil, reps: Int? = nil, problemFlag: Bool? = nil) {
            self.weightKg = weightKg; self.reps = reps; self.problemFlag = problemFlag
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(weightKg, forKey: .weightKg)
            try c.encode(reps, forKey: .reps)
            try c.encode(problemFlag, forKey: .problemFlag)
        }
    }

    public var format: String
    public var startedAt: Date
    public var endedAt: Date?
    public var sensor: Sensor
    public var geraet: Geraet
    public var kontext: Kontext
    public var label: Label
    public var befestigung: String?
    public var statistik: SensorStatistik.Ergebnis
    public var abschluss: Abschluss

    public init(format: String, startedAt: Date, endedAt: Date?, sensor: Sensor, geraet: Geraet,
                kontext: Kontext, label: Label, befestigung: String?, statistik: SensorStatistik.Ergebnis,
                abschluss: Abschluss) {
        self.format = format; self.startedAt = startedAt; self.endedAt = endedAt
        self.sensor = sensor; self.geraet = geraet; self.kontext = kontext; self.label = label
        self.befestigung = befestigung; self.statistik = statistik; self.abschluss = abschluss
    }

    public func encode(to encoder: Encoder) throws {
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
public struct SensorRatentestDatei: Codable, Equatable, Sendable {
    public static let formatkennung = "gymodo.sensorratentest/1"

    public var format: String
    public var startedAt: Date
    public var endedAt: Date
    public var sensor: SensorAufnahmeDatei.Sensor
    public var geraet: SensorAufnahmeDatei.Geraet
    public var statistik: SensorStatistik.Ergebnis

    public init(format: String, startedAt: Date, endedAt: Date, sensor: SensorAufnahmeDatei.Sensor,
                geraet: SensorAufnahmeDatei.Geraet, statistik: SensorStatistik.Ergebnis) {
        self.format = format; self.startedAt = startedAt; self.endedAt = endedAt
        self.sensor = sensor; self.geraet = geraet; self.statistik = statistik
    }
}
