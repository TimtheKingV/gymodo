import Foundation

/// Regelbasierter Wiederholungszaehler (Sensor-Spec B 5.3). Rein: keine
/// Uhr, keine Nebenlaeufigkeit, kein Zufall -- offline gegen Aufnahmen und
/// live im Satzpfad laeuft derselbe Code.
///
/// Gefiltert wird mit der Sollrate statt mit Zeitstempel-Differenzen, weil
/// gebuendelte Messwerte denselben Zeitstempel tragen (Spec A 4.7); die
/// Zeitstempel bestimmen nur die Zeiten der Ereignisse und die Luecken.
public struct Zaehler: Sendable {
    private enum Halbwelle: Sendable {
        case wartet
        case erste(beginn: TimeInterval, spitze: Double)
        case zweite(beginn: TimeInterval, umkehr: TimeInterval, spitze: Double)
    }

    /// Filter und Halbwellen eines Signals. Normal gibt es eine; bei
    /// `achseAusErsterWiederholung` laeuft bis zur ersten Wiederholung je
    /// Drehachse eine eigene, danach nur noch die der gewaehlten Achse.
    private struct Spur: Sendable {
        var gefiltert: Double?
        /// Ruhewert des gefilterten Signals vor der ersten Wiederholung. Ein
        /// Gleichanteil (Drehraten-Bias, Rest-Schraeglage in der Geschwindigkeit)
        /// laege sonst dauerhaft ausserhalb des Bands um null, und der Beginn der
        /// ersten Wiederholung rutschte in den Ruhevorlauf (Spec B 5.3).
        var grundlinie: Double?
        /// Ab der ersten Halbwelle ueber der Schwelle ist die Ruhe vorbei; die
        /// Grundlinie darf danach nicht mehr folgen, auch nicht nach einem
        /// verworfenen ersten Versuch, sonst wanderte sie mit der Bewegung.
        var hinwegBegonnen = false
        var zustand: Halbwelle = .wartet
        var vorzeichen: Double?
        var schwelle: Double
        var letztesS = 0.0
        var nulldurchgang: TimeInterval?
    }

    /// Ein abgeschlossener Kandidat, der Dauer, Lage und Stoss bestanden hat.
    private struct Kandidat {
        let beginn: TimeInterval
        let umkehr: TimeInterval
        let ende: TimeInterval
        let spitze: Double
    }

    /// Was Lagepruefung und Achsenwahl je Messwert brauchen.
    private struct Verlauf: Sendable {
        let t: TimeInterval
        let lage: Quaternion
        let drehrate: Vektor3
        let beschleunigung: Double
    }

    public let profil: ZaehlerProfil
    private let dt: Double
    private let alpha: Double

    private var gestoppt = false
    private var letzteT: TimeInterval?
    private var wiederholungen: [Wiederholung] = []

    // Signalaufbereitung
    private var schwerkraft: Vektor3?
    private var achse: Int?
    private var puffer: [SensorMesswert] = []
    private var bewegtSeit: TimeInterval?
    private var geschwindigkeit = 0.0

    private var spur: Spur
    /// Nur bis zur ersten Wiederholung bei `achseAusErsterWiederholung`.
    private var spuren: [Spur]?
    /// Lage seit Satzbeginn (aus der Drehrate) und die Messwerte der
    /// letzten hoechstDauer, nur wenn das Profil sie braucht.
    private var lage = Quaternion.eins
    private var verlauf: [Verlauf] = []

    public init(profil: ZaehlerProfil, rateHz: Double = 50) {
        self.profil = profil
        dt = 1 / rateHz
        let rc = 1 / (2 * .pi * profil.tiefpassHz)
        alpha = dt / (rc + dt)
        spur = Spur(schwelle: profil.startSchwelle)
        if profil.signal != .drehrate {
            achse = -1 // braucht keine Achsensuche
        } else if profil.achseAusErsterWiederholung {
            spuren = Array(repeating: Spur(schwelle: profil.startSchwelle), count: 3)
        }
    }

    public var anzahl: Int { wiederholungen.count }

    public mutating func verarbeite(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        guard !gestoppt else { return [] }
        defer { letzteT = m.t }
        if let letzteT, m.t - letzteT > profil.lueckeAb {
            return stoppen(.luecke)
        }
        lageNachfuehren(m)
        schwerkraftNachfuehren(m)

        if spuren != nil { return parallelSchritt(m) }
        guard achse != nil else {
            return achseSuchen(m)
        }
        return schritt(m, roh: rohsignal(m))
    }

