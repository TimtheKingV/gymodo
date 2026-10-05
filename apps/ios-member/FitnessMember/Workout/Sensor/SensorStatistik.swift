#if DEBUG
import Foundation

/// Was am iPhone ankommt, nicht was am Sensor eingestellt ist (Spec 4.7).
/// Rein: bekommt Zeitstempel, kennt weder Bluetooth noch Dateien.
struct SensorStatistik: Sendable {
    struct Abstand: Codable, Equatable, Sendable {
        var median: Double
        var p95: Double
        var max: Double
    }

    struct Ergebnis: Codable, Equatable, Sendable {
        var pakete: Int
        var rateIstHz: Double
        var abstandMs: Abstand
        var luecken: Int
        var verworfeneBytes: Int

        static let leer = Ergebnis(pakete: 0, rateIstHz: 0,
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

    mutating func erfassen(t: TimeInterval) {
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
    mutating func lueckeBegonnen() {
        luecken += 1
        nachLuecke = true
    }

    func rateLetzteSekunde(bis jetzt: TimeInterval) -> Double {
        Double(juengste.filter { $0 <= jetzt && jetzt - $0 < 1 }.count)
    }

    func ergebnis(verworfeneBytes: Int) -> Ergebnis {
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
#endif
