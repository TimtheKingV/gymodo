import Foundation
import Sensorik

/// Eine gezaehlte Wiederholung: Beginn am unteren Umkehrpunkt (Startposition), Umkehr am oberen, Ende am unteren.
public struct Koerperwiederholung: Sendable, Equatable {
    public let beginn: TimeInterval
    public let umkehr: TimeInterval
    public let ende: TimeInterval

    public init(beginn: TimeInterval, umkehr: TimeInterval, ende: TimeInterval) {
        self.beginn = beginn; self.umkehr = umkehr; self.ende = ende
    }

    public var dauerHin: TimeInterval { umkehr - beginn }
    public var dauerRueck: TimeInterval { ende - umkehr }
}

/// Macht aus einer Folge erkannter Skelette die Lage (0...1) im Bewegungsumfang
/// eines Gelenkwinkels und zaehlt die Wiederholungen.
public struct Koerperlage: Sendable {
    /// Glaettung des Winkels in Sekunden (exponentiell).
    static let glaettung = 0.08
    /// Nach einer Luecke ueber dieser Zeit wird ohne Glaettung neu angesetzt.
    static let lueckeNeuAnsetzen: TimeInterval = 0.5
    /// Ruhig: Schwankung des geglaetteten Winkels ueber `ruheFenster` hoechstens so gross.
    static let ruheFenster: TimeInterval = 0.5
    static let ruheSchwankung = 5.0
    /// Eine Wiederholung zaehlt, sobald die Lage nach dem oberen Umkehrpunkt auf diesen Wert faellt.
    static let rueckkehrLage = 0.15
    /// Zeiten der Wiederholung: Messwerte, die hoechstens so viele Grad ueber dem Talminimum liegen, zaehlen als im Tal.
    static let talband = 1.5
    static let grundSchwelle = 15.0
    static let schwelleAnteil = 0.35
    static let mindestMassstab = 40.0
    static let hubZuKleinUnter = 20.0
    static let maxAenderungJeWiederholung = 0.10
    static let seitenGleichstand = 0.25
    static let startFenster: TimeInterval = 0.5

    private enum Phase { case ruhe, oben, unten, warteNaehe }

    private struct Seitenstand {
        var wert: Double?
        var tWert: TimeInterval?
        var verlauf: [(t: TimeInterval, w: Double)] = []
        var sicherheitSumme = 0.0
        var sicherheitAnzahl = 0
        var start: Double?
        var vorzeichen = 0.0
        var phase = Phase.ruhe
        var ausschlag = 0.0
        var zuletztNah = 0.0
        var tief = (u: 0.0, t: 0.0)
        var hoch = (u: 0.0, t: 0.0)
        var tiefVorher = 0.0
        var beginn = 0.0
        /// Oberer Umkehrpunkt der offenen Wiederholung.
        var umkehr: (u: Double, t: Double)?
        /// Die offene Wiederholung ist schon gezaehlt.
        var gezaehlt = false
        /// Richtung im Tal-Abschnitt: `.rueck` bis das Tal durchschritten ist und der Winkel wieder ansteigt.
        var talRichtung = Wegrichtung.hin
        /// Messwerte (Zeit, u) seit dem oberen Umkehrpunkt bzw. seit dem Tal.
        var rueckweg: [(t: TimeInterval, u: Double)] = []
        var letztesEnde = 0.0

        var mittlereSicherheit: Double { sicherheitAnzahl == 0 ? 0 : sicherheitSumme / Double(sicherheitAnzahl) }
    }

    private enum Ereignis {
        case oberer
        case fertig(Koerperwiederholung, ausschlag: Double)
        case endeKorrigiert(TimeInterval)
    }

    private let signal: Gelenkwinkel
    private let wahl: Seitenwahl
    private let gemerkterHub: Double?
    /// Wurde ein gueltiger gemerkter Hub uebergeben? Fuer `Satzrueckblick.init(welle:hubWarGemerkt:)`.
    public let hubWarGemerkt: Bool
    private var seiten = [Seitenstand(), Seitenstand()]   // 0 = links, 1 = rechts
    private var gelost = false
    private var losAusstehend = false
    private var letzteZeit: TimeInterval?
    private var letzteLage = 0.0
    private var gemessenerMassstab: Double?

    public private(set) var wiederholungen: [Koerperwiederholung] = []
    public private(set) var fuehrendeSeite: Koerperseite?