    public mutating func luecke(von: TimeInterval, bis: TimeInterval) -> [ZaehlerEreignis] {
        guard !gestoppt else { return [] }
        return stoppen(.luecke)
    }

    public mutating func abschliessen() -> [ZaehlerEreignis] {
        gestoppt = true
        return [.zuende]
    }

    // MARK: - Aufbereitung

    private static func betrag(_ v: Vektor3) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    // Absoluter Betrag: setzt einen kleinen Gyro-Gleichanteil voraus, siehe ZaehlerProfil.ruheDrehrate.
    private func ruhig(_ m: SensorMesswert) -> Bool {
        Self.betrag(m.drehrate) < profil.ruheDrehrate
            && abs(Self.betrag(m.beschleunigung) - 1) < profil.ruheBeschleunigung
    }

    private mutating func schwerkraftNachfuehren(_ m: SensorMesswert) {
        guard let g = schwerkraft else { schwerkraft = m.beschleunigung; return }
        // Nur in Ruhe nachfuehren: in Bewegung waere die Beschleunigung der
        // Hantel ein Teil der Schaetzung. Zeitkonstante rund 2 s.
        guard ruhig(m) else { return }
        let k = dt / (2 + dt)
        schwerkraft = Vektor3(x: g.x + k * (m.beschleunigung.x - g.x),
                              y: g.y + k * (m.beschleunigung.y - g.y),
                              z: g.z + k * (m.beschleunigung.z - g.z))
    }

    /// Integriert die Drehrate zur Lage (Schritt mit der Sollrate wie der
    /// Filter) und haelt die Messwerte so lange, wie eine Wiederholung
    /// hoechstens dauert, plus Rand. Ueber die zwei bis drei Sekunden einer
    /// Wiederholung ist die Drift des Gyros vernachlaessigbar.
    private mutating func lageNachfuehren(_ m: SensorMesswert) {
        guard profil.lageHoechstens != nil || spuren != nil else { return }
        let rad = Double.pi / 180 * dt
        lage = lage.gedreht(x: m.drehrate.x * rad, y: m.drehrate.y * rad, z: m.drehrate.z * rad)
        verlauf.append(Verlauf(t: m.t, lage: lage, drehrate: m.drehrate,
                               beschleunigung: Self.betrag(m.beschleunigung)))
        let grenze = m.t - profil.hoechstDauer - 2
        if let erster = verlauf.firstIndex(where: { $0.t >= grenze }), erster > 0 {
            verlauf.removeFirst(erster)
        }
    }

    /// Lage beim letzten Messwert bis `t`; bei gebuendelten Zeitstempeln
    /// der letzte des Buendels.
    private func lage(bei t: TimeInterval) -> Quaternion {
        verlauf.last { $0.t <= t }?.lage ?? verlauf.first?.lage ?? .eins
    }

    /// Nur fuer Drehraten-Profile: sammeln, bis die erste Bewegung lang
    /// genug ist, dann die Achse mit der groessten Streuung waehlen und den
    /// Puffer nachspielen, damit die erste Wiederholung nicht verloren geht.
    private mutating func achseSuchen(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        puffer.append(m)
        if bewegtSeit == nil, bewegt(m) { bewegtSeit = m.t }
        guard let seit = bewegtSeit else {
            // Ruhevorlauf: nur die letzte Sekunde behalten.
            puffer.removeAll { m.t - $0.t > 1 }
            return []
        }
        guard m.t - seit >= profil.achsenFenster else { return [] }
        let bewegung = puffer.filter { $0.t >= seit }
        // Die Achse erst festlegen, wenn die Bewegung angehalten hat: ein
        // kurzer Stoss im Vorlauf (Hantel angestossen) wuerde sonst eine
        // falsche Achse fuer den ganzen Satz waehlen, und der Satz bliebe
        // stumm bei 0. Gemessen wird gegen die Ruheschwelle, nicht gegen die
        // Startschwelle der Suche: bei kleinem Ausschlag (Spitze knapp ueber
        // 30 Grad/s) laege sonst die meiste Zeit unter der Startschwelle und
        // die Achse wuerde nie gewaehlt. Mehrheit statt "alle", weil die
        // Drehrate um die Umkehr herum durch null geht.
        let nichtRuhig = bewegung.filter { Self.betrag($0.drehrate) > profil.ruheDrehrate }.count
        guard nichtRuhig * 2 > bewegung.count else {
            bewegtSeit = bewegt(m) ? m.t : nil
            puffer.removeAll { m.t - $0.t > 1 }
            return []
        }
        achse = Self.achseGroessterStreuung(bewegung.map(\.drehrate))
        let nachspielen = puffer
        puffer = []
        var ereignisse: [ZaehlerEreignis] = []
        for alt in nachspielen { ereignisse += schritt(alt, roh: rohsignal(alt)) }
        return ereignisse
    }

