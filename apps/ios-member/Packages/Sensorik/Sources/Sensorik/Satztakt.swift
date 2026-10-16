import Foundation

/// Auswertung eines ganzen Satzes nach dem Satzende: Takt der Bewegung
/// bestimmen und messen, wie lange er gleichmaessig anliegt. Aufheben und
/// Ablegen der Kurzhantel haben keinen Takt und fallen damit heraus, ohne
/// dass eine Schwelle sie abschneiden muesste. Rein wie `Zaehler`: keine
/// Uhr, kein Zufall, derselbe Code live und offline gegen Aufnahmen.
///
/// Warum nicht der Drehraten-Zaehler: Beim Druecken und Strecken ueber Kopf
/// dreht sich die Hantel kaum (Drehrate 25 bis 40 Grad/s, unter der
/// Schwelle), die Beschleunigung schwingt aber im Satztakt (Aufnahmen vom
/// 16.10.: 0,65 bis 1,26 g, Takt rund 1,9 s).
public enum Satztakt {
    public struct Ergebnis: Equatable, Sendable {
        public let anzahl: Int
        /// Dauer einer Wiederholung in Sekunden.
        public let takt: TimeInterval
        /// Messwertzeiten, zwischen denen der Takt anliegt.
        public let beginn: TimeInterval
        public let ende: TimeInterval
        /// Anteil der Schwingung, der im Takt liegt (0...1). Niedrig, wenn
        /// der Takt nur schwach oder unregelmaessig ist.
        public let guete: Double
        /// Spitzenwert der Takt-Huellkurve in g.
        public let ausschlag: Double
    }

    /// Kennung fuer rep_events und aufnahme.json (`ZaehlerProfil.algo` fuer die Takt-Auswertung).
    public static let algo = "kurzhantel/takt1"

    /// Die Wiederholungen als gleich lange Abschnitte des Takts. Einzelne
    /// Zeiten kennt die Auswertung nicht, nur Beginn, Ende und Takt; die
    /// Umkehr liegt in der Mitte. Ehrlicher als zehn erfundene Spitzen und
    /// genug fuer Zahl und Gesamtdauer.
    public static func wiederholungen(_ e: Ergebnis) -> [Wiederholung] {
        let dauer = (e.ende - e.beginn) / Double(e.anzahl)
        return (0..<e.anzahl).map { i in
            let beginn = e.beginn + Double(i) * dauer
            return Wiederholung(nummer: i + 1, beginn: beginn, umkehr: beginn + dauer / 2, ende: beginn + dauer,
                                ausschlag: e.ausschlag, sicherheit: min(1, max(0, e.guete)),
                                pauseDavor: i == 0 ? nil : 0)
        }
    }

    // Startwerte, an den Aufnahmen vom 16.10. abgestimmt (15 Saetze,
    // Kurzhantel): 10 exakt, 13 auf +-1.
    private static let tiefpassHz = 3.0
    /// Gleitender Mittelwert, der die langsame Lageaenderung (Aufheben,
    /// Ablegen, Schraeglage) aus dem Signal nimmt.
    private static let langsamS = 3.0
    private static let taktMin = 1.2
    private static let taktMax = 4.0
    /// Ein Oberton (Druecken hat zwei Hoecker je Wiederholung) ist kuerzer
    /// als der Takt: der kleinste Kandidat mit fast bester Korrelation gewinnt.
    private static let kandidatAnteil = 0.85
    /// Die Hanning-Fensterung der Huellkurve macht die gemessene Breite
    /// etwa ein Drittel Zyklus kleiner als die Bewegung.
    private static let randAnteil = 0.6
    private static let rundungsZuschlag = 0.3
    private static let mindestDauer = 5.0

    public static func auswerten(_ messwerte: [SensorMesswert], rateHz: Double = 50) -> Ergebnis? {
        let n = messwerte.count
        let dt = 1 / rateHz
        guard n > Int(mindestDauer * rateHz) else { return nil }
        let s = signal(messwerte, dt: dt)
        guard let (takt, guete) = takt(s, dt: dt) else { return nil }
        let (huelle, ausschlag) = huellkurve(s, takt: takt, dt: dt)
        guard ausschlag > 0 else { return nil }
        let spitze = huelle.indices.max { huelle[$0] < huelle[$1] }!
        var a = spitze, b = spitze
        while a > 0, huelle[a - 1] >= randAnteil * ausschlag { a -= 1 }
        while b < n - 1, huelle[b + 1] >= randAnteil * ausschlag { b += 1 }
        let breite = Double(b - a) * dt
        let anzahl = Int(breite / takt + 0.5 + rundungsZuschlag)
        guard anzahl >= 1 else { return nil }
        return Ergebnis(anzahl: anzahl, takt: takt, beginn: messwerte[a].t, ende: messwerte[b].t,
                        guete: guete, ausschlag: ausschlag)
    }

    // MARK: - Signal

