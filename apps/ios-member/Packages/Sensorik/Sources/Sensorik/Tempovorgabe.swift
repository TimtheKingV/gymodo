import Foundation

/// Zielzeiten je Wiederholung in Sekunden (Tempo-Spec 6.3): Kraftweg (Last hebt sich) und Ablassen.
public struct Tempovorgabe: Codable, Sendable, Equatable {
    public let kraftweg: Double
    public let ablassen: Double

    /// Die Standardwerte stehen nur hier: 1,5 s Kraftweg, 2,5 s Ablassen.
    private static let standardKraftweg = 1.5, standardAblassen = 2.5

    public static let standard = Tempovorgabe(kraftweg: standardKraftweg, ablassen: standardAblassen)

    /// Rundet auf 0,5 s und begrenzt auf 1…4 s.
    /// Nicht endliche Werte fallen je Weg auf den Wert von `standard` zurueck.
    public init(kraftweg: Double, ablassen: Double) {
        self.kraftweg = Self.geglaettet(kraftweg, standard: Self.standardKraftweg)
        self.ablassen = Self.geglaettet(ablassen, standard: Self.standardAblassen)
    }

    private enum CodingKeys: String, CodingKey { case kraftweg, ablassen }

    /// Gespeicherte Werte laufen durch dieselbe Rundung und Begrenzung wie `init(kraftweg:ablassen:)`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kraftweg: try c.decode(Double.self, forKey: .kraftweg),
                  ablassen: try c.decode(Double.self, forKey: .ablassen))
    }

    /// Dauer einer ganzen Wiederholung.
    public var periode: Double { kraftweg + ablassen }

    private static func geglaettet(_ sekunden: Double, standard: Double) -> Double {
        guard sekunden.isFinite else { return standard }
        return min(4, max(1, (sekunden * 2).rounded() / 2))
    }
}
