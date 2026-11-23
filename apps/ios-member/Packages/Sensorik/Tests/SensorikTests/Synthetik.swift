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

// MARK: - Hubsaetze fuer den Lageschaetzer

extension Synthetik {
    /// Kuenstlicher Satz mit der wahren Lage je Messwert (0 = Ruhelage unten, 1 = oben).
    struct Hubsatz { let werte: [SensorMesswert]; let lage: [Double] }

    /// Ein Wegstueck: die Lage laeuft als Kosinus-Flanke von `von` nach `nach`.
    /// Mit `von == nach` steht die Last still.
    fileprivate struct Wegstueck { let dauer: Double; let von: Double; let nach: Double }

    /// Die Schwerkraft liegt immer auf z (1 g). Die Position folgt Kosinus-Flanken
    /// (`(1 − cos(π·τ/dauer))/2`), die Beschleunigung ist deren zweite Ableitung
    /// (als zweite Differenz abgetastet),
    /// in g entlang `achse` addiert. `hubAnteil[n]` skaliert den Hub der n-ten
    /// Wiederholung (1-basiert). `lage` ist auf `hubMeter` normiert.
    /// `halt` haelt die Last auf dem Kraftweg der genannten Wiederholung bei
    /// `beiLage` an, `biasG` ist ein Gleichanteil entlang `achse`, der mit der
    /// ersten Wiederholung einsetzt (in der Ruhe davor wuerde ihn die
    /// Schwerkraftschaetzung schlucken), `stoss` eine Spitze von 40 ms auf z.
    /// `pausenUnten[n]` laesst die Last nach der n-ten Wiederholung so viele
    /// Sekunden in der Ruhelage stehen.
    /// `drehungGrad` kippt die Last mit der Lage um die x-Achse (Kippwinkel
    /// `drehungGrad · lage`, also je Wiederholung hin und zurueck), wie eine Hantel,
    /// die sich im Satz dreht; der Sensor sitzt im Drehpunkt. Beschleunigung,
    /// Drehrate (um x) und Winkel (Roll) werden dazu stimmig erzeugt: Im
    /// Sensorrahmen zeigt die Schwerkraft dann nach (0, sin θ, cos θ).
    static func hub(wiederholungen: Int, kraftweg: Double = 1.5, ablassen: Double = 2.5,
                    hubMeter: Double = 0.4, hubAnteil: [Int: Double] = [:],
                    startetOben: Bool = false, achse: Vektor3 = Vektor3(x: 0, y: 0, z: 1),
                    halt: (wiederholung: Int, beiLage: Double, dauer: Double)? = nil,
                    biasG: Double = 0, stoss: (bei: Double, g: Double)? = nil,
                    ruheVorher: Double = 3, ruheNachher: Double = 2,
                    rate: Double = 50, buendel: Int = 2,
                    luecke: (ab: Double, dauer: Double)? = nil,
                    pausenUnten: [Int: Double] = [:], drehungGrad: Double = 0) -> Hubsatz {
        let ruhelage: Double = startetOben ? 1 : 0
        var stuecke = [Wegstueck(dauer: ruheVorher, von: ruhelage, nach: ruhelage)]
        for n in stride(from: 1, through: wiederholungen, by: 1) {
            let anteil = hubAnteil[n] ?? 1
            let unten = startetOben ? 1 - anteil : 0
            let oben = unten + anteil
            var aufwaerts = [Wegstueck(dauer: kraftweg, von: unten, nach: oben)]
            if let halt, halt.wiederholung == n, halt.beiLage > unten, halt.beiLage < oben {
                let vorher = (halt.beiLage - unten) / anteil
                aufwaerts = [Wegstueck(dauer: kraftweg * vorher, von: unten, nach: halt.beiLage),
                             Wegstueck(dauer: halt.dauer, von: halt.beiLage, nach: halt.beiLage),
                             Wegstueck(dauer: kraftweg * (1 - vorher), von: halt.beiLage, nach: oben)]
            }
            let abwaerts = Wegstueck(dauer: ablassen, von: oben, nach: unten)
            stuecke += startetOben ? [abwaerts] + aufwaerts : aufwaerts + [abwaerts]
            if let pause = pausenUnten[n] { stuecke.append(Wegstueck(dauer: pause, von: ruhelage, nach: ruhelage)) }
        }
        stuecke.append(Wegstueck(dauer: ruheNachher, von: ruhelage, nach: ruhelage))

        let betrag = (achse.x * achse.x + achse.y * achse.y + achse.z * achse.z).squareRoot()
        let richtung = Vektor3(x: achse.x / betrag, y: achse.y / betrag, z: achse.z / betrag)
        let dt = 1 / rate
        let gesamtDauer = stuecke.reduce(0) { $0 + $1.dauer }
        func wahreLage(_ t: Double) -> Double {
            var beginn = 0.0
            for s in stuecke {
                if t < beginn + s.dauer, s.dauer > 0 {
                    let w = Double.pi * max(t - beginn, 0) / s.dauer
                    return s.von + (s.nach - s.von) * (1 - cos(w)) / 2
                }
                beginn += s.dauer
            }
            return ruhelage
        }
        var werte: [SensorMesswert] = []
        var lage: [Double] = []
        for i in 0..<Int((gesamtDauer * rate).rounded()) {
            let t = Double(i) * dt
            // Zweite Ableitung als zweite Differenz: an den Flankenwechseln springt
            // die Beschleunigung, abgetastet ergaebe sie sonst eine Scheindrift.
            // So ergibt die Summe der Beschleunigungen genau den wahren Weg.
            let beschleunigungMS2 = (wahreLage(t + dt) - 2 * wahreLage(t) + wahreLage(t - dt)) * hubMeter / (dt * dt)
            let entlang = beschleunigungMS2 / 9.81 + (t >= ruheVorher ? biasG : 0)
            var z = 1 + richtung.z * entlang
            if let stoss, t >= stoss.bei, t < stoss.bei + 0.04 { z += stoss.g }

            let bundleT = Double(i / buendel * buendel) * dt
            if let luecke, bundleT >= luecke.ab, bundleT < luecke.ab + luecke.dauer { continue }
            var beschleunigung = Vektor3(x: richtung.x * entlang, y: richtung.y * entlang, z: z)
            var drehrate = Vektor3(x: 0, y: 0, z: 0), winkel = Vektor3(x: 0, y: 0, z: 0)
            if drehungGrad != 0 {
                // Kippwinkel θ = drehungGrad · lage; Vektoren des ungekippten Rahmens
                // erscheinen im gekippten als (x, y cos θ + z sin θ, −y sin θ + z cos θ).
                let theta = drehungGrad * wahreLage(t) * .pi / 180
                let c = cos(theta), s = sin(theta)
                beschleunigung = Vektor3(x: beschleunigung.x, y: beschleunigung.y * c + beschleunigung.z * s,
                                         z: -beschleunigung.y * s + beschleunigung.z * c)
                // Drehrate um x = dθ/dt (zentrale Differenz), Roll = θ.
                drehrate = Vektor3(x: drehungGrad * (wahreLage(t + dt) - wahreLage(t - dt)) / (2 * dt), y: 0, z: 0)
                winkel = Vektor3(x: theta * 180 / .pi, y: 0, z: 0)
            }
            werte.append(SensorMesswert(t: bundleT, beschleunigung: beschleunigung, drehrate: drehrate, winkel: winkel))
            lage.append(wahreLage(t))
        }
        return Hubsatz(werte: werte, lage: lage)
    }
}

