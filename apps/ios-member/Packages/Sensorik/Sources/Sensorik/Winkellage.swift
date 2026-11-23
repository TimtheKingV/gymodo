import Foundation

public enum Winkelachse: String, Codable, Sendable { case roll, pitch }

/// Umfang eines Satzes in Grad, den der naechste Satz derselben Uebung als Start nimmt.
public struct GemerkterWinkel: Codable, Sendable, Equatable {
    public var achse: Winkelachse
    /// +1 oder −1: Richtung des Kraftwegs in Grad.
    public var vorzeichen: Int
    public var hubGrad: Double

    public init(achse: Winkelachse, vorzeichen: Int, hubGrad: Double) {
        self.achse = achse; self.vorzeichen = vorzeichen; self.hubGrad = hubGrad
    }
}

/// Lage der Last direkt aus dem Sensorwinkel (Roll = `winkel.x`, Pitch = `winkel.y`).
/// `lage = vorzeichen · (winkel − ruhewinkel) / hub`.
///
/// Zustaende:
/// Die Drehrate wird nicht benutzt; "still" heisst: der Winkel auf der gewaehlten Achse (vor der Wahl auf
/// beiden) schwankt in den letzten 0,5 s um weniger als 8° (Zittern der Hand zaehlt nicht als Bewegung).
/// - Vor der ersten Bewegung (Ausschlag unter 5°): Der Ruhewinkel folgt dem Median der letzten Sekunde,
///   solange still, sonst bleibt er; ohne je still zu sein der erste Messwert. Die Richtung ist `.unbekannt`.
/// - Erste Wiederholung: Ruhewinkel steht fest. Ohne gemerkten Wert waehlt der groessere Ausschlag die
///   Achse (fest ab 20°); der Massstab ist vorlaeufig das Groessere aus 40° und dem bisherigen Gipfel,
///   nach dem ersten oberen Umkehrpunkt dessen Hoehe. `sicher` wird erst mit dem ersten unteren Umkehrpunkt.
/// - Hub bekannt: Nach dem zweiten Gipfel gilt der Mittelwert der ersten beiden, danach folgt der Hub
///   je Wiederholung um hoechstens 10 %, aber nur bei mindestens 80 % des Hubs. Jeder neue Massstab
///   gilt erst, wenn der untere Umkehrpunkt der Wiederholung erkannt ist (die Lage ist dann nahe 0).
/// Umkehrpunkte entstehen ueber eine Hysterese von 10 % des Hubs, unten auch durch Stillstand.
/// Die Richtung folgt dem Trend der Lage ueber 0,1 s mit einer Totzone von 1 % des Hubs.
public struct Winkellage: Sendable {
    public static let mindesthubGrad = 40.0
    private static let bewegungGrad = 5.0, achseFestGrad = 20.0
    private static let hysterese = 0.1, stilleSekunden = 0.5, stilleSpanneGrad = 8.0
    private static let trendSekunden = 0.1, totzone = 0.01

    private enum Phase { case ruhe, hin, rueck }

    private let rateHz: Double
    private let uebergeben: GemerkterWinkel?
    private var achse: Winkelachse?
    private var vorzeichen = 1

    // Entfaltete Winkel (Spruenge ueber ±180° herausgerechnet) und Ruhewinkel.
    private var roh: (roll: Double, pitch: Double)?
    private var winkel = (roll: 0.0, pitch: 0.0)
    private var ruhe = (roll: 0.0, pitch: 0.0)
    private var fenster: [(roll: Double, pitch: Double)] = []
    private var erster: (roll: Double, pitch: Double)?
    private var ruheGefunden = false
    private var verlauf: [Double] = []
    private var trend = Wegrichtung.unbekannt

    private var phase = Phase.ruhe
    private var ausschlag = (roll: 0.0, pitch: 0.0)
    private var hoechste = 0.0
    private var gipfel = 0.0, gipfelT = 0.0, tal = 0.0, talT = 0.0
    private var massstab: Double
    private var neuerMassstab: Double?
    private var massstabGesetzt = false
    private var gipfelhoehen: [Double] = []
    private var ersterBoden = false
    private var luecke = false

