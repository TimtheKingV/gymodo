import Foundation

/// Was vom Zaehler am Satz gespeichert wird (Spec B 6.2) -- als rep_events
/// auf dem Server und als zaehler.ereignisse in aufnahme.json. Nur Werte,
/// die sich nicht ableiten lassen: Phasendauern und Pausen rechnet, wer sie
/// braucht (Teilprojekt C, D).
public struct RepEvents: Codable, Equatable, Sendable {
    public struct Eintrag: Codable, Equatable, Sendable {
        public let beginn: Double
        public let umkehr: Double
        public let ende: Double
        public let ausschlag: Double
        public let sicherheit: Double

        public init(beginn: Double, umkehr: Double, ende: Double, ausschlag: Double, sicherheit: Double) {
            self.beginn = beginn; self.umkehr = umkehr; self.ende = ende
            self.ausschlag = ausschlag; self.sicherheit = sicherheit
        }
    }

    public let algo: String
    public let befestigungsart: Befestigungsart
    public let unsicher: UnsicherGrund?
    public let wiederholungen: [Eintrag]

    public init(algo: String, befestigungsart: Befestigungsart,
                ereignisse: [ZaehlerEreignis], satzbeginn: TimeInterval) {
        self.algo = algo
        self.befestigungsart = befestigungsart
        var unsicher: UnsicherGrund?
        var liste: [Eintrag] = []
        for ereignis in ereignisse {
            switch ereignis {
            case .wiederholung(let w):
                liste.append(Eintrag(beginn: Self.r(w.beginn - satzbeginn), umkehr: Self.r(w.umkehr - satzbeginn),
                                     ende: Self.r(w.ende - satzbeginn), ausschlag: Self.r(w.ausschlag),
                                     sicherheit: Self.r(w.sicherheit)))
            case .unsicher(let grund):
                unsicher = grund
            case .zuende:
                break
            }
        }
        self.unsicher = unsicher
        self.wiederholungen = liste
    }

    /// Zwei Nachkommastellen: feiner als das 30-ms-Raster ist keine Zeit.
    private static func r(_ wert: Double) -> Double { (wert * 100).rounded() / 100 }

    private enum CodingKeys: String, CodingKey { case algo, befestigungsart, unsicher, wiederholungen }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(algo, forKey: .algo)
        try c.encode(befestigungsart, forKey: .befestigungsart)
        // Immer als Schluessel, auch als null (Spec B 6.2).
        try c.encode(unsicher, forKey: .unsicher)
        try c.encode(wiederholungen, forKey: .wiederholungen)
    }
}