    public init(vorgabe: Kameravorgabe, gemerkterHub: Double?) {
        precondition(vorgabe.signal != nil, "Koerperlage braucht eine Vorgabe mit Signal")
        self.signal = vorgabe.signal!
        self.wahl = vorgabe.seite
        // Ein nicht endlicher oder zu kleiner Hub (unter `hubZuKleinUnter`) gilt als nicht gemerkt.
        let gueltig = gemerkterHub.flatMap { $0.isFinite && $0 >= Self.hubZuKleinUnter ? $0 : nil }
        self.gemerkterHub = gueltig
        self.hubWarGemerkt = gueltig != nil
        self.gemessenerMassstab = gueltig
        switch vorgabe.seite {
        case .links: fuehrendeSeite = .links
        case .rechts: fuehrendeSeite = .rechts
        case .beide: fuehrendeSeite = nil
        }
    }

    // MARK: Abfragen

    /// Hub in Grad, sobald bekannt: gemerkt von Anfang an, sonst nach zwei gezaehlten Wiederholungen.
    public var hubGrad: Double? { hubBekannt ? gemessenerMassstab : nil }

    public var hubZuKlein: Bool {
        guard wiederholungen.count >= 2, let h = gemessenerMassstab else { return false }
        return h < Self.hubZuKleinUnter
    }

    public var istRuhig: Bool {
        let werte = kandidaten.compactMap { schwankung(seiten[$0], dauer: Self.ruheFenster) }
        return !werte.isEmpty && werte.allSatisfy { $0 <= Self.ruheSchwankung }
    }

    private var hubBekannt: Bool { gemerkterHub != nil || wiederholungen.count >= 2 }

    private var erlaubt: [Int] {
        switch wahl { case .links: [0]; case .rechts: [1]; case .beide: [0, 1] }
    }
    private var kandidaten: [Int] {
        if let f = fuehrendeSeite { return [Self.index(f)] }
        return erlaubt
    }
    private static func index(_ s: Koerperseite) -> Int { s == .links ? 0 : 1 }
    private static func seite(_ i: Int) -> Koerperseite { i == 0 ? .links : .rechts }

    // MARK: Steuerung

    /// Legt die Startposition fest: Mittel des geglaetteten Winkels der letzten 0,5 s.
    public mutating func los(t: TimeInterval) {
        gelost = true
        for i in erlaubt {
            let fenster = seiten[i].verlauf.filter { $0.t >= t - Self.startFenster && $0.t <= t }
            seiten[i].phase = .ruhe
            seiten[i].vorzeichen = 0
            seiten[i].ausschlag = 0
            seiten[i].umkehr = nil
            seiten[i].zuletztNah = t
            if fenster.isEmpty {
                seiten[i].start = nil
                losAusstehend = true
            } else {
                seiten[i].start = fenster.map(\.w).reduce(0, +) / Double(fenster.count)
            }
        }
    }

    /// Eine angefangene Wiederholung faellt weg, gezaehlte bleiben. Die naechste beginnt
    /// mit der naechsten Bewegung aus der Naehe der Startposition.
    public mutating func unterbrechen() {
        for i in erlaubt where seiten[i].start != nil {
            seiten[i].umkehr = nil
            seiten[i].gezaehlt = false
            seiten[i].rueckweg = []
            // Der Ausschlag ist die Basis des vorlaeufigen Massstabs; eine neue Bewegung beginnt von vorn.
            seiten[i].ausschlag = 0
            seiten[i].phase = seiten[i].vorzeichen == 0 ? .ruhe : .warteNaehe
        }
    }

    public mutating func verarbeite(t: TimeInterval, skelett: Skelett?) -> Lage {
        letzteZeit = t
        if let skelett {
            for i in erlaubt {
                let seite = Self.seite(i)
                if let roh = skelett.winkel(signal, seite: seite) {
                    aufnehmen(i, t: t, roh: roh)
                    let (a, b, c) = signal.gelenke(seite)
                    let summe = [a, b, c].compactMap { skelett.punkte[$0]?.sicherheit }.reduce(0, +)
                    seiten[i].sicherheitSumme += summe / 3
                    seiten[i].sicherheitAnzahl += 1
                }
            }
        }
        if gelost { folgen(t: t) }
        return lage(t: t)
    }

    // MARK: Winkel aufnehmen

