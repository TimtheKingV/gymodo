import Foundation

/// Die Koerperpunkte, die Apples Erkennung liefert (ohne Augen und Ohren).
public enum Gelenk: String, CaseIterable, Sendable {
    case nase, hals
    case schulterL, schulterR, ellbogenL, ellbogenR, handL, handR
    case wurzel, hueftL, hueftR, knieL, knieR, fussL, fussR
}

/// Lage im Bild: 0...1, Ursprung oben links.
public struct Punkt: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var sicherheit: Double
    public init(x: Double, y: Double, sicherheit: Double) {
        self.x = x; self.y = y; self.sicherheit = sicherheit
    }
}

public enum Koerperseite: Sendable { case links, rechts }

/// Die Gelenkwinkel, an denen eine Wiederholung abgelesen wird.
public enum Gelenkwinkel: String, CaseIterable, Sendable {
    case ellbogen, schulter, huefte, knie

    /// Die drei Gelenke des Winkels; der Winkel liegt am mittleren.
    public func gelenke(_ seite: Koerperseite) -> (Gelenk, Gelenk, Gelenk) {
        let l = seite == .links
        switch self {
        case .ellbogen: return l ? (.schulterL, .ellbogenL, .handL) : (.schulterR, .ellbogenR, .handR)
        case .schulter: return l ? (.ellbogenL, .schulterL, .hueftL) : (.ellbogenR, .schulterR, .hueftR)
        case .huefte: return l ? (.schulterL, .hueftL, .knieL) : (.schulterR, .hueftR, .knieR)
        case .knie: return l ? (.hueftL, .knieL, .fussL) : (.hueftR, .knieR, .fussR)
        }
    }
}

public struct Skelett: Sendable, Equatable {
    public var punkte: [Gelenk: Punkt]
    /// Breite durch Hoehe des Bildes; noetig, damit Winkel nicht verzerrt sind.
    public var seitenverhaeltnis: Double

    public init(punkte: [Gelenk: Punkt], seitenverhaeltnis: Double) {
        self.punkte = punkte
        self.seitenverhaeltnis = seitenverhaeltnis
    }

    public static let mindestSicherheit = 0.3

    public func sicher(_ g: Gelenk) -> Punkt? {
        guard let p = punkte[g], p.sicherheit >= Self.mindestSicherheit else { return nil }
        return p
    }

    /// Winkel am mittleren Gelenk in Grad, mit Vorzeichen (-180...180).
    /// Der Betrag ist der Gelenkwinkel (0 = ganz gebeugt, 180 = gestreckt).
    /// Das Vorzeichen braucht es, weil z.B. beim Rudern der Ellbogen hinter
    /// den Rumpf wandert: ohne Vorzeichen klappt der Schulterwinkel bei 0 um
    /// und eine Wiederholung zaehlt doppelt.
    public func winkel(_ w: Gelenkwinkel, seite: Koerperseite) -> Double? {
        let (a, b, c) = w.gelenke(seite)
        guard let pa = sicher(a), let pb = sicher(b), let pc = sicher(c) else { return nil }
        let v1 = ((pa.x - pb.x) * seitenverhaeltnis, pa.y - pb.y)
        let v2 = ((pc.x - pb.x) * seitenverhaeltnis, pc.y - pb.y)
        let kreuz = v1.0 * v2.1 - v1.1 * v2.0
        let punkt = v1.0 * v2.0 + v1.1 * v2.1
        guard abs(kreuz) + abs(punkt) > 1e-9 else { return nil }
        return atan2(kreuz, punkt) * 180 / .pi
    }
}
