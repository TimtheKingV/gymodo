import Foundation

/// Woher der `Lageschaetzer` die Schwerkraftrichtung je Messwert nimmt
/// (Winkel-Versuch, Task 5b; weicht bewusst von Tempo-Spec 6.1 ab).
public enum Schwerkraftquelle: Sendable, Equatable, CaseIterable {
    /// Richtung aus der Beschleunigung in Ruhe, in Bewegung fest (bisheriges Verhalten).
    case ruhe
    /// Richtung je Messwert aus Roll und Pitch des Sensors.
    case winkel
    /// Richtung aus der Ruhe, in Bewegung mit der Drehrate fortgeschrieben.
    case drehrate

    /// Richtung der gemessenen Beschleunigung in Ruhe (nach oben, Einheitsvektor im
    /// Sensorrahmen) aus Roll (`winkel.x`) und Pitch (`winkel.y`); Yaw wird nicht gebraucht.
    /// Konvention gemessen, nicht angenommen: in den Ruhephasen der Aufnahmen trifft
    /// sie die Beschleunigung im Median auf 1,4–1,7° (alle Arten); die anderen
    /// Vorzeichen- und Reihenfolge-Varianten liegen bei 3–175°.
    public static func richtung(winkel: Vektor3) -> Vektor3 {
        let roll = winkel.x * .pi / 180, pitch = winkel.y * .pi / 180
        return Vektor3(x: -sin(pitch), y: sin(roll) * cos(pitch), z: cos(roll) * cos(pitch))
    }

    /// Ein ortsfester Vektor `v` im Sensorrahmen nach einem Schritt `dt` mit der
    /// Drehrate (°/s): dv/dt = −ω × v, als Drehung um −|ω|·dt (Rodrigues). Das
    /// Vorzeichen ist an den Aufnahmen gegen die Winkel geprueft.
    public static func drehen(_ v: Vektor3, drehrate: Vektor3, dt: Double) -> Vektor3 {
        let w = Vektor3(x: drehrate.x * .pi / 180, y: drehrate.y * .pi / 180, z: drehrate.z * .pi / 180)
        let betrag = (w.x * w.x + w.y * w.y + w.z * w.z).squareRoot()
        let winkel = -betrag * dt
        guard betrag > 0 else { return v }
        let k = Vektor3(x: w.x / betrag, y: w.y / betrag, z: w.z / betrag)
        let c = cos(winkel), s = sin(winkel)
        let kxv = Vektor3(x: k.y * v.z - k.z * v.y, y: k.z * v.x - k.x * v.z, z: k.x * v.y - k.y * v.x)
        let kv = k.x * v.x + k.y * v.y + k.z * v.z
        return Vektor3(x: v.x * c + kxv.x * s + k.x * kv * (1 - c),
                       y: v.y * c + kxv.y * s + k.y * kv * (1 - c),
                       z: v.z * c + kxv.z * s + k.z * kv * (1 - c))
    }
}