    /// Bei Gleichstand gewinnt die hoehere Achse.
    private static func achseGroessterStreuung(_ drehraten: [Vektor3]) -> Int {
        func streuung(_ wert: (Vektor3) -> Double) -> Double {
            let werte = drehraten.map(wert)
            let mittel = werte.reduce(0, +) / Double(werte.count)
            return werte.reduce(0) { $0 + ($1 - mittel) * ($1 - mittel) }
        }
        let streuungen = [streuung(\.x), streuung(\.y), streuung(\.z)]
        return streuungen.indices.max { streuungen[$0] < streuungen[$1] } ?? 0
    }

    private func bewegt(_ m: SensorMesswert) -> Bool {
        Self.betrag(m.drehrate) > 3 * profil.ruheDrehrate
    }

    private static func komponente(_ v: Vektor3, _ achse: Int) -> Double {
        switch achse {
        case 0: v.x
        case 1: v.y
        default: v.z
        }
    }

    private mutating func rohsignal(_ m: SensorMesswert) -> Double {
        switch profil.signal {
        case .drehrate:
            return Self.komponente(m.drehrate, achse ?? 2)
        case .geschwindigkeitVertikal:
            let g = schwerkraft ?? Vektor3(x: 0, y: 0, z: 1)
            let gBetrag = max(Self.betrag(g), 0.0001)
            let entlang = (m.beschleunigung.x * g.x + m.beschleunigung.y * g.y + m.beschleunigung.z * g.z) / gBetrag
            return integrieren((entlang - gBetrag) * 9.81)
        case .geschwindigkeitBetrag:
            // Gegen 1 g statt gegen die geschaetzte Schwerkraft: die
            // Schaetzung folgt auch einem langsamen Hub (er gilt als ruhig)
            // und wuerde ihn sonst teilweise abziehen.
            return integrieren((Self.betrag(m.beschleunigung) - 1) * 9.81)
        }
    }

    private mutating func integrieren(_ linear: Double) -> Double {
        geschwindigkeit = geschwindigkeit * (1 - dt / profil.leckZeit) + linear * dt
        return geschwindigkeit
    }

    // MARK: - Achse aus der ersten Wiederholung

    /// Alle drei Achsen laufen, bis eine einen Kandidaten liefert, der die
    /// Pruefungen besteht. Das Intervall gilt dann als erste Wiederholung;
    /// die Achse ist die mit der groessten Streuung darin, nicht unbedingt
    /// die, deren Spur ausgeloest hat (bei Curls schwingt eine Nebenachse
    /// mit und kann zuerst fertig sein).
    private mutating func parallelSchritt(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        guard var alle = spuren else { return [] }
        var treffer: Kandidat?
        for i in alle.indices {
            let k = halbwelle(m, roh: Self.komponente(m.drehrate, i), spur: &alle[i])
            if treffer == nil { treffer = k }
        }
        spuren = alle
        guard let k = treffer else { return [] }
        let intervall = verlauf.filter { $0.t >= k.beginn && $0.t <= k.ende }
        let a = Self.achseGroessterStreuung(intervall.map(\.drehrate))
        // Richtung aus dem Hinweg der gewaehlten Achse; Ausschlag roh, weil
        // ihre Spur den Kandidaten nicht selbst erkannt haben muss.
        let hinweg = intervall.filter { $0.t <= k.umkehr }.reduce(0) { $0 + Self.komponente($1.drehrate, a) }
        let spitze = intervall.map { abs(Self.komponente($0.drehrate, a)) }.max() ?? k.spitze
        achse = a
        spuren = nil
        spur = alle[a]
        spur.vorzeichen = hinweg > 0 ? 1 : -1
        spur.zustand = .wartet
        spur.hinwegBegonnen = true
        return zaehlen(Kandidat(beginn: k.beginn, umkehr: k.umkehr, ende: k.ende, spitze: spitze))
    }

    // MARK: - Halbwellen

    private mutating func schritt(_ m: SensorMesswert, roh: Double) -> [ZaehlerEreignis] {
        // Ueber eine Kopie, weil halbwelle self liest, waehrend die Spur
        // geaendert wird (exklusiver Zugriff).
        var s = spur
        let kandidat = halbwelle(m, roh: roh, spur: &s)
        spur = s
        guard let kandidat else { return [] }
        return zaehlen(kandidat)
    }