    private mutating func aufnehmen(_ i: Int, t: TimeInterval, roh: Double) {
        var r = roh
        let wert: Double
        if let alt = seiten[i].wert, let tAlt = seiten[i].tWert {
            // Fortlaufend fuehren: der Sprung von 180 auf -180 ist keiner.
            r += 360 * ((alt - r) / 360).rounded()
            if t - tAlt > Self.lueckeNeuAnsetzen {
                wert = r
            } else {
                let a = 1 - exp(-(t - tAlt) / Self.glaettung)
                wert = alt + a * (r - alt)
            }
        } else {
            wert = r
        }
        seiten[i].wert = wert
        seiten[i].tWert = t
        seiten[i].verlauf.append((t, wert))
        seiten[i].verlauf.removeAll { $0.t < t - 2.0 }
        if losAusstehend, gelost, seiten[i].start == nil { seiten[i].start = wert }
        if seiten[i].start != nil { losAusstehend = erlaubt.contains { seiten[$0].start == nil } }
    }

    /// Spanne der geglaetteten Winkel in den letzten `dauer` Sekunden; nil, wenn die Seite
    /// nicht aktuell ist oder das Fenster noch nicht gefuellt.
    private func schwankung(_ s: Seitenstand, dauer: TimeInterval) -> Double? {
        guard let tw = s.tWert, let letzte = letzteZeit, tw >= letzte - 0.2,
              let erster = s.verlauf.first, erster.t <= tw - dauer + 0.1 else { return nil }
        let w = s.verlauf.filter { $0.t >= tw - dauer }.map(\.w)
        guard let lo = w.min(), let hi = w.max() else { return nil }
        return hi - lo
    }

    // MARK: Massstab und Schwelle

    private func massstab(_ s: Seitenstand) -> Double {
        gemessenerMassstab ?? max(Self.mindestMassstab, s.ausschlag)
    }
    private func schwelle(_ s: Seitenstand) -> Double {
        max(Self.grundSchwelle, Self.schwelleAnteil * massstab(s))
    }

    private mutating func wiederholungGezaehlt(_ w: Koerperwiederholung, ausschlag: Double) {
        wiederholungen.append(w)
        let g = Self.maxAenderungJeWiederholung
        if let alt = gemessenerMassstab, gemerkterHub != nil || wiederholungen.count >= 3 {
            gemessenerMassstab = min(max(ausschlag, alt * (1 - g)), alt * (1 + g))
        } else if let alt = gemessenerMassstab {
            gemessenerMassstab = (alt + ausschlag) / 2
        } else {
            gemessenerMassstab = ausschlag
        }
    }

    // MARK: Umkehrpunkte

    private mutating func folgen(t: TimeInterval) {
        for i in kandidaten where seiten[i].tWert == t {
            let ereignisse = schritt(i, t: t)
            for e in ereignisse {
                switch e {
                case .oberer:
                    if fuehrendeSeite == nil { fuehrendeSeite = waehleSeite() }
                case .fertig(let w, let ausschlag):
                    if fuehrendeSeite == Self.seite(i) { wiederholungGezaehlt(w, ausschlag: ausschlag) }
                case .endeKorrigiert(let ende):
                    if fuehrendeSeite == Self.seite(i), let l = wiederholungen.last {
                        wiederholungen[wiederholungen.count - 1] = Koerperwiederholung(beginn: l.beginn, umkehr: l.umkehr, ende: ende)
                    }
                }
            }
        }
    }

    /// Seite bei `Seitenwahl.beide`: groesserer Ausschlag; bei Gleichstand (25 %) die sicherere.
    private func waehleSeite() -> Koerperseite {
        let a0 = seiten[0].ausschlag, a1 = seiten[1].ausschlag
        let gross = max(a0, a1), klein = min(a0, a1)
        let groessere: Koerperseite = a1 > a0 ? .rechts : .links
        if gross > 0, (gross - klein) / gross <= Self.seitenGleichstand {
            let s0 = seiten[0].mittlereSicherheit, s1 = seiten[1].mittlereSicherheit
            if s0 != s1 { return s1 > s0 ? .rechts : .links }
        }
        return groessere
    }

