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

    /// Ein Stueck eines frei gebauten Verlaufs; die Funktionen bekommen die
    /// Zeit seit Beginn des Stuecks. Fuer Aufnehmen, Ablegen und Stoesse, die
    /// `satz` nicht abbilden kann.
    struct Stueck {
        var dauer: Double
        var drehrate: (Double) -> Vektor3 = { _ in Vektor3(x: 0, y: 0, z: 0) }
        var beschleunigung: (Double) -> Vektor3 = { _ in Vektor3(x: 0, y: 0, z: 1) }

        static func ruhe(_ dauer: Double) -> Stueck { Stueck(dauer: dauer) }

        /// Curls um y: volle Sinuswellen mit 200 Grad/s Spitze, je Welle
        /// zurueck in die Ausgangslage.
        static func curls(_ anzahl: Int, periode: Double = 2) -> Stueck {
            Stueck(dauer: Double(anzahl) * periode,
                   drehrate: { u in Vektor3(x: 0, y: 200 * sin(2 * .pi * u / periode), z: 0) })
        }

        /// Schwung, der die Lage aendert wie Aufnehmen oder Ablegen: 0,8 s
        /// hin mit 400 Grad/s Spitze, 0,5 s zurueck mit 150 Grad/s. Netto
        /// bleiben rund 156 Grad Drehung um die Achse (0 = x, 1 = y, 2 = z).
        static func lagewechsel(achse: Int) -> Stueck {
            Stueck(dauer: 1.3, drehrate: { u in
                let w = u < 0.8 ? 400 * sin(.pi * u / 0.8) : -150 * sin(.pi * (u - 0.8) / 0.5)
                return Vektor3(x: achse == 0 ? w : 0, y: achse == 1 ? w : 0, z: achse == 2 ? w : 0)
            })
        }
    }

    static func folge(_ stuecke: [Stueck], rate: Double = 50, buendel: Int = 2) -> [SensorMesswert] {
        let dt = 1 / rate
        var werte: [SensorMesswert] = []
        var i = 0
        for stueck in stuecke {
            let n = Int((stueck.dauer * rate).rounded())
            for k in 0..<n {
                let u = Double(k) * dt
                werte.append(SensorMesswert(t: Double(i / buendel * buendel) * dt,
                                            beschleunigung: stueck.beschleunigung(u),
                                            drehrate: stueck.drehrate(u), winkel: Vektor3(x: 0, y: 0, z: 0)))
                i += 1
            }
        }
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