    /// Fuehrt eine Spur um einen Messwert weiter und gibt einen
    /// abgeschlossenen Kandidaten zurueck, der die Pruefungen besteht.
    private func halbwelle(_ m: SensorMesswert, roh: Double, spur s: inout Spur) -> Kandidat? {
        // Mit dem ersten Wert starten statt mit 0, damit ein Gleichanteil
        // kein Einschwingen erzeugt, das wie Bewegung aussieht.
        let f = (s.gefiltert ?? roh) + alpha * (roh - (s.gefiltert ?? roh))
        s.gefiltert = f
        // Beim Betrag keine Grundlinie: die leckende Integration hat keinen
        // Gleichanteil, und ein langsamer Hub zu Satzbeginn gilt als ruhig.
        // Die Grundlinie nahm ihn am 14.10. mit 0,1 bis 0,2 m/s auf, danach
        // erreichten die Hubphasen die Schwelle nicht mehr.
        if profil.signal != .geschwindigkeitBetrag, !s.hinwegBegonnen, ruhig(m) {
            // Nur aus ruhigen Messwerten: beginnt die Aufnahme mitten in der
            // Bewegung, laege die Grundlinie sonst auf einem Bewegungswert.
            // Zeitkonstante rund 0,5 s: folgt dem Ruhewert, ohne dass die
            // kurzen ruhigen Momente zu Bewegungsbeginn ihn verschieben.
            let k = dt / (0.5 + dt)
            s.grundlinie = s.grundlinie.map { $0 + k * (f - $0) } ?? f
        }
        // Ohne Ruhe vor der ersten Halbwelle gibt es keinen Gleichanteil zu
        // schaetzen; dann gilt null wie ohne Grundlinie.
        let wert = f - (s.grundlinie ?? 0)
        // "Nulldurchgang" ist der letzte Moment nahe null: ein echter
        // Vorzeichenwechsel oder ein Wert im Band um null. Ohne das Band
        // bliebe er in reiner Ruhe (Wert exakt 0) beim ersten Messwert stehen,
        // und die erste Wiederholung begaenne mit dem Ruhevorlauf.
        let wechsel = wert != 0 && s.letztesS != 0 && (wert > 0) != (s.letztesS > 0)
        if s.nulldurchgang == nil || wechsel || abs(wert) < 0.1 * s.schwelle { s.nulldurchgang = m.t }
        defer { if wert != 0 { s.letztesS = wert } }

        switch s.zustand {
        case .wartet:
            guard abs(wert) > s.schwelle else { return nil }
            let richtung: Double = wert > 0 ? 1 : -1
            if s.vorzeichen == nil { s.vorzeichen = richtung }
            // Die erste Halbwelle ueber der Schwelle legt die Richtung fest,
            // auch wenn sie ein Ausholen ist. Danach zaehlen nur Halbwellen in
            // dieser Richtung als Hinweg. Grenze: holt der Sportler weit
            // genug aus, gilt das Ausholen als Hinweg und die Phasen der
            // Wiederholungen sind vertauscht.
            guard richtung == s.vorzeichen else { return nil }
            s.hinwegBegonnen = true
            s.zustand = .erste(beginn: s.nulldurchgang ?? m.t, spitze: abs(wert))
            return nil

        case .erste(let beginn, let spitze):
            if m.t - beginn > profil.hoechstDauer { s.zustand = .wartet; return nil }
            let vz = s.vorzeichen ?? 1
            if wert * vz < -s.schwelle {
                s.zustand = .zweite(beginn: beginn, umkehr: s.nulldurchgang ?? m.t, spitze: max(spitze, abs(wert)))
            } else {
                s.zustand = .erste(beginn: beginn, spitze: max(spitze, abs(wert)))
            }
            return nil

        case .zweite(let beginn, let umkehr, let spitze):
            if m.t - beginn > profil.hoechstDauer { s.zustand = .wartet; return nil }
            let vz = s.vorzeichen ?? 1
            let neueSpitze = max(spitze, abs(wert))
            // Abgeschlossen, sobald der Rueckweg fast zur Ruhe gekommen ist.
            guard wert * vz > -s.schwelle / 2 else {
                s.zustand = .zweite(beginn: beginn, umkehr: umkehr, spitze: neueSpitze)
                return nil
            }
            s.zustand = .wartet
            return pruefen(Kandidat(beginn: beginn, umkehr: umkehr, ende: m.t, spitze: neueSpitze), spur: &s)
        }
    }