    private mutating func schritt(_ i: Int, t: TimeInterval) -> [Ereignis] {
        guard let w = seiten[i].wert, let start = seiten[i].start else { return [] }
        var s = seiten[i]
        defer { seiten[i] = s }
        let dev = w - start
        s.ausschlag = max(s.ausschlag, abs(dev))
        let sw = schwelle(s)
        let u = s.vorzeichen * dev
        var ereignisse: [Ereignis] = []

        switch s.phase {
        case .ruhe:
            if abs(dev) <= Self.talband { s.zuletztNah = t }
            if abs(dev) >= sw {
                s.vorzeichen = dev > 0 ? 1 : -1
                s.phase = .oben
                s.hoch = (abs(dev), t)
                s.tiefVorher = 0
                s.beginn = s.zuletztNah
                s.umkehr = nil
                s.gezaehlt = false
            }
        case .oben:
            if u > s.hoch.u { s.hoch = (u, t) }
            if u <= s.hoch.u - sw {
                s.umkehr = s.hoch
                s.phase = .unten
                s.tief = (u, t)
                s.rueckweg = [(t, u)]
                s.gezaehlt = false
                s.talRichtung = .rueck
                ereignisse.append(.oberer)
            }
        case .unten:
            s.rueckweg.append((t, u))
            if u < s.tief.u { s.tief = (u, t) }
            // Kleine Totzone gegen Zittern: erst ein Anstieg ueber das Talband kehrt die Richtung um.
            if s.umkehr != nil, u > s.tief.u + Self.talband { s.talRichtung = .hin }
            let steigt = u >= s.tief.u + sw
            if !s.gezaehlt, let um = s.umkehr, steigt || u <= Self.rueckkehrLage * massstab(s) {
                s.letztesEnde = ende(s)
                ereignisse.append(.fertig(Koerperwiederholung(beginn: s.beginn, umkehr: um.t, ende: s.letztesEnde),
                                          ausschlag: um.u - s.tiefVorher))
                s.gezaehlt = true
            } else if s.gezaehlt, s.umkehr != nil {
                let e = ende(s)
                if e != s.letztesEnde { s.letztesEnde = e; ereignisse.append(.endeKorrigiert(e)) }
            }
            if steigt {
                s.beginn = s.rueckweg.last { $0.u <= s.tief.u + Self.talband }?.t ?? s.tief.t
                s.tiefVorher = s.tief.u
                s.phase = .oben
                s.hoch = (u, t)
                s.umkehr = nil
                s.gezaehlt = false
                s.rueckweg = []
            }
        case .warteNaehe:
            if abs(dev) < sw {
                s.phase = .unten
                s.tief = (u, t)
                s.tiefVorher = u
                s.beginn = t
                s.umkehr = nil
                s.gezaehlt = false
                s.rueckweg = [(t, u)]
            }
        }
        return ereignisse
    }

    /// Fruehester Messwert des Rueckwegs, der hoechstens `talband` ueber dem bisherigen Talminimum liegt.
    private func ende(_ s: Seitenstand) -> TimeInterval {
        let minimum = s.rueckweg.map(\.u).min() ?? s.tief.u
        return s.rueckweg.first { $0.u <= minimum + Self.talband }?.t ?? s.tief.t
    }

    // MARK: Lage

    private mutating func lage(t: TimeInterval) -> Lage {
        let aktuell = kandidaten.filter { seiten[$0].tWert == t }
        // Vor der Festlegung kommt die Lage aus der Seite mit dem bisher groesseren Ausschlag.
        let aktiv = aktuell.max { a, b in
            seiten[a].ausschlag != seiten[b].ausschlag ? seiten[a].ausschlag < seiten[b].ausschlag : a > b
        }
        guard let i = aktiv, let w = seiten[i].wert else {
            return Lage(t: t, lage: letzteLage, richtung: .unbekannt, sicher: false)
        }
        let s = seiten[i]
        let sicher = hubBekannt
        guard let start = s.start else {
            return Lage(t: t, lage: 0, richtung: .unbekannt, sicher: sicher)
        }
        let dev = w - start
        let vz = s.vorzeichen != 0 ? s.vorzeichen : (dev >= 0 ? 1 : -1)
        let lage = vz * dev / massstab(s)
        letzteLage = lage
        let richtung: Wegrichtung
        switch s.phase {
        case .ruhe, .warteNaehe: richtung = .unbekannt
        case .oben: richtung = .hin
        case .unten: richtung = s.umkehr == nil ? .hin : s.talRichtung
        }
        return Lage(t: t, lage: lage, richtung: richtung, sicher: sicher)
    }
}
