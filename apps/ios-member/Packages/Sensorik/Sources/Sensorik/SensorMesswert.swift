import Foundation

public struct Vektor3: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x; self.y = y; self.z = z
    }
}

/// Ein Messwert samt Empfangszeitpunkt. Der Sensor schickt keinen
/// Zeitstempel mit (Spec 3) -- `t` ist die Uptime des iPhones in dem
/// Moment, in dem Core Bluetooth das Paket abgeliefert hat.
public struct SensorMesswert: Sendable, Equatable {
    public let t: TimeInterval
    /// in g
    public let beschleunigung: Vektor3
    /// in Grad pro Sekunde
    public let drehrate: Vektor3
    /// in Grad. Yaw (z) ist am Stahl nicht belastbar (Spec 2).
    public let winkel: Vektor3

    public init(t: TimeInterval, beschleunigung: Vektor3, drehrate: Vektor3, winkel: Vektor3) {
        self.t = t; self.beschleunigung = beschleunigung; self.drehrate = drehrate; self.winkel = winkel
    }
}
