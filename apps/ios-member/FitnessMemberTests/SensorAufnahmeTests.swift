#if DEBUG
import Foundation
import Sensorik

/// Testdaten fuer die App-Tests rund um Sensor-Aufnahmen. Die Tests der
/// Aufnahme selbst wohnen im Package Sensorik; die Koordinator- und
/// Protokoll-Tests brauchen weiter dieselben Beispielwerte, und ein
/// Testtarget kann das andere nicht importieren.
struct SensorAufnahmeTests {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!
    /// 2026-09-19 14:12:03 +02:00
    static let start = Date(timeIntervalSince1970: 1_789_819_923)

    static let sensor = SensorAufnahmeDatei.Sensor(name: "WT901BLE67", rateSollHz: 50, akkuProzent: 82)
    static let geraet = SensorAufnahmeDatei.Geraet(model: "iPhone17,1", os: "iOS 26.0", appBuild: "1")
    static let kontext = SensorAufnahmeDatei.Kontext(
        machineId: "m1", machineName: "Beinpresse", exerciseId: "e1", exerciseName: "Beidbeinig",
        sessionId: nil, setId: nil, setIndex: nil)

    static func messwert(t: TimeInterval) -> SensorMesswert {
        SensorMesswert(t: t,
                       beschleunigung: Vektor3(x: 0.0125, y: -0.9981, z: 0.0312),
                       drehrate: Vektor3(x: 1.25, y: -0.5, z: 0),
                       winkel: Vektor3(x: -88.5, y: 1.25, z: 0))
    }
}
#endif
