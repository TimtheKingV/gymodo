import Foundation

/// Erkennt einen Sensor, der nur herumliegt. Das Mitglied vergisst das
/// Ausschalten, und der Akku ist leer, bevor es wieder trainiert.
///
/// Bewegung ist eine Drehrate ueber der Schwelle oder eine Beschleunigung,
/// die von der zuletzt als Ruhe gemerkten abweicht. Reine Logik ohne Uhr:
/// die Zeit kommt aus `SensorMesswert.t`.
public struct Ruhewaechter: Sendable {
    public static let standardFrist: TimeInterval = 20 * 60
    /// Drehrate in Grad pro Sekunde; Rauschen eines ruhenden Sensors liegt darunter.
    static let drehratenSchwelle = 5.0
    /// Aenderung der Beschleunigung in g.
    static let beschleunigungsSchwelle = 0.05

    private let frist: TimeInterval
    private var referenz: Vektor3?
    private var letzteBewegung: TimeInterval?

    public init(frist: TimeInterval = Ruhewaechter.standardFrist) {
        self.frist = frist
    }

    /// `true`, sobald der Sensor die ganze Frist lang ruhig lag.
    public mutating func pruefen(_ messwert: SensorMesswert) -> Bool {
        guard let referenz, let letzteBewegung else {
            self.referenz = messwert.beschleunigung
            self.letzteBewegung = messwert.t
            return false
        }
        if Self.bewegt(messwert, gegen: referenz) {
            self.referenz = messwert.beschleunigung
            self.letzteBewegung = messwert.t
            return false
        }
        return messwert.t - letzteBewegung >= frist
    }

    /// Nach Trennen oder Wiederverbinden von vorn zaehlen.
    public mutating func zuruecksetzen() {
        referenz = nil
        letzteBewegung = nil
    }

    private static func bewegt(_ m: SensorMesswert, gegen referenz: Vektor3) -> Bool {
        let drehung = max(abs(m.drehrate.x), abs(m.drehrate.y), abs(m.drehrate.z))
        let ausschlag = max(abs(m.beschleunigung.x - referenz.x),
                            abs(m.beschleunigung.y - referenz.y),
                            abs(m.beschleunigung.z - referenz.z))
        return drehung > drehratenSchwelle || ausschlag > beschleunigungsSchwelle
    }
}
