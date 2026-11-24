import Foundation

public enum Weg: Sendable, Equatable { case kraftweg, ablassen }

/// Umkehrpunkt oder Mitte eines Wegs der Soll-Welle.
public struct Taktmarke: Sendable, Equatable {
    public let t: TimeInterval
    public let lage: Double

    public init(t: TimeInterval, lage: Double) {
        self.t = t; self.lage = lage
    }
}

/// Soll-Lage der Last als reine Funktion der Zeit seit der Los-Marke (Tempo-Spec 6.3).
/// Je Wiederholung ein Kraftweg (0 → 1) und ein Ablassen (1 → 0), jeweils eine Cosinus-Flanke ohne Haltezeit.
public struct Sollwelle: Sendable, Equatable {
    public static let standardHalbeBahnbreite = 0.2

    public let vorgabe: Tempovorgabe
    /// Halbe Breite der Bahn um die Soll-Lage, in Einheiten der Lage.
    public let halbeBahnbreite: Double

    /// Eine Bahnbreite, die nicht endlich oder nicht positiv ist, faellt auf `standardHalbeBahnbreite` zurueck.
    public init(vorgabe: Tempovorgabe, halbeBahnbreite: Double = Sollwelle.standardHalbeBahnbreite) {
        self.vorgabe = vorgabe
        self.halbeBahnbreite = halbeBahnbreite.isFinite && halbeBahnbreite > 0 ? halbeBahnbreite : Self.standardHalbeBahnbreite
    }

    /// t in Sekunden seit der Los-Marke; davor die Ruhelage.
    public func lage(bei t: TimeInterval) -> Double {
        guard t.isFinite, t > 0 else { return 0 }
        let tau = t.truncatingRemainder(dividingBy: vorgabe.periode)
        if tau < vorgabe.kraftweg {
            return Self.flanke(tau / vorgabe.kraftweg)
        }
        return 1 - Self.flanke((tau - vorgabe.kraftweg) / vorgabe.ablassen)
    }

    /// 0-basiert, nil vor der Los-Marke.
    public func periode(bei t: TimeInterval) -> Int? {
        guard t.isFinite, t >= 0, let k = Int(exactly: (t / vorgabe.periode).rounded(.down)) else { return nil }
        return k
    }

    public func weg(bei t: TimeInterval) -> Weg? {
        guard t.isFinite, t >= 0 else { return nil }
        return t.truncatingRemainder(dividingBy: vorgabe.periode) < vorgabe.kraftweg ? .kraftweg : .ablassen
    }

    public func zielzeit(wiederholungen: Int) -> TimeInterval {
        Double(max(0, wiederholungen)) * vorgabe.periode
    }

    /// Umkehrpunkte und Mitte jedes Wegs im Zeitfenster `von ..< bis`.
    /// Nicht endliche Grenzen und Fenster ueber 600 s (Schutz vor riesigen Listen) liefern eine leere Liste.
    public func taktmarken(von: TimeInterval, bis: TimeInterval) -> [Taktmarke] {
        guard von.isFinite, bis.isFinite, bis > max(von, 0), bis - von <= 600 else { return [] }
        let p = vorgabe.periode
        guard let erste = Int(exactly: (max(von, 0) / p).rounded(.down)),
              let letzte = Int(exactly: (bis / p).rounded(.up)) else { return [] }
        let punkte: [(Double, Double)] = [
            (0, 0), (vorgabe.kraftweg / 2, 0.5),
            (vorgabe.kraftweg, 1), (vorgabe.kraftweg + vorgabe.ablassen / 2, 0.5),
        ]
        var marken: [Taktmarke] = []
        for k in erste...letzte {
            let start = Double(k) * p
            for (dt, lage) in punkte {
                let t = start + dt
                if t >= von && t < bis && t >= 0 { marken.append(Taktmarke(t: t, lage: lage)) }
            }
        }
        return marken
    }

    /// Liegt `lage` zum Zeitpunkt `t` innerhalb der Bahn um die Soll-Lage?
    public func inDerBahn(_ lage: Double, bei t: TimeInterval) -> Bool {
        abs(lage - self.lage(bei: t)) <= halbeBahnbreite + 1e-9
    }

    /// Cosinus-Flanke von 0 nach 1 fuer `anteil` in 0…1.
    private static func flanke(_ anteil: Double) -> Double {
        (1 - cos(Double.pi * anteil)) / 2
    }
}