    public private(set) var umkehrpunkte: [Umkehrpunkt] = []

    public init(rateHz: Double, gemerkt: GemerkterWinkel? = nil) {
        self.rateHz = rateHz
        // Ein unbrauchbarer Wert (Hub nicht positiv, Vorzeichen nicht ±1) gilt als nicht gemerkt.
        let brauchbar = gemerkt.flatMap { $0.hubGrad > 0 && $0.hubGrad.isFinite && abs($0.vorzeichen) == 1 ? $0 : nil }
        uebergeben = brauchbar
        achse = brauchbar?.achse
        vorzeichen = brauchbar?.vorzeichen ?? 1
        massstab = brauchbar?.hubGrad ?? Self.mindesthubGrad
    }

    /// Groesster Ausschlag aus der Ruhelage bisher, in Grad.
    public var groessterAusschlagGrad: Double {
        switch achse {
        case .roll: ausschlag.roll
        case .pitch: ausschlag.pitch
        case nil: max(ausschlag.roll, ausschlag.pitch)
        }
    }

    public var gemerkt: GemerkterWinkel? {
        guard gipfelhoehen.count >= 2, let achse else { return uebergeben }
        return GemerkterWinkel(achse: achse, vorzeichen: vorzeichen, hubGrad: neuerMassstab ?? massstab)
    }

    /// Der Hub, mit dem die Lage gerade gerechnet wird.
    private var hub: Double { uebergeben == nil && !massstabGesetzt ? max(Self.mindesthubGrad, hoechste) : massstab }

    private var hubBekannt: Bool { uebergeben != nil || (ersterBoden && massstabGesetzt) }

    public mutating func luecke(von: TimeInterval, bis: TimeInterval) {
        // Fehlt der Umkehrpunkt womoeglich in der Luecke, taugt dessen Zeit und Hoehe nicht.
        if (phase == .hin && gipfel > 0.5 * hub) || (phase == .rueck && tal < 0.5 * hub) { luecke = true }
    }

    public mutating func verarbeite(_ m: SensorMesswert) -> Lage {
        entfalte(m.winkel)
        fenster.append(winkel)
        if fenster.count > Int(rateHz) { fenster.removeFirst() }
        if phase == .ruhe { ruheNachfuehren() }

        let roll = winkel.roll - ruhe.roll, pitch = winkel.pitch - ruhe.pitch
        if phase == .ruhe {
            let schwelle = achse == nil ? max(abs(roll), abs(pitch)) : abs(wert(roll, pitch))
            if schwelle > Self.bewegungGrad { phase = .hin; gipfel = 0; gipfelT = m.t }
        }
        if phase != .ruhe {
            ausschlag = (max(ausschlag.roll, abs(roll)), max(ausschlag.pitch, abs(pitch)))
            if achse == nil {
                let beste: Winkelachse = ausschlag.roll >= ausschlag.pitch ? .roll : .pitch
                if max(ausschlag.roll, ausschlag.pitch) >= Self.achseFestGrad {
                    achse = beste
                    vorzeichen = (beste == .roll ? roll : pitch) < 0 ? -1 : 1
                }
            }
        }
        let s = signal(roll, pitch)
        if phase != .ruhe { hoechste = max(hoechste, s); folge(s, t: m.t) }
        let trendLaenge = max(1, Int(Self.trendSekunden * rateHz))
        verlauf.append(s)
        if verlauf.count > trendLaenge + 1 { verlauf.removeFirst() }
        if phase != .ruhe, verlauf.count > trendLaenge {
            let aenderung = s - verlauf[0]
            if abs(aenderung) >= Self.totzone * hub { trend = aenderung > 0 ? .hin : .rueck }
        }
        return Lage(t: m.t, lage: s / hub, richtung: phase == .ruhe ? .unbekannt : trend, sicher: hubBekannt && hub >= Self.mindesthubGrad)
    }

    // MARK: Winkel

