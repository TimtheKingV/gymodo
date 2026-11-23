import Foundation
@testable import Sensorik

/// Nachtraegliche Lage einer Aufnahme als Bezug fuer das Guetetor (Tempo-Spec 4
/// und 6.4), Rechnung wie `tools/sensorik-sim/tempo_nachrechnung.py`:
/// Schwerkraftrichtung = Mittel der Beschleunigung ueber die ganze Aufnahme,
/// Vertikalbeschleunigung zweimal aufsummiert und je um den gleitenden
/// Mittelwert ueber eine Periode befreit. Nicht-kausal: kennt den ganzen Satz.
///
/// Das Skript liefert nur eine Position in Metern. Fuer den Vergleich mit der
/// Live-Lage wird sie je Halbwelle auf 0…1 normiert: Zwischen zwei
/// aufeinanderfolgenden Extremen wird linear umgerechnet, das untere wird 0,
/// das obere 1. Oben ist gegen die Schwerkraft: Am ruhenden Sensor zeigt die
/// gemessene Beschleunigung nach oben, auf ihre mittlere Richtung projiziert
/// ist eine aufwaerts beschleunigte Last also positiv.
enum Lagebezug {
    struct Ergebnis {
        /// Je Messwert; ausserhalb von `aktiv` 0 und ohne Bedeutung.
        let lage: [Double]
        /// Vom ersten bis einschliesslich zum letzten Extrem im aktiven Teil.
        let aktiv: Range<Int>
        /// Periode einer Wiederholung (s), aus der Autokorrelation.
        let periode: Double
    }

    /// Nachtraegliche Rechnung wie tools/sensorik-sim/tempo_nachrechnung.py, je Halbwelle auf 0…1 normiert.
    static func berechne(_ werte: [SensorMesswert], rateHz fs: Double) -> Ergebnis? {
        let n = werte.count
        guard n >= 3 else { return nil }
        var mittel = (x: 0.0, y: 0.0, z: 0.0)
        for w in werte {
            mittel.x += w.beschleunigung.x; mittel.y += w.beschleunigung.y; mittel.z += w.beschleunigung.z
        }
        mittel = (mittel.x / Double(n), mittel.y / Double(n), mittel.z / Double(n))
        let betrag = (mittel.x * mittel.x + mittel.y * mittel.y + mittel.z * mittel.z).squareRoot()
        guard betrag > 0 else { return nil }
        let av = werte.map { w in
            let entlang = (w.beschleunigung.x * mittel.x + w.beschleunigung.y * mittel.y
                + w.beschleunigung.z * mittel.z) / betrag
            return (entlang - betrag) * 9.81
        }
        guard let periode = periode(av, fs: fs) else { return nil }
        let fenster = periode * fs

        var v = kumuliert(av, fs: fs)
        v = zip(v, gleitend(v, fenster)).map { $0 - $1 }
        var p = kumuliert(v, fs: fs)
        p = zip(p, gleitend(p, fenster)).map { $0 - $1 }

        let huelle = gleitend(av.map { $0 * $0 }, fenster).map { $0.squareRoot() }
        let grenze = 0.3 * (huelle.max() ?? 0)
        var bester = 0..<0
        var i = 0
        while i < n {
            guard huelle[i] > grenze else { i += 1; continue }
            var j = i
            while j < n, huelle[j] > grenze { j += 1 }
            if j - i > bester.count { bester = i..<j }
            i = j
        }

        let extreme = halbwellen(p, in: bester, abstand: 0.6 * fenster)
        guard extreme.count >= 2, let erstes = extreme.first, let letztes = extreme.last else { return nil }
        var lage = [Double](repeating: 0, count: n)
        for (a, b) in zip(extreme, extreme.dropFirst()) {
            let unten = a.oben ? p[b.index] : p[a.index]
            let oben = a.oben ? p[a.index] : p[b.index]
            for k in a.index...b.index { lage[k] = (p[k] - unten) / (oben - unten) }
        }
        return Ergebnis(lage: lage, aktiv: erstes.index..<(letztes.index + 1), periode: periode)
    }

    // MARK: - Bausteine wie im Skript

