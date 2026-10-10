import Foundation

public enum UnsicherGrund: String, Codable, Sendable {
    case luecke, signalSchwach, taktUnregelmaessig
}

/// Eine gezaehlte Wiederholung. Zeiten sind Messwertzeiten (Spec A 5.3) mit
/// rund 30 ms Aufloesung wegen der Buendelung am iPhone (Spec A 4.7).
public struct Wiederholung: Equatable, Sendable {
    public let nummer: Int
    public let beginn: TimeInterval
    /// Geschwindigkeit null zwischen Hin- und Rueckweg.
    public let umkehr: TimeInterval
    public let ende: TimeInterval
    /// Betrag des Spitzenwerts im Profil-Signal (Grad/s oder m/s).
    public let ausschlag: Double
    public let sicherheit: Double
    /// nil fuer die erste Wiederholung des Satzes.
    public let pauseDavor: TimeInterval?

    public init(nummer: Int, beginn: TimeInterval, umkehr: TimeInterval, ende: TimeInterval,
                ausschlag: Double, sicherheit: Double, pauseDavor: TimeInterval?) {
        self.nummer = nummer; self.beginn = beginn; self.umkehr = umkehr; self.ende = ende
        self.ausschlag = ausschlag; self.sicherheit = sicherheit; self.pauseDavor = pauseDavor
    }

    public var dauerKonzentrisch: TimeInterval { umkehr - beginn }
    public var dauerExzentrisch: TimeInterval { ende - umkehr }
}

public enum ZaehlerEreignis: Equatable, Sendable {
    case wiederholung(Wiederholung)
    case unsicher(UnsicherGrund)
    case zuende
}
