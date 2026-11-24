import Foundation

/// Umfang eines Satzes in Grad, den der naechste Satz derselben Uebung als Start nimmt.
public struct GemerkterWinkel: Codable, Sendable, Equatable {
    public var hubGrad: Double

    public init(hubGrad: Double) { self.hubGrad = hubGrad }
}

/// Lage der Last direkt aus dem Sensorwinkel: wie weit sich die Schwerkraftrichtung im Sensorrahmen
/// gegenueber der Ruhe gedreht hat. Benutzt werden nur Roll (`winkel.x`) und Pitch (`winkel.y`).
///
/// Ablauf: eine Instanz je Satz, `init` → (`los()`) → `verarbeite` … → `ende()`. Es gibt kein Zuruecksetzen;
/// der naechste Satz bekommt eine neue Instanz und den Hub ueber `gemerkt`.
///
/// Signal: je Messwert ĝ = (−sin p, sin r · cos p, cos r · cos p); ĝ ist auch dort stetig, wo Roll und Pitch
/// als Euler-Winkel springen (nahe Pitch ±90°). Die Ruherichtung ĝ₀ ist das normierte Mittel von ĝ ueber den
/// stillen Teil. Drehwinkel φ: bis zur Festlegung der Drehebene der Winkel zwischen ĝ₀ und ĝ (≥ 0); sobald er
/// 20° erreicht, steht die Drehachse n = normiert(ĝ₀ × ĝ) fest, danach φ = atan2((ĝ₀ × ĝ) · n, ĝ₀ · ĝ),
/// ueber ±180° hinweg entfaltet (in Richtung des ersten Wegs positiv, auch ueber 180° hinaus).
/// `lage = φ / hub`. Eine Drehung um die Senkrechte aendert ĝ nicht und bleibt unsichtbar. Liegt ĝ weniger als
/// 20° von n (|ĝ · n| > cos 20°), ist φ nicht bestimmt: es wird gehalten, und die Lage ist nicht `sicher`.
///
/// "Still" heisst: in den letzten 0,5 s weicht ĝ hoechstens 4° vom Mittel dieser 0,5 s ab (Zittern der Hand
/// zaehlt nicht als Bewegung). Das stille Mittel ist das Mittel der letzten Sekunde, wenn sie still ist, sonst
/// das der letzten halben. Die Drehrate wird nicht benutzt.
///
/// Start: Mit `wartetAufLos` liefert `verarbeite` bis `los()` Lage 0 und `.unbekannt` und merkt sich das zuletzt
/// stille Mittel. `los()` legt ĝ₀ fest: das stille Mittel, wenn es gerade still ist; sonst das gemerkte, wenn es
/// hoechstens 3 s alt ist; sonst der letzte Messwert. Ohne `wartetAufLos` folgt ĝ₀ der Ruhe (stilles Mittel,
/// ohne je still zu sein der erste Messwert) und steht mit der ersten Bewegung ueber 5° fest.
/// Zeit: `losZeit` ist die Sensorzeit des Messwerts, bei dem `los()` wirksam wurde (ohne `wartetAufLos` die der
/// ersten Bewegung); `Lage.t` bleibt Sensorzeit, `sekundenSeitLos` rechnet sie in die Zeit der `Sollwelle` um.
///
/// Ab der Bewegung:
/// - Erste Wiederholung: Der Massstab ist vorlaeufig das Groessere aus 40° und dem bisherigen Gipfel,
///   nach dem ersten oberen Umkehrpunkt dessen Hoehe. `sicher` wird erst mit dem ersten unteren Umkehrpunkt.
/// - Hub bekannt: Nach dem zweiten Gipfel gilt der Mittelwert der ersten beiden, danach folgt der Hub
///   je Wiederholung um hoechstens 10 %, aber nur bei mindestens 80 % des Hubs. Jeder neue Massstab
///   gilt erst, wenn der untere Umkehrpunkt der Wiederholung erkannt ist (die Lage ist dann nahe 0).
/// Umkehrpunkte entstehen ueber eine Hysterese von 10 % des Hubs, solange der Hub nicht bekannt ist mindestens 10°;
/// unten auch durch Stillstand bei Lage < 0,35.
/// Die Richtung folgt dem Trend der Lage ueber 0,1 s mit einer Totzone von 1 % des Hubs.
///
/// Ende: Nach `ende()` steht die Lage (unsicher), Umkehrpunkte, `gemerkt` und der groesste Ausschlag bleiben;
/// eine angefangene Wiederholung zaehlt nicht. Eine Rate, die nicht endlich oder nicht positiv ist, gilt als 50 Hz.
public struct Winkellage: Sendable {
    public static let mindesthubGrad = 40.0
    private static let bewegungGrad = 5.0, achseFestGrad = 20.0
    /// |ĝ · n| ueber cos 20°: ĝ liegt naeher als 20° an der Drehachse.
    private static let naheAchseKosinus = cos(20 * Double.pi / 180)
    private static let hysterese = 0.1
    /// Untergrenze der Hysterese, solange der Hub nicht bekannt ist (erste Wiederholung ohne gemerkten Wert).
    static let hystereseOhneHubGrad = 10.0
    /// Still: ĝ weicht in den letzten `stilleSekunden` hoechstens `stilleAbweichungGrad` vom Mittel ab.
    static let stilleSekunden = 0.5, stilleAbweichungGrad = 4.0
    private static let trendSekunden = 0.1, totzone = 0.01
    /// So alt darf das gemerkte stille Mittel bei `los()` hoechstens sein.
    static let stilleRuheHoechstensSekunden = 3.0

