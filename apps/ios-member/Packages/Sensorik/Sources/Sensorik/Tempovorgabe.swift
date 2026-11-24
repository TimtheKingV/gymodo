import Foundation

/// Zielzeiten je Wiederholung in Sekunden (Tempo-Spec 6.3): Kraftweg (Last hebt sich) und Ablassen.
public struct Tempovorgabe: Codable, Sendable, Equatable {
    public let kraftweg: Double
    public let ablassen: Double

    public static let standard = Tempovorgabe(kraftweg: 1.5, ablassen: 2.5)

    /// Rundet auf 0,5 s und begrenzt auf 1…4 s.
    public init(kraftweg: Double, ablassen: Double) {
        self.kraftweg = Self.geglaettet(kraftweg)
        self.ablassen = Self.geglaettet(ablassen)
    }

    /// Dauer einer ganzen Wiederholung.
    public var periode: Double { kraftweg + ablassen }

    private static func geglaettet(_ sekunden: Double) -> Double {
        min(4, max(1, (sekunden * 2).rounded() / 2))
    }
}
