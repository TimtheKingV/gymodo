import Foundation

/// Zielzeiten je Wiederholung in Sekunden (Tempo-Spec 6.3): Kraftweg (Last hebt sich), Halten oben und Ablassen.
public struct Tempovorgabe: Codable, Sendable, Equatable {
    public let kraftweg: Double
    public let ablassen: Double
    /// Haltezeit oben zwischen Kraftweg und Ablassen; 0 = keine Haltezeit.
    public let halten: Double

    /// Die Standardwerte stehen nur hier: 1,5 s Kraftweg, 2,5 s Ablassen.
    private static let standardKraftweg = 1.5, standardAblassen = 2.5

    public static let standard = Tempovorgabe(kraftweg: standardKraftweg, ablassen: standardAblassen)

    /// Rundet auf 0,5 s und begrenzt Kraftweg und Ablassen auf 1…4 s, das Halten auf 0…3 s.
    /// Nicht endliche Werte fallen je Weg auf den Wert von `standard` zurueck, beim Halten auf 0.
    public init(kraftweg: Double, ablassen: Double, halten: Double = 0) {
        self.kraftweg = Self.geglaettet(kraftweg, standard: Self.standardKraftweg)
        self.ablassen = Self.geglaettet(ablassen, standard: Self.standardAblassen)
        self.halten = Self.gehalten(halten)
    }

    private enum CodingKeys: String, CodingKey { case kraftweg, ablassen, halten }

    /// Gespeicherte Werte laufen durch dieselbe Rundung und Begrenzung wie `init(kraftweg:ablassen:halten:)`.
    /// Fehlt `halten` (altes JSON), gilt 0.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kraftweg: try c.decode(Double.self, forKey: .kraftweg),
                  ablassen: try c.decode(Double.self, forKey: .ablassen),
                  halten: try c.decodeIfPresent(Double.self, forKey: .halten) ?? 0)
    }

    /// `halten` wird nur geschrieben, wenn es nicht 0 ist; so bleibt das JSON ohne Haltezeit wie bisher.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kraftweg, forKey: .kraftweg)
        try c.encode(ablassen, forKey: .ablassen)
        if halten > 0 { try c.encode(halten, forKey: .halten) }
    }

    /// Dauer einer ganzen Wiederholung.
    public var periode: Double { kraftweg + halten + ablassen }

    private static func gehalten(_ sekunden: Double) -> Double {
        guard sekunden.isFinite else { return 0 }
        return min(3, max(0, (sekunden * 2).rounded() / 2))
    }

    private static func geglaettet(_ sekunden: Double, standard: Double) -> Double {
        guard sekunden.isFinite else { return standard }
        return min(4, max(1, (sekunden * 2).rounded() / 2))
    }
}
