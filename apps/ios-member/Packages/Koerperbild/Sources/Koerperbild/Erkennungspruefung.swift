import Foundation

/// Entscheidet ueber die Zeit, ob eine Person sauber im Bild ist
/// (bestanden) oder das Tracking verloren ging (verloren).
public struct Erkennungspruefung: Sendable {
    public static let bestandenNach: TimeInterval = 1.0
    public static let verlorenNach: TimeInterval = 1.0
    /// Gelenke naeher am Bildrand zaehlen nicht als im Rahmen.
    static let rand = 0.03

    private let vorgabe: Kameravorgabe
    private var skelett: Skelett?
    private var letzteZeit: TimeInterval?
    private var imRahmenSeit: TimeInterval?
    private var nichtAlleSicherSeit: TimeInterval?

    public init(vorgabe: Kameravorgabe) {
        self.vorgabe = vorgabe
    }

    public mutating func eingabe(t: TimeInterval, skelett: Skelett?) {
        self.skelett = skelett
        letzteZeit = t
        if imRahmen {
            if imRahmenSeit == nil { imRahmenSeit = t }
        } else {
            imRahmenSeit = nil
        }
        if alleSicher {
            nichtAlleSicherSeit = nil
        } else if nichtAlleSicherSeit == nil {
            nichtAlleSicherSeit = t
        }
    }

    public mutating func zuruecksetzen() {
        skelett = nil
        letzteZeit = nil
        imRahmenSeit = nil
        nichtAlleSicherSeit = nil
    }

    public var fuehrendeSeite: Koerperseite {
        switch vorgabe.seite {
        case .links: return .links
        case .rechts: return .rechts
        case .beide:
            let links = sichereAnzahl(.links)
            let rechts = sichereAnzahl(.rechts)
            return rechts > links ? .rechts : .links
        }
    }

    public var fehlendeGruppen: Set<Gelenkgruppe> {
        let seite = fuehrendeSeite
        let pflicht = vorgabe.pflichtgelenke(seite)
        var fehlend = Set<Gelenkgruppe>()
        for gruppe in Gelenkgruppe.allCases {
            let betroffen = gruppe.gelenke(seite).intersection(pflicht)
            if betroffen.contains(where: { skelett?.sicher($0) == nil }) { fehlend.insert(gruppe) }
        }
        return fehlend
    }

    public var imRahmen: Bool {
        let pflicht = vorgabe.pflichtgelenke(fuehrendeSeite)
        let lo = Self.rand, hi = 1 - Self.rand
        return pflicht.allSatisfy { g in
            guard let p = skelett?.sicher(g) else { return false }
            return p.x >= lo && p.x <= hi && p.y >= lo && p.y <= hi
        }
    }

    public var bestanden: Bool {
        guard let seit = imRahmenSeit, let t = letzteZeit else { return false }
        return t - seit >= Self.bestandenNach
    }

    public var verloren: Bool {
        guard let seit = nichtAlleSicherSeit, let t = letzteZeit else { return false }
        return t - seit > Self.verlorenNach
    }

    private var alleSicher: Bool {
        vorgabe.pflichtgelenke(fuehrendeSeite).allSatisfy { skelett?.sicher($0) != nil }
    }

    private func sichereAnzahl(_ seite: Koerperseite) -> Int {
        vorgabe.pflichtgelenke(seite).filter { skelett?.sicher($0) != nil }.count
    }
}
