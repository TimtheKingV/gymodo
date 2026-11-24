import Foundation

/// Richtung des aktuellen Wegs der `Winkellage`: `hin` = in Richtung der ersten Bewegung aus der Ruhelage
/// (weg von der Ruhe, zum oberen Umkehrpunkt), `rueck` = zurueck zur Ruhelage.
public enum Wegrichtung: Sendable, Equatable { case hin, rueck, unbekannt }

/// Live-Lage aus der `Winkellage`: wo die Last im eigenen Bewegungsumfang steht (Tempo-Spec 6.1, Nachtrag N9).
public struct Lage: Sendable, Equatable {
    /// Sensorzeit des Messwerts, nicht die Zeit seit der Los-Marke (dazu `Winkellage.sekundenSeitLos`).
    public let t: TimeInterval
    /// 0 = Ruhelage der Last (unten), 1 = oberer Umkehrpunkt; Werte leicht ausserhalb sind erlaubt.
    public let lage: Double
    public let richtung: Wegrichtung
    /// Ob die Lage gerade traegt: Hub bekannt (gemerkt oder ab dem ersten unteren Umkehrpunkt) und mindestens 40°,
    /// ĝ nicht nahe der Drehachse, Satz nicht beendet.
    public let sicher: Bool

    public init(t: TimeInterval, lage: Double, richtung: Wegrichtung, sicher: Bool) {
        self.t = t; self.lage = lage; self.richtung = richtung; self.sicher = sicher
    }
}

/// Oberer oder unterer Umkehrpunkt einer Wiederholung; `t` ist die Sensorzeit des Messwerts.
public struct Umkehrpunkt: Sendable, Equatable {
    public let t: TimeInterval
    public let oben: Bool

    public init(t: TimeInterval, oben: Bool) {
        self.t = t; self.oben = oben
    }
}
