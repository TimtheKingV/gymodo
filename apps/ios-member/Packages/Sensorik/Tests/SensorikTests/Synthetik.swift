import Foundation
@testable import Sensorik

/// Kuenstliche Saetze mit bekannter Wahrheit. Die Zeitstempel sind wie am
/// iPhone gebuendelt (Spec A 4.7): `buendel` Messwerte teilen sich einen t.
enum Synthetik {
    struct Abschnitt {
        var perioden: Int
        var periode: Double = 2.0
        var amplitude: Double = 1.0 // Anteil der Grundamplitude
    }

    static func satz(signal: ZaehlerProfil.Signal, abschnitte: [Abschnitt],
                     ruheVorher: Double = 3, ruheNachher: Double = 2,
                     rate: Double = 50, buendel: Int = 2,
                     rauschenGradProS: Double = 0,
                     luecke: (ab: Double, dauer: Double)? = nil) -> [SensorMesswert] {
        let dt = 1 / rate
        var werte: [SensorMesswert] = []
        var i = 0
        func ablegen(_ wert: Double) {
            // Zeitstempel des Buendels: der erste Messwert des Buendels gibt ihn vor.
            let bundleT = Double(i / buendel * buendel) * dt
            if let luecke, bundleT >= luecke.ab, bundleT < luecke.ab + luecke.dauer { i += 1; return }
            let stoerung = rauschenGradProS * sin(2 * .pi * 7 * Double(i) * dt)
            switch signal {
            case .drehrate:
                werte.append(SensorMesswert(
                    t: bundleT, beschleunigung: Vektor3(x: 0, y: 0, z: 1),
                    drehrate: Vektor3(x: 0, y: 200 * wert + stoerung, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0)))
            case .geschwindigkeitVertikal, .geschwindigkeitBetrag:
                // wert ist hier die Beschleunigung in m/s^2 entlang z.
                werte.append(SensorMesswert(
                    t: bundleT, beschleunigung: Vektor3(x: 0, y: 0, z: 1 + wert / 9.81),
                    drehrate: Vektor3(x: stoerung, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0)))
            }
            i += 1
        }
        let ruheSamples = { (dauer: Double) in Int((dauer * rate).rounded()) }
        for _ in 0..<ruheSamples(ruheVorher) { ablegen(0) }
        for abschnitt in abschnitte {
            let n = Int((Double(abschnitt.perioden) * abschnitt.periode * rate).rounded())
            for k in 0..<n {
                let phase = 2 * .pi * Double(k) * dt / abschnitt.periode
                switch signal {
                case .drehrate:
                    ablegen(abschnitt.amplitude * sin(phase))
                case .geschwindigkeitVertikal, .geschwindigkeitBetrag:
                    // v = 0,4 m/s * sin -> a = dv/dt
                    let v0 = 0.4 * abschnitt.amplitude
                    ablegen(v0 * 2 * .pi / abschnitt.periode * cos(phase))
                }
            }
        }
        for _ in 0..<ruheSamples(ruheNachher) { ablegen(0) }
        return werte
    }

    static func zaehlen(_ werte: [SensorMesswert], art: Befestigungsart, rate: Double = 50) -> [ZaehlerEreignis] {
        var zaehler = Zaehler(profil: .fuer(art), rateHz: rate)
        var ereignisse: [ZaehlerEreignis] = []
        for m in werte { ereignisse += zaehler.verarbeite(m) }
        ereignisse += zaehler.abschliessen()
        return ereignisse
    }

    static func anzahl(_ ereignisse: [ZaehlerEreignis]) -> Int {
        ereignisse.filter { if case .wiederholung = $0 { true } else { false } }.count
    }
}

// MARK: - Drehsaetze fuer die Winkellage

extension Synthetik {
    /// Ein Wegstueck: die Lage laeuft als Kosinus-Flanke von `von` nach `nach`.
    /// Mit `von == nach` steht die Last still.
    fileprivate struct Wegstueck { let dauer: Double; let von: Double; let nach: Double }

