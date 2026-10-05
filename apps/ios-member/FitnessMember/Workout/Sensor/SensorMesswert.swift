#if DEBUG
import Foundation

struct Vektor3: Sendable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

/// Ein Messwert samt Empfangszeitpunkt. Der Sensor schickt keinen
/// Zeitstempel mit (Spec 3) -- `t` ist die Uptime des iPhones in dem
/// Moment, in dem Core Bluetooth das Paket abgeliefert hat.
struct SensorMesswert: Sendable, Equatable {
    let t: TimeInterval
    /// in g
    let beschleunigung: Vektor3
    /// in Grad pro Sekunde
    let drehrate: Vektor3
    /// in Grad. Yaw (z) ist am Stahl nicht belastbar (Spec 2).
    let winkel: Vektor3
}
#endif
