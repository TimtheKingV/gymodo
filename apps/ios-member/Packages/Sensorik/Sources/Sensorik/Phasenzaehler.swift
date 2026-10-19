import Foundation

/// Zaehlung ueber den ganzen Satz aus zwei gegenueberliegenden Geschwindigkeits-
/// phasen: Beschleunigung auf der Hauptachse, grob zur Geschwindigkeit
/// integriert, jede Wiederholung ein Paar aus einer positiven und einer
/// negativen Halbwelle. Nach dem Satzende gerechnet (die Hauptachse und die
/// Schwellen nutzen den ganzen Satz), kein Livezaehler.
///
/// Fuer Stapel besser als der Takt-Zaehler (37 Saetze: 37 statt 34 innerhalb
/// +-1), an Hanteln deutlich schlechter (Kurzhantel 15 statt 38 von 49 exakt):
/// die Schwerkraftprojektion einer drehenden Hantel traegt dort den Takt, den
/// der Hochpass und die Integration entfernen. Darum nur ueber das Profil
/// `.stapel` aktiv. Herkunft und Zahlen: Versuch vom 19.10.2026
/// (`phasenversuch.py`, Spalte `raw_phases`), hier ohne Aenderung portiert.
enum Phasenzaehler {
    /// Schwelle auf dem 1-s-Effektivwert der hochpassgefilterten Beschleunigung
    /// in g. Alle 97 echten Saetze liegen darueber (kleinster Wert 0,09 g); die
    /// Schwelle ist nicht an Sensorrauschen kalibriert.
    private static let bewegungMin = 0.01
    private static let hochpassHz = 0.15
    private static let tiefpassHz = 2.0
    /// Zeitkonstante der leckenden Integration in Sekunden.
    private static let leckS = 2.0
    private static let g = 9.80665
    /// Untergrenze der Schwelle in m/s und Anteil des 90. Perzentils.
    private static let schwelleMin = 0.015
    private static let schwelleAnteil = 0.2
    private static let halbwelleS = 0.15...6.0
    private static let zyklusS = 0.6...10.0
    private static let flaechenMin = 0.1

    struct Zyklus: Equatable {
        let von: Int
        let umkehr: Int
        let bis: Int
        /// kleinere Flaeche der beiden Halbwellen durch die groessere (0...1)
        let bilanz: Double
    }

    /// nil, wenn keine Bewegung nachgewiesen oder kein Paar gefunden wurde.
    static func auswerten(_ messwerte: [SensorMesswert], rateHz rate: Double) -> Satztakt.Ergebnis? {
        guard messwerte.count > 1 else { return nil }
        let hoch = [\Vektor3.x, \.y, \.z].map { pfad in
            Biquad.hochpass(hz: hochpassHz, rate: rate).filtern(messwerte.map { $0.beschleunigung[keyPath: pfad] })
        }
        guard bewegung(hoch, rate: rate) >= bewegungMin else { return nil }
        let achse = Satztakt.hauptachse(hoch)
        let koeff = g / rate
        let leck = exp(-1 / (leckS * rate))
        var v = [Double](repeating: 0, count: achse.count)
        var y = 0.0
        for i in achse.indices { y = koeff * achse[i] + leck * y; v[i] = y }
        let glatt = Biquad.tiefpass(hz: tiefpassHz, rate: rate).filtern(v)
        let zyklen = zyklen(glatt, rate: rate)
        guard let erster = zyklen.first, let letzter = zyklen.last else { return nil }

        let beginn = messwerte[erster.von].t
        let ende = messwerte[min(letzter.bis, messwerte.count - 1)].t
        let bilanzen = zyklen.map(\.bilanz).sorted()
        let ausschlag = glatt.map(abs).max() ?? 0
        return Satztakt.Ergebnis(anzahl: zyklen.count, takt: (ende - beginn) / Double(zyklen.count),
                                 beginn: beginn, ende: ende, guete: bilanzen[bilanzen.count / 2], ausschlag: ausschlag)
    }

    /// Groesster 1-s-Effektivwert der dreiachsigen, hochpassgefilterten Beschleunigung.
    static func bewegung(_ hoch: [[Double]], rate: Double) -> Double {
        let n = Int(rate)
        let count = hoch[0].count
        guard n > 0, count >= n else { return 0 }
        let energie = (0..<count).map { i in hoch.reduce(0.0) { $0 + $1[i] * $1[i] } }
        var summe = energie[0..<n].reduce(0, +)
        var beste = summe
        for i in n..<count {
            summe += energie[i] - energie[i - n]
            beste = max(beste, summe)
        }
        return (max(0, beste) / Double(n)).squareRoot()
    }