    /// `np.cumsum(x)/fs`
    private static func kumuliert(_ x: [Double], fs: Double) -> [Double] {
        var summe = 0.0
        return x.map { summe += $0; return summe / fs }
    }

    /// `movavg`: zentriertes Rechteck ueber `max(3, int(n)|1)` Werte, Raender gehalten.
    static func gleitend(_ x: [Double], _ laenge: Double) -> [Double] {
        guard !x.isEmpty else { return [] }
        let k = max(3, Int(laenge) | 1), h = k / 2
        func wert(_ i: Int) -> Double { x[min(max(i, 0), x.count - 1)] }
        var summe = (-h...h).reduce(0) { $0 + wert($1) }
        var ergebnis = [Double](repeating: 0, count: x.count)
        for i in x.indices {
            ergebnis[i] = summe / Double(k)
            summe += wert(i + h + 1) - wert(i - h)
        }
        return ergebnis
    }

    /// `period`: Verschiebung mit der groessten Autokorrelation zwischen 0,8 und 8 s.
    private static func periode(_ x: [Double], fs: Double) -> Double? {
        let mittel = x.reduce(0, +) / Double(x.count)
        let y = x.map { $0 - mittel }
        let lo = Int(0.8 * fs), hi = min(Int(8 * fs), y.count - 1)
        guard hi > lo else { return nil }
        var bester = lo, besterWert = -Double.infinity
        for lag in lo..<hi {
            var s = 0.0
            for i in 0..<(y.count - lag) { s += y[i] * y[i + lag] }
            if s > besterWert { besterWert = s; bester = lag }
        }
        return Double(bester) / fs
    }

    /// `peaks`: lokale Maxima, naeher als `abstand` behaelt das hoehere.
    private static func gipfel(_ x: [Double], in bereich: Range<Int>, abstand: Double) -> [Int] {
        var idx: [Int] = []
        guard bereich.count >= 3 else { return idx }
        for i in (bereich.lowerBound + 1)..<(bereich.upperBound - 1) where x[i] > x[i - 1] && x[i] >= x[i + 1] {
            if let letzter = idx.last, Double(i - letzter) < abstand {
                if x[i] > x[letzter] { idx[idx.count - 1] = i }
            } else {
                idx.append(i)
            }
        }
        return idx
    }

    struct Extrem: Equatable { let index: Int; let oben: Bool }

    /// Abwechselnde Extreme wie `strokes`: Gipfel und Taeler nach Zeit sortiert;
    /// zwei gleiche hintereinander behalten das weitere, Halbwellen unter 40 %
    /// des Medians fallen samt ihren beiden Extremen heraus (wie das Skript sie
    /// nicht zaehlt).
    static func halbwellen(_ p: [Double], in bereich: Range<Int>, abstand: Double) -> [Extrem] {
        let roh = (gipfel(p, in: bereich, abstand: abstand).map { Extrem(index: $0, oben: true) }
            + gipfel(p.map { -$0 }, in: bereich, abstand: abstand).map { Extrem(index: $0, oben: false) })
            .sorted { $0.index < $1.index }
        func abwechselnd(_ e: [Extrem]) -> [Extrem] {
            var r: [Extrem] = []
            for x in e {
                if let l = r.last, l.oben == x.oben {
                    if x.oben ? p[x.index] > p[l.index] : p[x.index] < p[l.index] { r[r.count - 1] = x }
                } else {
                    r.append(x)
                }
            }
            return r
        }
        var e = abwechselnd(roh)
        while e.count >= 2 {
            let huebe = zip(e, e.dropFirst()).map { abs(p[$0.index] - p[$1.index]) }
            let median = TempoBericht.median(huebe)
            guard let k = huebe.indices.min(by: { huebe[$0] < huebe[$1] }), huebe[k] < 0.4 * median else { break }
            // Am Rand faellt nur das aeussere Extrem, innen beide: so bleibt der Wechsel erhalten.
            if k == 0 { e.removeFirst() }
            else if k == huebe.count - 1 { e.removeLast() }
            else { e.removeSubrange(k...(k + 1)); e = abwechselnd(e) }
        }
        return e
    }
}
