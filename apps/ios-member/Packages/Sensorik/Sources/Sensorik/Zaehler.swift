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
    private var gefiltert = 0.0

    // Halbwellen
    private var zustand: Halbwelle = .wartet
    private var vorzeichen: Double?
    private var schwelle: Double
    private var letztesS = 0.0
    private var nulldurchgang: TimeInterval?

    public init(profil: ZaehlerProfil, rateHz: Double = 50) {
        self.profil = profil
        dt = 1 / rateHz
        let rc = 1 / (2 * .pi * profil.tiefpassHz)
        alpha = dt / (rc + dt)
        schwelle = profil.startSchwelle
        if profil.signal == .geschwindigkeitVertikal { achse = -1 } // braucht keine Achsensuche
    }

    public var anzahl: Int { wiederholungen.count }

    public mutating func verarbeite(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        guard !gestoppt else { return [] }
        defer { letzteT = m.t }
        if let letzteT, m.t - letzteT > profil.lueckeAb {
            return stoppen(.luecke)
        }
        schwerkraftNachfuehren(m)

        guard achse != nil else {
            return achseSuchen(m)
        }
        return schritt(m)
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

    /// Nur fuer Drehraten-Profile: sammeln, bis die erste Bewegung lang
    /// genug ist, dann die Achse mit der groessten Streuung waehlen und den
    /// Puffer nachspielen, damit die erste Wiederholung nicht verloren geht.
    private mutating func achseSuchen(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        puffer.append(m)
        let bewegt = Self.betrag(m.drehrate) > 3 * profil.ruheDrehrate
        if bewegtSeit == nil, bewegt { bewegtSeit = m.t }
        guard let seit = bewegtSeit else {
            // Ruhevorlauf: nur die letzte Sekunde behalten.
            puffer.removeAll { m.t - $0.t > 1 }
            return []
        }
        guard m.t - seit >= profil.achsenFenster else { return [] }
        let bewegung = puffer.filter { $0.t >= seit }
        func streuung(_ wert: (SensorMesswert) -> Double) -> Double {
            let werte = bewegung.map(wert)
            let mittel = werte.reduce(0, +) / Double(werte.count)
            return werte.reduce(0) { $0 + ($1 - mittel) * ($1 - mittel) }
        }
        let streuungen = [streuung { $0.drehrate.x }, streuung { $0.drehrate.y }, streuung { $0.drehrate.z }]
        achse = streuungen.indices.max { streuungen[$0] < streuungen[$1] }
        let nachspielen = puffer
        puffer = []
        var ereignisse: [ZaehlerEreignis] = []
        for alt in nachspielen { ereignisse += schritt(alt) }
        return ereignisse
    }

    private mutating func rohsignal(_ m: SensorMesswert) -> Double {
        switch profil.signal {
        case .drehrate:
            switch achse {
            case 0: return m.drehrate.x
            case 1: return m.drehrate.y
            default: return m.drehrate.z
            }
        case .geschwindigkeitVertikal:
            let g = schwerkraft ?? Vektor3(x: 0, y: 0, z: 1)
            let gBetrag = max(Self.betrag(g), 0.0001)
            let entlang = (m.beschleunigung.x * g.x + m.beschleunigung.y * g.y + m.beschleunigung.z * g.z) / gBetrag
            let linear = (entlang - gBetrag) * 9.81
            geschwindigkeit = geschwindigkeit * (1 - dt / profil.leckZeit) + linear * dt
            return geschwindigkeit
        }
    }

    // MARK: - Halbwellen

    private mutating func schritt(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        gefiltert += alpha * (rohsignal(m) - gefiltert)
        let s = gefiltert
        // "Nulldurchgang" ist der letzte Moment nahe null: ein echter
        // Vorzeichenwechsel oder ein Wert im Band um null. Ohne das Band
        // bliebe er in reiner Ruhe (s exakt 0) beim ersten Messwert stehen,
        // und die erste Wiederholung begaenne mit dem Ruhevorlauf.
        let wechsel = s != 0 && letztesS != 0 && (s > 0) != (letztesS > 0)
        if nulldurchgang == nil || wechsel || abs(s) < 0.1 * schwelle { nulldurchgang = m.t }
        defer { if s != 0 { letztesS = s } }

        switch zustand {
        case .wartet:
            guard abs(s) > schwelle else { return [] }
            let richtung: Double = s > 0 ? 1 : -1
            if vorzeichen == nil { vorzeichen = richtung }
            // Eine Gegenbewegung vor dem ersten Hinweg (z. B. Ausholen) zaehlt nicht.
            guard richtung == vorzeichen else { return [] }
            zustand = .erste(beginn: nulldurchgang ?? m.t, spitze: abs(s))
            return []

        case .erste(let beginn, let spitze):
            if m.t - beginn > profil.hoechstDauer { zustand = .wartet; return [] }
            let vz = vorzeichen ?? 1
            if s * vz < -schwelle {
                zustand = .zweite(beginn: beginn, umkehr: nulldurchgang ?? m.t, spitze: max(spitze, abs(s)))
            } else {
                zustand = .erste(beginn: beginn, spitze: max(spitze, abs(s)))
            }
            return []

        case .zweite(let beginn, let umkehr, let spitze):
            if m.t - beginn > profil.hoechstDauer { zustand = .wartet; return [] }
            let vz = vorzeichen ?? 1
            let neueSpitze = max(spitze, abs(s))
            // Abgeschlossen, sobald der Rueckweg fast zur Ruhe gekommen ist.
            guard s * vz > -schwelle / 2 else {
                zustand = .zweite(beginn: beginn, umkehr: umkehr, spitze: neueSpitze)
                return []
            }
            zustand = .wartet
            return abschliessenWiederholung(beginn: beginn, umkehr: umkehr, ende: m.t, spitze: neueSpitze)
        }
    }

    private mutating func abschliessenWiederholung(beginn: TimeInterval, umkehr: TimeInterval,
                                                    ende: TimeInterval, spitze: Double) -> [ZaehlerEreignis] {
        let dauer = ende - beginn
        // Zu kurz ist ein Wackler, keine Wiederholung -- verwerfen, nicht zweifeln.
        guard dauer >= profil.mindestDauer, umkehr > beginn, ende > umkehr else { return [] }
        if wiederholungen.count >= 2 {
            let spitzen = wiederholungen.map(\.ausschlag).sorted()
            let dauern = wiederholungen.map { $0.ende - $0.beginn }.sorted()
            let medianSpitze = spitzen[spitzen.count / 2]
            let medianDauer = dauern[dauern.count / 2]
            if spitze < profil.schwachAnteil * medianSpitze { return stoppen(.signalSchwach) }
            if dauer > profil.taktBand * medianDauer || dauer < medianDauer / profil.taktBand {
                return stoppen(.taktUnregelmaessig)
            }
        }
        let sicherheit = min(1, max(0, (spitze - schwelle) / schwelle))
        let wiederholung = Wiederholung(
            nummer: wiederholungen.count + 1, beginn: beginn, umkehr: umkehr, ende: ende,
            ausschlag: spitze, sicherheit: sicherheit,
            pauseDavor: wiederholungen.last.map { max(0, beginn - $0.ende) })
        wiederholungen.append(wiederholung)
        if wiederholungen.count == 1 {
            schwelle = max(profil.startSchwelle, profil.schwellenAnteil * spitze)
        }
        return [.wiederholung(wiederholung)]
    }

    private mutating func stoppen(_ grund: UnsicherGrund) -> [ZaehlerEreignis] {
        gestoppt = true
        return [.unsicher(grund)]
    }
}
