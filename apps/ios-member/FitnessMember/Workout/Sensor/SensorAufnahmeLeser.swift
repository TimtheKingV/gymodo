#if DEBUG
import Foundation

enum SensorAufnahmeLeser {
    enum Fehler: Error { case unbekanntesFormat(String), kaputteZeile(String) }

    enum Eintrag: Equatable {
        case messwert(SensorMesswert)
        case luecke(von: TimeInterval, bis: TimeInterval)
    }

    static func lesen(ordner: URL) throws -> (datei: SensorAufnahmeDatei, eintraege: [Eintrag]) {
        let datei = try JSONDecoder.testnotiz().decode(
            SensorAufnahmeDatei.self, from: Data(contentsOf: ordner.appendingPathComponent("aufnahme.json")))
        // Unbekanntes ablehnen statt raten (Spec 6.3).
        guard datei.format == SensorAufnahmeDatei.formatkennung else {
            throw Fehler.unbekanntesFormat(datei.format)
        }
        let csv = try String(contentsOf: ordner.appendingPathComponent("messwerte.csv"), encoding: .utf8)
        var eintraege: [Eintrag] = []
        for zeile in csv.split(separator: "\n").dropFirst() {
            if zeile.hasPrefix("# luecke ") {
                let grenzen = zeile.dropFirst("# luecke ".count).split(separator: "-").compactMap { Double($0) }
                guard grenzen.count == 2 else { throw Fehler.kaputteZeile(String(zeile)) }
                eintraege.append(.luecke(von: grenzen[0], bis: grenzen[1]))
            } else if zeile.hasPrefix("#") {
                continue
            } else {
                let z = zeile.split(separator: ",").compactMap { Double($0) }
                guard z.count == 10 else { throw Fehler.kaputteZeile(String(zeile)) }
                eintraege.append(.messwert(SensorMesswert(
                    t: z[0],
                    beschleunigung: Vektor3(x: z[1], y: z[2], z: z[3]),
                    drehrate: Vektor3(x: z[4], y: z[5], z: z[6]),
                    winkel: Vektor3(x: z[7], y: z[8], z: z[9]))))
            }
        }
        return (datei, eintraege)
    }
}
#endif