    /// Beschleunigung auf der Achse der groessten Streuung, tiefpassgefiltert
    /// und von der langsamen Lage befreit.
    private static func signal(_ m: [SensorMesswert], dt: Double) -> [Double] {
        let rc = 1 / (2 * .pi * tiefpassHz)
        let alpha = dt / (rc + dt)
        let fenster = max(1, Int(langsamS / dt))
        let pfade: [KeyPath<Vektor3, Double>] = [\.x, \.y, \.z]
        let achsen: [[Double]] = pfade.map { pfad in
            var y = m[0].beschleunigung[keyPath: pfad]
            let tief = m.map { wert -> Double in
                y += alpha * (wert.beschleunigung[keyPath: pfad] - y)
                return y
            }
            let mittel = gleitenderMittelwert(tief, fenster: fenster)
            return zip(tief, mittel).map { $0 - $1 }
        }
        return hauptachse(achsen)
    }

    private static func gleitenderMittelwert(_ x: [Double], fenster: Int) -> [Double] {
        var summe = [0.0]
        summe.reserveCapacity(x.count + 1)
        for v in x { summe.append(summe[summe.count - 1] + v) }
        return x.indices.map { i in
            let a = max(0, i - fenster / 2), b = min(x.count, i + fenster / 2 + 1)
            return (summe[b] - summe[a]) / Double(b - a)
        }
    }

    /// Projektion auf die erste Hauptkomponente (Potenzverfahren, 3x3).
    private static func hauptachse(_ spalten: [[Double]]) -> [Double] {
        let n = spalten[0].count
        let mittel = spalten.map { $0.reduce(0, +) / Double(n) }
        let x = spalten.enumerated().map { k, c in c.map { $0 - mittel[k] } }
        var kov = [[Double]](repeating: [0, 0, 0], count: 3)
        for i in 0..<3 { for j in 0..<3 {
            var s = 0.0
            for k in 0..<n { s += x[i][k] * x[j][k] }
            kov[i][j] = s / Double(n)
        } }
        var v = [1.0, 1.0, 1.0]
        for _ in 0..<60 {
            let w = (0..<3).map { i in (0..<3).reduce(0.0) { $0 + kov[i][$1] * v[$1] } }
            let norm = (w.reduce(0) { $0 + $1 * $1 }).squareRoot()
            guard norm > 0 else { break }
            v = w.map { $0 / norm }
        }
        return (0..<n).map { k in v[0] * x[0][k] + v[1] * x[1][k] + v[2] * x[2][k] }
    }

    // MARK: - Takt

    private static func autokorrelation(_ x: [Double], lag: Int) -> Double {
        var s = 0.0
        for i in 0..<(x.count - lag) { s += x[i] * x[i + lag] }
        return s / Double(x.count - lag)
    }

    /// Takt aus der Autokorrelation und der Anteil der Schwingung, der in
    /// ihm liegt (Korrelation beim Takt geteilt durch die Varianz).
    private static func takt(_ s: [Double], dt: Double) -> (TimeInterval, Double)? {
        let mittel = s.reduce(0, +) / Double(s.count)
        let x = s.map { $0 - mittel }
        let varianz = x.reduce(0) { $0 + $1 * $1 } / Double(x.count)
        guard varianz > 1e-9 else { return nil }
        let von = Int(taktMin / 2 / dt), bis = min(Int(taktMax / dt), x.count / 2)
        guard bis > von + 2 else { return nil }
        var c: [Int: Double] = [:]
        for l in von...bis { c[l] = autokorrelation(x, lag: l) }
        let spitzen = ((von + 1)..<bis).filter { c[$0]! > c[$0 - 1]! && c[$0]! >= c[$0 + 1]! && c[$0]! > 0 }
        guard let beste = spitzen.map({ c[$0]! }).max() else { return nil }
        guard let lag = spitzen.first(where: { Double($0) * dt >= taktMin && c[$0]! >= kandidatAnteil * beste })
        else { return nil }
        return (Double(lag) * dt, c[lag]! / varianz)
    }

    /// Betrag der komplexen Demodulation beim Takt, mit Hanning-Fenster ueber
    /// drei Takte: gross, wo die Schwingung im Takt liegt, klein davor/danach.
    private static func huellkurve(_ s: [Double], takt: Double, dt: Double) -> ([Double], Double) {
        let w = 2 * Double.pi / takt
        let halb = max(1, Int(1.5 * takt / dt))
        let cosinus = s.indices.map { cos(w * Double($0) * dt) }
        let sinus = s.indices.map { sin(w * Double($0) * dt) }
        var huelle = [Double](repeating: 0, count: s.count)
        for i in s.indices {
            var re = 0.0, im = 0.0
            for k in max(0, i - halb)..<min(s.count, i + halb + 1) {
                let h = 0.5 * (1 + cos(Double.pi * Double(k - i) / Double(halb)))
                re += h * s[k] * cosinus[k]
                im += h * s[k] * sinus[k]
            }
            huelle[i] = (re * re + im * im).squareRoot() / Double(halb)
        }
        return (huelle, huelle.max() ?? 0)
    }
}