    /// Dauer, Lage und (vor der ersten Wiederholung) Stoss. Ein verworfener
    /// Kandidat ist kein Zweifel am Satz: er wird still uebergangen.
    private func pruefen(_ k: Kandidat, spur s: inout Spur) -> Kandidat? {
        // Zu kurz ist ein Wackler, keine Wiederholung -- verwerfen, nicht zweifeln.
        guard k.ende - k.beginn >= profil.mindestDauer, k.umkehr > k.beginn, k.ende > k.umkehr else { return nil }
        let vorDerErsten = wiederholungen.isEmpty
        var verwerfen = false
        if let hoechstens = profil.lageHoechstens {
            verwerfen = lage(bei: k.beginn).winkelGrad(zu: lage(bei: k.ende)) > hoechstens
        }
        if vorDerErsten, !verwerfen, let stoss = profil.stossAb {
            verwerfen = verlauf.contains { $0.t >= k.beginn - 0.5 && $0.t <= k.ende && $0.beschleunigung > stoss }
        }
        guard verwerfen else { return k }
        if vorDerErsten {
            // Aufnehmen legt weder Richtung noch Schwelle fest: die naechste
            // Halbwelle ueber der Startschwelle entscheidet neu.
            s.vorzeichen = nil
            s.schwelle = profil.startSchwelle
        }
        return nil
    }

    private mutating func zaehlen(_ k: Kandidat) -> [ZaehlerEreignis] {
        let dauer = k.ende - k.beginn
        if wiederholungen.count >= 2 {
            let spitzen = wiederholungen.map(\.ausschlag).sorted()
            let dauern = wiederholungen.map { $0.ende - $0.beginn }.sorted()
            let medianSpitze = spitzen[spitzen.count / 2]
            let medianDauer = dauern[dauern.count / 2]
            if k.spitze < profil.schwachAnteil * medianSpitze { return stoppen(.signalSchwach) }
            if dauer > profil.taktBand * medianDauer || dauer < medianDauer / profil.taktBand {
                return stoppen(.taktUnregelmaessig)
            }
        }
        let sicherheit = min(1, max(0, (k.spitze - spur.schwelle) / spur.schwelle))
        let wiederholung = Wiederholung(
            nummer: wiederholungen.count + 1, beginn: k.beginn, umkehr: k.umkehr, ende: k.ende,
            ausschlag: k.spitze, sicherheit: sicherheit,
            pauseDavor: wiederholungen.last.map { max(0, k.beginn - $0.ende) })
        wiederholungen.append(wiederholung)
        if wiederholungen.count == 1 {
            spur.schwelle = max(profil.startSchwelle, profil.schwellenAnteil * k.spitze)
        }
        return [.wiederholung(wiederholung)]
    }

    private mutating func stoppen(_ grund: UnsicherGrund) -> [ZaehlerEreignis] {
        gestoppt = true
        return [.unsicher(grund)]
    }
}

/// Einheitsquaternion fuer die Lage aus der Drehrate.
struct Quaternion: Sendable, Equatable {
    var w, x, y, z: Double

    static let eins = Quaternion(w: 1, x: 0, y: 0, z: 0)

    /// Dreht um den Vektor (x, y, z) im Sensorsystem, in Radiant; danach
    /// normiert, damit sich Rundungsfehler ueber einen Satz nicht aufbauen.
    func gedreht(x dx: Double, y dy: Double, z dz: Double) -> Quaternion {
        let winkel = (dx * dx + dy * dy + dz * dz).squareRoot()
        guard winkel > 0 else { return self }
        let s = sin(winkel / 2) / winkel
        let d = Quaternion(w: cos(winkel / 2), x: dx * s, y: dy * s, z: dz * s)
        let p = Quaternion(w: w * d.w - x * d.x - y * d.y - z * d.z,
                           x: w * d.x + x * d.w + y * d.z - z * d.y,
                           y: w * d.y - x * d.z + y * d.w + z * d.x,
                           z: w * d.z + x * d.y - y * d.x + z * d.w)
        let n = (p.w * p.w + p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
        return Quaternion(w: p.w / n, x: p.x / n, y: p.y / n, z: p.z / n)
    }

    /// Drehwinkel zwischen zwei Lagen in Grad.
    func winkelGrad(zu o: Quaternion) -> Double {
        let d = abs(w * o.w + x * o.x + y * o.y + z * o.z)
        return 2 * acos(min(1, d)) * 180 / .pi
    }
}