    private mutating func entfalte(_ w: Vektor3) {
        guard let vorher = roh else { winkel = (w.x, w.y); roh = (w.x, w.y); return }
        winkel = (winkel.roll + Self.falte(w.x - vorher.roll), winkel.pitch + Self.falte(w.y - vorher.pitch))
        roh = (w.x, w.y)
    }

    private static func falte(_ grad: Double) -> Double {
        var x = grad.truncatingRemainder(dividingBy: 360)
        if x > 180 { x -= 360 } else if x < -180 { x += 360 }
        return x
    }

    /// Ob der Winkel in den letzten `n` Messwerten auf der massgeblichen Achse still war.
    private func still(_ n: Int) -> Bool {
        guard fenster.count >= n, n > 0 else { return false }
        func spanne(_ f: ((roll: Double, pitch: Double)) -> Double) -> Double {
            let w = fenster.suffix(n).map(f)
            return w.max()! - w.min()!
        }
        let rollStill = achse == .pitch || spanne { $0.roll } < Self.stilleSpanneGrad
        let pitchStill = achse == .roll || spanne { $0.pitch } < Self.stilleSpanneGrad
        return rollStill && pitchStill
    }

    /// Ruhewinkel: Median der letzten Sekunde, solange still; sonst bleibt er, ohne je still der erste Messwert.
    private mutating func ruheNachfuehren() {
        if erster == nil { erster = winkel }
        let halbe = Int(Self.stilleSekunden * rateHz)
        if still(halbe) {
            let basis = still(Int(rateHz)) ? fenster : Array(fenster.suffix(halbe))
            func median(_ x: [Double]) -> Double { x.sorted()[x.count / 2] }
            ruhe = (median(basis.map(\.roll)), median(basis.map(\.pitch)))
            ruheGefunden = true
        } else if !ruheGefunden {
            ruhe = erster ?? winkel
        }
    }

    private func wert(_ roll: Double, _ pitch: Double) -> Double { achse == .pitch ? pitch : roll }

    /// Ausschlag in Kraftwegrichtung. Solange die Achse offen ist, zaehlt der groessere Ausschlag.
    private func signal(_ roll: Double, _ pitch: Double) -> Double {
        if achse != nil { return Double(vorzeichen) * wert(roll, pitch) }
        return abs(roll) >= abs(pitch) ? abs(roll) : abs(pitch)
    }

    // MARK: Umkehrpunkte

    private mutating func folge(_ s: Double, t: TimeInterval) {
        let schwelle = Self.hysterese * hub
        switch phase {
        case .ruhe: break
        case .hin:
            if s > gipfel { gipfel = s; gipfelT = t }
            if gipfel >= Self.achseFestGrad, s < gipfel - schwelle {
                oben(hoehe: gipfel, t: gipfelT)
                phase = .rueck; tal = s; talT = t
            }
        case .rueck:
            if s < tal { tal = s; talT = t }
            let steht = still(Int(Self.stilleSekunden * rateHz)) && s <= 0.35 * hub
            if s > tal + schwelle || steht {
                unten(t: talT)
                phase = .hin; gipfel = s; gipfelT = t
            }
        }
    }

    private mutating func oben(hoehe: Double, t: TimeInterval) {
        defer { luecke = false }
        guard !luecke else { return }
        umkehrpunkte.append(Umkehrpunkt(t: t, oben: true))
        gipfelhoehen.append(hoehe)
        switch gipfelhoehen.count {
        case 1: if uebergeben == nil { neuerMassstab = hoehe }
        case 2: neuerMassstab = (gipfelhoehen[0] + gipfelhoehen[1]) / 2
        default:
            if hoehe >= 0.8 * massstab {
                neuerMassstab = massstab + min(max(hoehe - massstab, -0.1 * massstab), 0.1 * massstab)
            }
        }
    }

    private mutating func unten(t: TimeInterval) {
        defer { luecke = false }
        ersterBoden = true
        if let neu = neuerMassstab { massstab = neu; massstabGesetzt = true; neuerMassstab = nil }
        guard !luecke else { return }
        umkehrpunkte.append(Umkehrpunkt(t: t, oben: false))
    }
}