    private enum Phase { case ruhe, hin, rueck }

    private let rateHz: Double
    private let uebergeben: GemerkterWinkel?
    private let wartetAufLos: Bool
    private var losGegeben = false

    // Schwerkraftrichtung: letzte Sekunde, Ruherichtung, Drehachse, entfalteter Drehwinkel.
    private var fenster: [Vektor3] = []
    private var letzteT: TimeInterval?
    /// Waehrend des Wartens: das zuletzt stille Mittel von ĝ und die Zeit seines letzten Messwerts.
    private var stilleRuhe: (richtung: Vektor3, t: TimeInterval)?
    private var ruhe: Vektor3?
    private var ruheFest = false
    private var drehachse: Vektor3?
    /// ĝ liegt weniger als 20° von der Drehachse: φ ist dort nicht bestimmt und wird gehalten.
    private var naheAchse = false
    private var phiRoh = 0.0
    /// Aktueller Drehwinkel φ gegenueber der Ruherichtung, in Grad.
    public private(set) var drehwinkelGrad = 0.0
    private var verlauf: [Double] = []
    private var trend = Wegrichtung.unbekannt

    private var phase = Phase.ruhe
    private var ausschlag = 0.0
    private var hoechste = 0.0
    private var gipfel = 0.0, gipfelT = 0.0, tal = 0.0, talT = 0.0
    private var massstab: Double
    private var neuerMassstab: Double?
    private var massstabGesetzt = false
    private var gipfelhoehen: [Double] = []
    private var ersterBoden = false
    private var luecke = false
    /// Der letzte obere Umkehrpunkt steht in `umkehrpunkte` und `gipfelhoehen`, sein unterer fehlt noch.
    private var offenerGipfel = false
    private var beendet = false
    private var letzteLage: Lage?

    public private(set) var umkehrpunkte: [Umkehrpunkt] = []

    /// Sensorzeit `t` des Messwerts, bei dem `los()` wirksam wurde (der erste nach dem Aufruf); ohne `wartetAufLos`
    /// die Zeit der ersten Bewegung. nil davor.
    public private(set) var losZeit: TimeInterval?

    /// Sekunden seit der Los-Marke fuer die Sensorzeit `t` (die Zeit, die `Sollwelle` und `Tempoauswertung` erwarten);
    /// nil vor `losZeit` oder bei nicht endlichem `t`. Vor `losZeit` liegende Zeiten ergeben negative Werte.
    public func sekundenSeitLos(_ t: TimeInterval) -> TimeInterval? {
        guard let losZeit, t.isFinite else { return nil }
        return t - losZeit
    }

    /// Rate, wenn `rateHz` nicht endlich oder nicht positiv ist.
    static let ersatzRateHz = 50.0

    public init(rateHz: Double, gemerkt: GemerkterWinkel? = nil, wartetAufLos: Bool = false) {
        self.rateHz = rateHz.isFinite && rateHz > 0 ? rateHz : Self.ersatzRateHz
        self.wartetAufLos = wartetAufLos
        // Ein unbrauchbarer Wert (Hub nicht positiv oder nicht endlich) gilt als nicht gemerkt.
        let brauchbar = gemerkt.flatMap { $0.hubGrad > 0 && $0.hubGrad.isFinite ? $0 : nil }
        uebergeben = brauchbar
        massstab = brauchbar?.hubGrad ?? Self.mindesthubGrad
    }