    /// Paart zwei benachbarte gegensinnige Halbwellen zu einem Zyklus. Eine
    /// Halbwelle gilt nur, wenn sie am Rand zur Ruhe zurueckkehrt, 0,15 bis 6 s
    /// dauert und die Schwelle erreicht; sonst reisst die Nachbarschaft ab.
    static func zyklen(_ v: [Double], rate: Double) -> [Zyklus] {
        guard v.count > 1 else { return [] }
        let betraege = v.map(abs).sorted()
        let schwelle = max(schwelleMin, schwelleAnteil * quantil(betraege, 0.9))
        var vorzeichen = v.map { $0 > 0 ? 1.0 : ($0 < 0 ? -1.0 : 0.0) }
        // Exakte Nullen gehoeren zur vorigen Halbwelle: echte Nulldurchgaenge bleiben.
        for i in 1..<vorzeichen.count where vorzeichen[i] == 0 { vorzeichen[i] = vorzeichen[i - 1] }
        var kanten: [Int] = [0]
        for i in 1..<v.count where vorzeichen[i] * vorzeichen[i - 1] < 0 { kanten.append(i) }
        kanten.append(v.count)
        kanten = Array(Set(kanten)).sorted()

        var offen: (von: Int, bis: Int, flaeche: Double)?
        var zyklen: [Zyklus] = []
        for k in 0..<(kanten.count - 1) {
            let a = kanten[k], b = kanten[k + 1]
            let dauer = Double(b - a) / rate
            let geschlossen = b < v.count || abs(v[v.count - 1]) <= 0.15 * schwelle
            let begonnen = a > 0 || abs(v[0]) <= 0.15 * schwelle
            let spitze = v[a..<b].map(abs).max() ?? 0
            guard begonnen, geschlossen, halbwelleS.contains(dauer), spitze >= schwelle else { offen = nil; continue }
            let jetzt = (von: a, bis: b, flaeche: v[a..<b].reduce(0, +) / rate)
            if let vorher = offen {
                let laenge = Double(b - vorher.von) / rate
                let kleiner = min(abs(vorher.flaeche), abs(jetzt.flaeche))
                let groesser = max(abs(vorher.flaeche), abs(jetzt.flaeche))
                let bilanz = kleiner / groesser
                if vorher.bis == a, vorher.flaeche * jetzt.flaeche < 0, zyklusS.contains(laenge), bilanz >= flaechenMin {
                    zyklen.append(Zyklus(von: vorher.von, umkehr: a, bis: b, bilanz: bilanz))
                    offen = nil
                    continue
                }
            }
            offen = jetzt
        }
        return zyklen
    }

    /// Lineare Interpolation wie `numpy.quantile` auf einem sortierten Feld.
    private static func quantil(_ sortiert: [Double], _ q: Double) -> Double {
        let pos = q * Double(sortiert.count - 1)
        let unten = Int(pos.rounded(.down)), oben = min(sortiert.count - 1, unten + 1)
        return sortiert[unten] + (pos - Double(unten)) * (sortiert[oben] - sortiert[unten])
    }
}

/// Butterworth zweiter Ordnung (ein Abschnitt, bilineare Transformation mit
/// Vorverzerrung wie `scipy.signal.butter`), Direktform II transponiert. Der
/// Anfangszustand ist der eingeschwungene Zustand fuer den ersten Wert
/// (`sosfilt_zi * x[0]`), damit der Start keinen Sprung erzeugt.
struct Biquad {
    let b0, b1, b2, a1, a2: Double

    static func tiefpass(hz: Double, rate: Double) -> Biquad {
        let k = tan(.pi * hz / rate)
        let norm = 1 / (1 + 2.0.squareRoot() * k + k * k)
        let b0 = k * k * norm
        return Biquad(b0: b0, b1: 2 * b0, b2: b0, a1: 2 * (k * k - 1) * norm, a2: (1 - 2.0.squareRoot() * k + k * k) * norm)
    }

    static func hochpass(hz: Double, rate: Double) -> Biquad {
        let k = tan(.pi * hz / rate)
        let norm = 1 / (1 + 2.0.squareRoot() * k + k * k)
        return Biquad(b0: norm, b1: -2 * norm, b2: norm, a1: 2 * (k * k - 1) * norm, a2: (1 - 2.0.squareRoot() * k + k * k) * norm)
    }

    func filtern(_ x: [Double]) -> [Double] {
        guard let erster = x.first else { return [] }
        // Eingeschwungen bei konstantem Eingang x[0]: y = H(1) * x[0].
        let ruhe = (b0 + b1 + b2) / (1 + a1 + a2) * erster
        var z1 = ruhe - b0 * erster
        var z2 = b2 * erster - a2 * ruhe
        return x.map { xn in
            let y = b0 * xn + z1
            z1 = b1 * xn - a1 * y + z2
            z2 = b2 * xn - a2 * y
            return y
        }
    }
}
