import Foundation

/// Auswertung eines ganzen Satzes nach dem Satzende: Takt der Bewegung
/// bestimmen, dann die laengste Kette von Abschnitten einer Taktlaenge, in
/// der jeder Abschnitt seinem Vorgaenger nach Form und Groesse gleicht. Die
/// Zahl der Abschnitte ist die Zahl der Wiederholungen. Aufheben und Ablegen
/// gleichen keiner Wiederholung und fallen heraus, ohne dass eine Schwelle
/// auf der Signalstaerke sie abschneiden muesste. Rein wie `Zaehler`: keine
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
    public static let algo = "kurzhantel/takt2"

    /// Kennung je Art: Kurzhantel behaelt `takt2`, die anderen Arten starten bei `takt1`.
    public static func algo(fuer art: Befestigungsart) -> String {
        if TaktProfil.fuer(art)?.verfahren == .phasen { return "\(art.rawValue)/phasen1" }
        return art == .kurzhantel ? algo : "\(art.rawValue)/takt1"
    }

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

    private static let tiefpassHz = 3.0
    /// Gleitender Mittelwert, der die langsame Lageaenderung (Aufheben,
    /// Ablegen, Schraeglage) aus dem Signal nimmt.
    private static let langsamS = 3.0

    /// Kette zu kurz gegen die Aktivdauer: unter diesem Anteil der Schaetzung
    /// gilt die Schaetzung. An den Abstimmungssaetzen vom 18.10. greift das nur
    /// dort, wo die Kette bei 14 von 30 oder 4 von 8 abriss; die 35 Kurzhantel-
    /// Saetze vom 16.10. bleiben unberuehrt.
    private static let kettenAnteil = 0.7
    /// Anteil der Spitze der Takt-Huellkurve, ab dem ein Moment als aktiv gilt.
    private static let huellSchwelle = 0.4
    /// Eine Zahl aus Schaetzung oder erweitertem Takt ist unsicher (`Ergebnis.guete`).
    public static let unsicherGrenze = 0.49

    public static func auswerten(_ messwerte: [SensorMesswert], rateHz: Double = 50,
                                 profil: TaktProfil = .kurzhantel) -> Ergebnis? {
        if profil.verfahren == .phasen { return Phasenzaehler.auswerten(messwerte, rateHz: rateHz) }
        if let e = auswertenEinmal(messwerte, rateHz: rateHz, profil: profil) { return e }
        // Kein Takt im Profilbereich: noch einmal mit weiterer Obergrenze, aber unsicher.
        let weit = TaktProfil(taktMin: profil.taktMin, taktMax: profil.taktMax * 1.5, kappFaktor: profil.kappFaktor,
                              kandidatAnteil: profil.kandidatAnteil, gleichheitMin: profil.gleichheitMin,
                              abstandMin: profil.abstandMin, abstandMax: profil.abstandMax,
                              mindestDauer: profil.mindestDauer, verfahren: profil.verfahren)
        guard let e = auswertenEinmal(messwerte, rateHz: rateHz, profil: weit) else { return nil }
        return Ergebnis(anzahl: e.anzahl, takt: e.takt, beginn: e.beginn, ende: e.ende,
                        guete: min(e.guete, unsicherGrenze), ausschlag: e.ausschlag)
    }

    private static func auswertenEinmal(_ messwerte: [SensorMesswert], rateHz: Double,
                                        profil: TaktProfil) -> Ergebnis? {
        let n = messwerte.count
        let dt = 1 / rateHz
        guard n > Int(profil.mindestDauer * rateHz) else { return nil }
        let s = signal(messwerte, dt: dt, profil: profil)
        guard let (takt, guete) = takt(s, dt: dt, profil: profil) else { return nil }
        let (huelle, ausschlag) = huellkurve(s, takt: takt, dt: dt)
        guard ausschlag > 0 else { return nil }
        let laenge = Int((takt / dt).rounded())
        let kette = laengsteKette(s, laenge: laenge, profil: profil)
        // Die Schaetzung zaehlt zusammenhaengende aktive Laeufe ab `laufMin` Takten:
        // beide Haelften eines Satzes mit Pause, aber keine verstreuten Ausschlaege
        // eines schwachen Signals.
        let laeufe = aktiveLaeufe(huelle, schwelle: huellSchwelle * ausschlag, mindestens: Int(laufMin * Double(laenge)))
        let schaetzung = Int((Double(laeufe.reduce(0) { $0 + $1.count }) * dt / takt).rounded())
        let aktiv = laeufe.flatMap { $0 }
        if let erster = kette.first, let letzter = kette.last, Double(kette.count) >= kettenAnteil * Double(schaetzung) {
            return Ergebnis(anzahl: kette.count, takt: takt, beginn: messwerte[erster].t,
                            ende: messwerte[min(n - 1, letzter + laenge)].t, guete: guete, ausschlag: ausschlag)
        }
        guard schaetzung > 0, let von = aktiv.first, let bis = aktiv.last else { return nil }
        return Ergebnis(anzahl: schaetzung, takt: takt, beginn: messwerte[von].t, ende: messwerte[bis].t,
                        guete: min(guete, unsicherGrenze), ausschlag: ausschlag)
    }

    /// Anzahl Takte, die ein aktiver Lauf mindestens dauern muss.
    private static let laufMin = 2.5

    /// Indexlaeufe, in denen die Huellkurve `schwelle` erreicht, ohne
    /// Unterbrechung und mit mindestens `mindestens` Werten.
    private static func aktiveLaeufe(_ huelle: [Double], schwelle: Double, mindestens: Int) -> [[Int]] {
        var laeufe: [[Int]] = []
        var lauf: [Int] = []
        for i in huelle.indices {
            if huelle[i] >= schwelle { lauf.append(i) } else {
                if lauf.count >= mindestens { laeufe.append(lauf) }
                lauf = []
            }
        }
        if lauf.count >= mindestens { laeufe.append(lauf) }
        return laeufe
    }

    // MARK: - Kette

    /// Gleichheit nach Form und Groesse, 2<a,b>/(|a|^2+|b|^2) ohne Mittelwert:
    /// wie die normierte Korrelation bei gleicher Energie, aber klein, wenn ein
    /// Abschnitt viel schwaecher ist (Ausklingen nach dem Ablegen).
    private static func gleichheit(_ x: [Double], _ a: Int, _ b: Int, laenge: Int) -> Double {
        var ma = 0.0, mb = 0.0
        for k in 0..<laenge { ma += x[a + k]; mb += x[b + k] }
        ma /= Double(laenge); mb /= Double(laenge)
        var ab = 0.0, aa = 0.0, bb = 0.0
        for k in 0..<laenge {
            let u = x[a + k] - ma, v = x[b + k] - mb
            ab += u * v; aa += u * u; bb += v * v
        }
        return aa + bb > 0 ? 2 * ab / (aa + bb) : 0
    }

    /// Beginn des Abschnitts nach (`richtung` 1) bzw. vor (-1) `start`, der ihm
    /// am meisten gleicht, sofern die Gleichheit reicht.
    private static func naechster(_ x: [Double], nach start: Int, richtung: Int, laenge: Int,
                                  profil: TaktProfil) -> Int? {
        var beste = -2.0, bester: Int?
        for d in Int(profil.abstandMin * Double(laenge))...Int(profil.abstandMax * Double(laenge)) {
            let s = start + richtung * d
            guard s >= 0, s + laenge <= x.count else { continue }
            let g = gleichheit(x, start, s, laenge: laenge)
            if g > beste { beste = g; bester = s }
        }
        return beste >= profil.gleichheitMin ? bester : nil
    }

    /// Beginne der laengsten Kette sich gleichender Abschnitte. Startpunkte im
    /// Viertel-Takt-Raster, von jedem aus waechst die Kette in beide Richtungen.
    private static func laengsteKette(_ x: [Double], laenge: Int, profil: TaktProfil) -> [Int] {
        guard laenge > 0, x.count > laenge else { return [] }
        var beste: [Int] = []
        for saat in stride(from: 0, to: x.count - laenge, by: max(1, laenge / 4)) {
            var kette = [saat]
            var cur = saat
            while let s = naechster(x, nach: cur, richtung: 1, laenge: laenge, profil: profil) { kette.append(s); cur = s }
            cur = saat
            while let s = naechster(x, nach: cur, richtung: -1, laenge: laenge, profil: profil) { kette.insert(s, at: 0); cur = s }
            if kette.count > beste.count { beste = kette }
        }
        return beste
    }

    // MARK: - Signal

    /// Beschleunigung auf der Achse der groessten Streuung, tiefpassgefiltert
    /// und von der langsamen Lage befreit.
    private static func signal(_ m: [SensorMesswert], dt: Double, profil: TaktProfil) -> [Double] {
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
        return kappen(hauptachse(achsen), dt: dt, faktor: profil.kappFaktor)
    }

    /// Kappt bei `faktor` (Profil) mal dem typischen Sekunden-Effektivwert
    /// (Median der oberen Haelfte, also der aktiven Sekunden).
    private static func kappen(_ x: [Double], dt: Double, faktor: Double) -> [Double] {
        let sek = max(1, Int(1 / dt))
        guard x.count >= sek else { return x }
        let rms = stride(from: 0, through: x.count - sek, by: sek).map { i in
            (x[i..<(i + sek)].reduce(0) { $0 + $1 * $1 } / Double(sek)).squareRoot()
        }.sorted()
        let obere = rms[(rms.count / 2)...]
        let grenze = faktor * obere[obere.startIndex + obere.count / 2]
        guard grenze > 0 else { return x }
        return x.map { min(grenze, max(-grenze, $0)) }
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
    static func hauptachse(_ spalten: [[Double]]) -> [Double] {
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
    private static func takt(_ s: [Double], dt: Double, profil: TaktProfil) -> (TimeInterval, Double)? {
        let mittel = s.reduce(0, +) / Double(s.count)
        let x = s.map { $0 - mittel }
        let varianz = x.reduce(0) { $0 + $1 * $1 } / Double(x.count)
        guard varianz > 1e-9 else { return nil }
        let von = Int(profil.taktMin / 2 / dt), bis = min(Int(profil.taktMax / dt), x.count / 2)
        guard bis > von + 2 else { return nil }
        var c: [Int: Double] = [:]
        for l in von...bis { c[l] = autokorrelation(x, lag: l) }
        let spitzen = ((von + 1)..<bis).filter { c[$0]! > c[$0 - 1]! && c[$0]! >= c[$0 + 1]! && c[$0]! > 0 }
        guard let beste = spitzen.map({ c[$0]! }).max() else { return nil }
        guard let lag = spitzen.first(where: { Double($0) * dt >= profil.taktMin && c[$0]! >= profil.kandidatAnteil * beste })
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