    /// Groesster Ausschlag aus der Ruhelage bisher, in Grad.
    public var groessterAusschlagGrad: Double { ausschlag }

    /// Ob `verarbeite` noch auf `los()` wartet.
    public var wartet: Bool { wartetAufLos && !losGegeben }

    public var gemerkt: GemerkterWinkel? {
        guard gipfelhoehen.count >= 2 else { return uebergeben }
        return GemerkterWinkel(hubGrad: neuerMassstab ?? massstab)
    }

    /// Der Hub, mit dem die Lage gerade gerechnet wird.
    private var hub: Double { uebergeben == nil && !massstabGesetzt ? max(Self.mindesthubGrad, hoechste) : massstab }

    private var hubBekannt: Bool { uebergeben != nil || (ersterBoden && massstabGesetzt) }

    /// Ausdruecklicher Start: die Ruherichtung steht ab jetzt fest, erst danach zaehlen Bewegung, Drehachse,
    /// Massstab und Umkehrpunkte. Ein zweiter Aufruf oder ein Aufruf nach der ersten Bewegung aendert nichts.
    public mutating func los() {
        guard !losGegeben else { return }
        losGegeben = true
        guard phase == .ruhe, !fenster.isEmpty else { return }
        if let jetzt = stillesMittel() {
            ruhe = jetzt
        } else if let gemerkt = stilleRuhe, let t = letzteT, t - gemerkt.t <= Self.stilleRuheHoechstensSekunden {
            ruhe = gemerkt.richtung
        } else {
            ruhe = fenster.last
        }
        ruheFest = true
    }

    /// Satzende: ab jetzt liefert `verarbeite` die zuletzt gezeigte Lage (mit der Zeit des neuen Messwerts) und
    /// `sicher = false`; es entstehen keine Umkehrpunkte mehr, `gemerkt`, `umkehrpunkte` und `groessterAusschlagGrad`
    /// aendern sich nicht. Eine angefangene Wiederholung zaehlt nicht: steht ihr oberer Umkehrpunkt schon in der Liste,
    /// ihr unterer aber nicht, faellt er heraus, und seine Hoehe geht nicht in den Hub ein.
    public mutating func ende() {
        guard !beendet else { return }
        beendet = true
        if offenerGipfel {
            umkehrpunkte.removeLast(); gipfelhoehen.removeLast(); neuerMassstab = nil; offenerGipfel = false
        }
    }

    public mutating func luecke(von: TimeInterval, bis: TimeInterval) {
        guard !wartet, !beendet else { return }
        // Fehlt der Umkehrpunkt womoeglich in der Luecke, taugt dessen Zeit und Hoehe nicht.
        if (phase == .hin && gipfel > 0.5 * hub) || (phase == .rueck && tal < 0.5 * hub) { luecke = true }
    }

    public mutating func verarbeite(_ m: SensorMesswert) -> Lage {
        if beendet {
            let l = letzteLage
            return Lage(t: m.t, lage: l?.lage ?? 0, richtung: l?.richtung ?? .unbekannt, sicher: false)
        }
        let lage = naechsteLage(m)
        letzteLage = lage
        return lage
    }

    private mutating func naechsteLage(_ m: SensorMesswert) -> Lage {
        let g = Self.schwerkraft(m.winkel)
        fenster.append(g)
        if fenster.count > Int(rateHz) { fenster.removeFirst() }
        letzteT = m.t
        if wartet {
            if let mittel = stillesMittel() { stilleRuhe = (mittel, m.t) }
            return Lage(t: m.t, lage: 0, richtung: .unbekannt, sicher: false)
        }
        if wartetAufLos && losZeit == nil { losZeit = m.t }
        if phase == .ruhe && !ruheFest { ruheNachfuehren(g) }

        let s = drehwinkel(g)
        drehwinkelGrad = s
        if phase == .ruhe && abs(s) > Self.bewegungGrad {
            phase = .hin; gipfel = 0; gipfelT = m.t; ruheFest = true
            if losZeit == nil { losZeit = m.t }
        }
        if phase != .ruhe { ausschlag = max(ausschlag, abs(s)); hoechste = max(hoechste, s); folge(s, t: m.t) }
        let trendLaenge = max(1, Int(Self.trendSekunden * rateHz))
        verlauf.append(s)
        if verlauf.count > trendLaenge + 1 { verlauf.removeFirst() }
        if phase != .ruhe, verlauf.count > trendLaenge {
            let aenderung = s - verlauf[0]
            if abs(aenderung) >= Self.totzone * hub { trend = aenderung > 0 ? .hin : .rueck }
        }
        return Lage(t: m.t, lage: s / hub, richtung: phase == .ruhe ? .unbekannt : trend, sicher: hubBekannt && hub >= Self.mindesthubGrad && !naheAchse)
    }

