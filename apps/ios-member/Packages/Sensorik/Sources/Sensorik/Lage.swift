import Foundation

/// Richtung des aktuellen Wegs. Senkrecht ist `hin` der Kraftweg (die Last hebt sich).
public enum Wegrichtung: Sendable, Equatable { case hin, rueck, unbekannt }

/// Live-Schaetzung, wo die Last im eigenen Bewegungsumfang steht (Tempo-Spec 6.1).
public struct Lage: Sendable, Equatable {
    public let t: TimeInterval
    /// 0 = Ruhelage der Last (unten), 1 = oberer Umkehrpunkt; Werte leicht ausserhalb sind erlaubt.
    public let lage: Double
    public let richtung: Wegrichtung
    /// Ob die Schaetzung gerade traegt.
    public let sicher: Bool

    public init(t: TimeInterval, lage: Double, richtung: Wegrichtung, sicher: Bool) {
        self.t = t; self.lage = lage; self.richtung = richtung; self.sicher = sicher
    }
}

public struct Umkehrpunkt: Sendable, Equatable {
    public let t: TimeInterval
    public let oben: Bool

    public init(t: TimeInterval, oben: Bool) {
        self.t = t; self.oben = oben
    }
}

/// Umfang eines Satzes, den der naechste Satz derselben Uebung als Start nimmt (Tempo-Spec 6.2).
public struct GemerkterUmfang: Codable, Sendable, Equatable {
    /// Interne Einheit des Schaetzers, nur als Verhaeltnis gueltig.
    public var hub: Double
    public var startetOben: Bool
    public var senkrecht: Bool

    public init(hub: Double, startetOben: Bool, senkrecht: Bool) {
        self.hub = hub; self.startetOben = startetOben; self.senkrecht = senkrecht
    }
}