    /// Kuenstlicher Satz einer drehenden Last mit der wahren Lage je Messwert (0 = Ruhelage, 1 = oben).
    /// `losT`: ein Zeitpunkt 0,5 s vor der ersten Wiederholung, an dem die Last in der Ruhelage des Satzes steht.
    struct Drehsatz { let werte: [SensorMesswert]; let lage: [Double]; let losT: Double }

    /// Vorbewegung vor dem Satz (Aufnehmen der Hantel): aus der Startrichtung um `hinGrad` hin, dann zurueck
    /// auf `ruheGrad`, je in `dauer` s; davor `ruheDavor` s Ruhe. Die Ruhelage des Satzes liegt danach `ruheGrad`
    /// neben der Startrichtung, die Wahrheit ist in der Vorbewegung 0.
    struct Vorbewegung { var hinGrad = 60.0; var ruheGrad = 25.0; var dauer = 1.0; var ruheDavor = 2.0 }

    /// Die Schwerkraftrichtung im Sensorrahmen startet bei `startRoll`/`startPitch`
    /// (ĝ = (−sin p, sin r · cos p, cos r · cos p)) und dreht mit dem Drehwinkel α um `drehachse`
    /// (im Sensorrahmen; der Sensor dreht um +α, die Schwerkraft in seinem Rahmen um −α).
    /// α = Vorbewegung + `hubGrad · lage` + Zittern; ausgegeben werden `roll = atan2(ĝ.y, ĝ.z)` und
    /// `pitch = asin(−ĝ.x)` in Grad, also mit allen Euler-Spruengen (Roll ±180°, Pitch ±90°).
    /// Die Lage folgt Kosinus-Flanken (`Wegstueck`). Die Drehrate ist die Ableitung der ausgegebenen
    /// Roll- und Pitch-Winkel (ueber ±180° gefaltet), auf z liegt ein kleines Zittern von 9 Hz;
    /// die Beschleunigung ist (0, 0, 1). `pauseNach[n]` haelt nach der n-ten Wiederholung unten an,
    /// `hubAnteil[n]` skaliert deren Hub. `zitternGrad` legt in Ruhe und Pausen ein Sinus-Zittern (7 Hz)
    /// auf α. Mit `ruheVorher: 0` beginnt der Satz mitten in der Bewegung.
    static func drehsatz(wiederholungen: Int, kraftweg: Double = 1.5, ablassen: Double = 2.5,
                         hubGrad: Double = 140, hubAnteil: [Int: Double] = [:],
                         drehachse: Vektor3 = Vektor3(x: 1, y: 0, z: 0), startRoll: Double = 0, startPitch: Double = 0,
                         vorbewegung: Vorbewegung? = nil,
                         pauseNach: [Int: Double] = [:], zitternGrad: Double = 0,
                         ruheVorher: Double = 3, ruheNachher: Double = 2,
                         rate: Double = 50, buendel: Int = 2,
                         luecke: (ab: Double, dauer: Double)? = nil) -> Drehsatz {
        let vorDauer = vorbewegung.map { $0.ruheDavor + 2 * $0.dauer } ?? 0
        var stuecke = [Wegstueck(dauer: vorDauer + ruheVorher, von: 0, nach: 0)]
        for n in stride(from: 1, through: wiederholungen, by: 1) {
            let anteil = hubAnteil[n] ?? 1
            stuecke.append(Wegstueck(dauer: kraftweg, von: 0, nach: anteil))
            stuecke.append(Wegstueck(dauer: ablassen, von: anteil, nach: 0))
            if let pause = pauseNach[n] { stuecke.append(Wegstueck(dauer: pause, von: 0, nach: 0)) }
        }
        stuecke.append(Wegstueck(dauer: ruheNachher, von: 0, nach: 0))

        /// Wahre Lage und Zittergewicht: 0 in der Bewegung, in Ruhe und Pausen blendet es
        /// ueber 0,25 s ein und aus, damit das Zittern nirgends springt.
        func zustand(_ t: Double) -> (lage: Double, zittern: Double) {
            var beginn = 0.0
            for s in stuecke {
                if t < beginn + s.dauer, s.dauer > 0 {
                    let w = Double.pi * max(t - beginn, 0) / s.dauer
                    let lage = s.von + (s.nach - s.von) * (1 - cos(w)) / 2
                    let gewicht = s.von == s.nach ? min(1, (t - beginn) / 0.25, (beginn + s.dauer - t) / 0.25) : 0
                    return (lage, max(gewicht, 0))
                }
                beginn += s.dauer
            }
            return (0, 0)
        }
        /// Drehwinkel der Vorbewegung (Kosinus-Flanken), danach `ruheGrad`.
        func vor(_ t: Double) -> Double {
            guard let v = vorbewegung else { return 0 }
            func flanke(_ tau: Double) -> Double { (1 - cos(Double.pi * min(max(tau, 0), 1))) / 2 }
            if t < v.ruheDavor + v.dauer { return v.hinGrad * flanke((t - v.ruheDavor) / v.dauer) }
            return v.hinGrad + (v.ruheGrad - v.hinGrad) * flanke((t - v.ruheDavor - v.dauer) / v.dauer)
        }
        /// Drehwinkel α inklusive Vorbewegung und Zittern, in Grad.
        func alpha(_ t: Double) -> Double {
            let z = zustand(t)
            // In der Vorbewegung zittert nichts, damit sie ihre Form behaelt.
            let zittern = t < vorDauer ? 0 : z.zittern * zitternGrad * sin(2 * .pi * 7 * t)
            return vor(t) + hubGrad * z.lage + zittern
        }
        let r0 = startRoll * .pi / 180, p0 = startPitch * .pi / 180
        let start = Vektor3(x: -sin(p0), y: sin(r0) * cos(p0), z: cos(r0) * cos(p0))
        let betrag = (drehachse.x * drehachse.x + drehachse.y * drehachse.y + drehachse.z * drehachse.z).squareRoot()
        let k = Vektor3(x: drehachse.x / betrag, y: drehachse.y / betrag, z: drehachse.z / betrag)
        /// Roll und Pitch in Grad zur Zeit t: ĝ = Drehung von `start` um k mit −α (Rodrigues).
        func eulerwinkel(_ t: Double) -> (roll: Double, pitch: Double) {
            let a = -alpha(t) * .pi / 180, c = cos(a), s = sin(a), v = start
            let kxv = Vektor3(x: k.y * v.z - k.z * v.y, y: k.z * v.x - k.x * v.z, z: k.x * v.y - k.y * v.x)
            let kv = k.x * v.x + k.y * v.y + k.z * v.z
            let g = Vektor3(x: v.x * c + kxv.x * s + k.x * kv * (1 - c),
                            y: v.y * c + kxv.y * s + k.y * kv * (1 - c),
                            z: v.z * c + kxv.z * s + k.z * kv * (1 - c))
            return (atan2(g.y, g.z) * 180 / .pi, asin(min(max(-g.x, -1), 1)) * 180 / .pi)
        }
        func falte(_ grad: Double) -> Double {
            var x = grad.truncatingRemainder(dividingBy: 360)
            if x > 180 { x -= 360 } else if x < -180 { x += 360 }
            return x
        }
        let dt = 1 / rate
        let gesamtDauer = stuecke.reduce(0) { $0 + $1.dauer }
        var werte: [SensorMesswert] = []
        var lage: [Double] = []
        for i in 0..<Int((gesamtDauer * rate).rounded()) {
            let t = Double(i) * dt
            let bundleT = Double(i / buendel * buendel) * dt
            if let luecke, bundleT >= luecke.ab, bundleT < luecke.ab + luecke.dauer { continue }
            let jetzt = eulerwinkel(t), davor = eulerwinkel(t - dt), danach = eulerwinkel(t + dt)
            let drehrate = Vektor3(x: falte(danach.roll - davor.roll) / (2 * dt),
                                   y: falte(danach.pitch - davor.pitch) / (2 * dt),
                                   z: 8 * sin(2 * .pi * 9 * t + 2))
            werte.append(SensorMesswert(t: bundleT, beschleunigung: Vektor3(x: 0, y: 0, z: 1),
                                        drehrate: drehrate, winkel: Vektor3(x: jetzt.roll, y: jetzt.pitch, z: 0)))
            lage.append(zustand(t).lage)
        }
        return Drehsatz(werte: werte, lage: lage, losT: vorDauer + ruheVorher - 0.5)
    }
}
