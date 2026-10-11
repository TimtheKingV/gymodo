import Foundation

/// Was am iPhone ankommt, nicht was am Sensor eingestellt ist (Spec 4.7).
/// Rein: bekommt Zeitstempel, kennt weder Bluetooth noch Dateien.
public struct SensorStatistik: Sendable {
    public struct Abstand: Codable, Equatable, Sendable {
        public var median: Double
        public var p95: Double
        public var max: Double

        public init(median: Double, p95: Double, max: Double) {
            self.median = median; self.p95 = p95; self.max = max
        }
    }

    public struct Ergebnis: Codable, Equatable, Sendable {
        public var pakete: Int
        public var rateIstHz: Double
        public var abstandMs: Abstand
        public var luecken: Int
        public var verworfeneBytes: Int

        public init(pakete: Int, rateIstHz: Double, abstandMs: Abstand, luecken: Int, verworfeneBytes: Int) {
            self.pakete = pakete; self.rateIstHz = rateIstHz; self.abstandMs = abstandMs
            self.luecken = luecken; self.verworfeneBytes = verworfeneBytes
        }

        public static let leer = Ergebnis(pakete: 0, rateIstHz: 0,
                                   abstandMs: Abstand(median: 0, p95: 0, max: 0),
                                   luecken: 0, verworfeneBytes: 0)
    }

    private var pakete = 0
    private var letzter: TimeInterval?
    /// In Sekunden. Fuenf Minuten bei 100 Hz sind 30 000 Doubles -- das
    /// darf im Speicher liegen, dafuer stimmen Median und p95 exakt.
    private var abstaende: [Double] = []
    private var luecken = 0
    private var nachLuecke = false
    /// Nur das letzte Stueck, fuer die Anzeige in der Sensor-Zeile.
    private var juengste: [TimeInterval] = []

    public init() {}

    public mutating func erfassen(t: TimeInterval) {
        pakete += 1
        if let letzter, !nachLuecke { abstaende.append(t - letzter) }
        letzter = t
        nachLuecke = false
        juengste.append(t)
        if let erster = juengste.first, t - erster > 2 {
            juengste.removeAll { t - $0 > 1 }
        }
    }

    /// Der Abstand ueber eine getrennte Verbindung hinweg ist keine
    /// Eigenschaft der Funkstrecke und verdirbt sonst Maximum und Rate.
    public mutating func lueckeBegonnen() {
        luecken += 1
        nachLuecke = true
    }

    public func rateLetzteSekunde(bis jetzt: TimeInterval) -> Double {
        Double(juengste.filter { $0 <= jetzt && jetzt - $0 < 1 }.count)
    }

    public func ergebnis(verworfeneBytes: Int) -> Ergebnis {
        guard !abstaende.isEmpty else {
            var leer = Ergebnis.leer
            leer.pakete = pakete; leer.luecken = luecken; leer.verworfeneBytes = verworfeneBytes
            return leer
        }
        let sortiert = abstaende.sorted()
        let n = sortiert.count
        let median = n % 2 == 1 ? sortiert[n / 2] : (sortiert[n / 2 - 1] + sortiert[n / 2]) / 2
        let p95 = sortiert[min(n - 1, Int((Double(n) * 0.95).rounded(.up)) - 1)]
        let summe = abstaende.reduce(0, +)
        func ms(_ sekunden: Double) -> Double { (sekunden * 1000 * 100).rounded() / 100 }
        return Ergebnis(
            pakete: pakete,
            rateIstHz: summe > 0 ? (Double(n) / summe * 10).rounded() / 10 : 0,
            abstandMs: Abstand(median: ms(median), p95: ms(p95), max: ms(sortiert[n - 1])),
            luecken: luecken,
            verworfeneBytes: verworfeneBytes
        )
    }
}