    // MARK: Richtung und Drehwinkel

    /// Drehwinkel φ in Grad; legt beim ersten Erreichen von 20° die Drehachse fest.
    private mutating func drehwinkel(_ g: Vektor3) -> Double {
        guard let g0 = ruhe else { return 0 }
        let kreuz = Self.kreuz(g0, g), cosinus = Self.punkt(g0, g)
        guard let n = drehachse else {
            let winkel = atan2(Self.betrag(kreuz), cosinus) * 180 / .pi
            if winkel >= Self.achseFestGrad { drehachse = Self.normiert(kreuz); phiRoh = winkel }
            return winkel
        }
        naheAchse = abs(Self.punkt(g, n)) > Self.naheAchseKosinus
        if naheAchse { return drehwinkelGrad }
        let roh = atan2(Self.punkt(kreuz, n), cosinus) * 180 / .pi
        var d = (roh - phiRoh).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        phiRoh = roh
        return drehwinkelGrad + d
    }

    /// Ob ĝ in den letzten `n` Messwerten hoechstens 4° von seinem Mittel abwich.
    private func still(_ n: Int) -> Bool {
        guard fenster.count >= n, n > 0 else { return false }
        let w = fenster.suffix(n), m = Self.mittel(w)
        let grenze = cos(Self.stilleAbweichungGrad * .pi / 180)
        return w.allSatisfy { Self.punkt($0, m) >= grenze }
    }

    /// Mittel von ĝ ueber die letzte Sekunde, wenn sie still ist; sonst ueber die letzte halbe, wenn sie still ist;
    /// sonst nil.
    private func stillesMittel() -> Vektor3? {
        let halbe = Int(Self.stilleSekunden * rateHz)
        guard still(halbe) else { return nil }
        return still(Int(rateHz)) ? Self.mittel(fenster) : Self.mittel(fenster.suffix(halbe))
    }

    /// Ruherichtung: das stille Mittel (`stillesMittel`), solange still; sonst bleibt sie, ohne je still der erste Messwert.
    private mutating func ruheNachfuehren(_ g: Vektor3) {
        if let mittel = stillesMittel() {
            ruhe = mittel
        } else if ruhe == nil {
            ruhe = g
        }
    }

    // MARK: Umkehrpunkte

    private mutating func folge(_ s: Double, t: TimeInterval) {
        let schwelle = hubBekannt ? Self.hysterese * hub : max(Self.hystereseOhneHubGrad, Self.hysterese * hub)
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
        offenerGipfel = true
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
        offenerGipfel = false
        if let neu = neuerMassstab { massstab = neu; massstabGesetzt = true; neuerMassstab = nil }
        guard !luecke else { return }
        umkehrpunkte.append(Umkehrpunkt(t: t, oben: false))
    }
}

// MARK: - Vektoren

extension Winkellage {
    /// Schwerkraftrichtung im Sensorrahmen aus Roll (`x`) und Pitch (`y`) in Grad; Yaw wird nicht gebraucht.
    static func schwerkraft(_ winkel: Vektor3) -> Vektor3 {
        let r = winkel.x * .pi / 180, p = winkel.y * .pi / 180
        return Vektor3(x: -sin(p), y: sin(r) * cos(p), z: cos(r) * cos(p))
    }
    static func punkt(_ a: Vektor3, _ b: Vektor3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
    static func kreuz(_ a: Vektor3, _ b: Vektor3) -> Vektor3 {
        Vektor3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
    }
    static func betrag(_ a: Vektor3) -> Double { punkt(a, a).squareRoot() }
    static func normiert(_ a: Vektor3) -> Vektor3 {
        let b = betrag(a)
        return b > 0 ? Vektor3(x: a.x / b, y: a.y / b, z: a.z / b) : a
    }
    /// Normiertes Mittel der Richtungen.
    static func mittel<S: Sequence>(_ richtungen: S) -> Vektor3 where S.Element == Vektor3 {
        var x = 0.0, y = 0.0, z = 0.0
        for r in richtungen { x += r.x; y += r.y; z += r.z }
        return normiert(Vektor3(x: x, y: y, z: z))
    }
}
