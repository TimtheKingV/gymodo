import Foundation

/// Welche Koerperpartie die Kamera sehen muss.
public enum Kameraprofil: String, CaseIterable, Sendable {
    case ganzkoerperStehend = "ganzkoerper_stehend"
    case oberkoerper = "oberkoerper"
    case stuetzBoden = "stuetz_boden"
    case liegend = "liegend"
    case zugHaengend = "zug_haengend"
    case ohneKamera = "ohne_kamera"
}

public enum Seitenwahl: String, Sendable { case links, rechts, beide }

/// Kameravorgabe einer Uebung: Profil, Signalwinkel und Koerperseite.
public struct Kameravorgabe: Sendable, Equatable {
    public let profil: Kameraprofil
    public let signal: Gelenkwinkel?
    public let seite: Seitenwahl

    /// Ohne Signal gibt es nur das Profil `ohneKamera`; dort wird ein Signal verworfen.
    public init?(profil: Kameraprofil, signal: Gelenkwinkel?, seite: Seitenwahl) {
        if profil == .ohneKamera {
            self.signal = nil
        } else {
            guard let signal else { return nil }
            self.signal = signal
        }
        self.profil = profil
        self.seite = seite
    }

    /// Gelenke, die auf dieser Seite sicher im Bild sein muessen.
    public func pflichtgelenke(_ seite: Koerperseite) -> Set<Gelenk> {
        var menge = Set<Gelenk>()
        let l = seite == .links
        let schulter: Gelenk = l ? .schulterL : .schulterR
        let ellbogen: Gelenk = l ? .ellbogenL : .ellbogenR
        let hand: Gelenk = l ? .handL : .handR
        let huefte: Gelenk = l ? .hueftL : .hueftR
        let knie: Gelenk = l ? .knieL : .knieR
        let fuss: Gelenk = l ? .fussL : .fussR
        switch profil {
        case .ganzkoerperStehend: menge = [schulter, huefte, knie, fuss]
        case .oberkoerper, .zugHaengend: menge = [schulter, ellbogen, hand]
        case .stuetzBoden: menge = [schulter, ellbogen, hand, huefte]
        case .liegend, .ohneKamera: break
        }
        if let signal {
            let (a, b, c) = signal.gelenke(seite)
            menge.formUnion([a, b, c])
        }
        return menge
    }
}

/// Gelenkgruppen, in denen der Nutzer fehlende Gelenke gemeldet bekommt.
public enum Gelenkgruppe: CaseIterable, Sendable {
    case schultern, arme, hueftenKnie, fuesse

    public func gelenke(_ seite: Koerperseite) -> Set<Gelenk> {
        let l = seite == .links
        switch self {
        case .schultern: return [l ? .schulterL : .schulterR]
        case .arme: return l ? [.ellbogenL, .handL] : [.ellbogenR, .handR]
        case .hueftenKnie: return l ? [.hueftL, .knieL] : [.hueftR, .knieR]
        case .fuesse: return [l ? .fussL : .fussR]
        }
    }
}