// MARK: - Drehsaetze fuer die Winkellage

extension Synthetik {
    /// Kuenstlicher Satz einer drehenden Last mit der wahren Lage je Messwert (0 = Ruhelage, 1 = oben).
    struct Drehsatz { let werte: [SensorMesswert]; let lage: [Double] }

    /// Winkel = `startGrad + vorzeichen · hubGrad · lage` auf `achse` (die andere bleibt 0), auf ±180° gefaltet;
    /// die Lage folgt Kosinus-Flanken wie bei `hub`. Die Drehrate ist die Ableitung auf derselben Achse,
    /// die Beschleunigung (0, 0, 1). `pauseNach[n]` haelt nach der n-ten Wiederholung unten an,
    /// `hubAnteil[n]` skaliert deren Hub. `zitternGrad` legt in Ruhe und Pausen ein Sinus-Zittern
    /// (7 Hz) auf den Winkel; die Drehrate ist die Ableitung des tatsaechlich ausgegebenen Winkels samt Zittern,
    /// auf den anderen Achsen liegt ein kleines Zittern von 9 Hz. Mit `ruheVorher: 0` beginnt der Satz mitten in der Bewegung.
    static func drehsatz(wiederholungen: Int, kraftweg: Double = 1.5, ablassen: Double = 2.5,
                         hubGrad: Double = 140, hubAnteil: [Int: Double] = [:],
                         achse: Winkelachse = .roll, vorzeichen: Int = 1, startGrad: Double = 0,
                         pauseNach: [Int: Double] = [:], zitternGrad: Double = 0,
                         ruheVorher: Double = 3, ruheNachher: Double = 2,
                         rate: Double = 50, buendel: Int = 2,
                         luecke: (ab: Double, dauer: Double)? = nil) -> Drehsatz {
        let richtung = Double(vorzeichen)
        var stuecke = [Wegstueck(dauer: ruheVorher, von: 0, nach: 0)]
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
        /// Entfalteter Winkel inklusive Zittern.
        func entfaltet(_ t: Double) -> Double {
            let z = zustand(t)
            return startGrad + richtung * hubGrad * z.lage + z.zittern * zitternGrad * sin(2 * .pi * 7 * t)
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
            let jetzt = zustand(t)
            let grad = falte(entfaltet(t))
            let rateGradProS = (entfaltet(t + dt) - entfaltet(t - dt)) / (2 * dt)
            func nebenzittern(_ k: Double) -> Double { 8 * sin(2 * .pi * 9 * t + k) }
            let winkel = achse == .roll ? Vektor3(x: grad, y: 0, z: 0) : Vektor3(x: 0, y: grad, z: 0)
            let drehrate = achse == .roll
                ? Vektor3(x: rateGradProS, y: nebenzittern(1), z: nebenzittern(2))
                : Vektor3(x: nebenzittern(1), y: rateGradProS, z: nebenzittern(2))
            werte.append(SensorMesswert(t: bundleT, beschleunigung: Vektor3(x: 0, y: 0, z: 1),
                                        drehrate: drehrate, winkel: winkel))
            lage.append(jetzt.lage)
        }
        return Drehsatz(werte: werte, lage: lage)
    }
}
