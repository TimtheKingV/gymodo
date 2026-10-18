import Foundation
@testable import Sensorik

/// Gruppe eines Satzes beim Abstimmen von Satztakt: Abstimmung darf der
/// Bauende ansehen, die Blindpruefung erst nach dem Einfrieren der
/// Parameter (und nur einmal). Kurzhantel vom 16.10. wurde schon frueher
/// abgestimmt und zaehlt nur als Regressionsschutz.
enum Gruppe: String { case abstimmen, blind, frueherAbgestimmt }

struct TaktZeile {
    let ordner: String
    let art: Befestigungsart
    let wahr: Int
    let gezaehlt: Int?
    let gruppe: Gruppe
}

enum TaktBericht {
    /// Nach Ordnername sortierte Namen einer Art: 0, 2, 4 ... abstimmen,
    /// 1, 3, 5 ... blind. Eine feste Regel statt Zufall, damit die
    /// Aufteilung mit jedem Lauf gleich bleibt.
    static func aufteilen(_ namen: [String]) -> [Gruppe] {
        namen.indices.map { $0 % 2 == 0 ? .abstimmen : .blind }
    }

    /// Die Auswertung aller Saetze dauert Minuten (Debug), deshalb einmal je Testlauf.
    static let gemessen: [TaktZeile] = (try? zeilen()) ?? []

    static func zeilen() throws -> [TaktZeile] {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        var zeilen: [TaktZeile] = []
        for art in Befestigungsart.allCases {
            let namen = k.aufnahmen
                .filter { $0.value.fuerZaehler && $0.value.befestigungsart == art && $0.value.repsWahr != nil }
                .keys.sorted()
                .filter { fm.fileExists(atPath: Pfade.aufnahmen.appendingPathComponent($0).appendingPathComponent("messwerte.csv").path) }
            let frueh = namen.filter { art == .kurzhantel && $0.hasPrefix("2026-10-16-") }
            let rest = namen.filter { !frueh.contains($0) }
            let gruppen = aufteilen(rest)
            let alle = frueh.map { ($0, Gruppe.frueherAbgestimmt) } + zip(rest, gruppen).map { ($0, $1) }
            for (name, gruppe) in alle {
                let wahr = try pflicht(k.aufnahmen[name]?.repsWahr)
                let gezaehlt = try AufnahmeLauf.takt(ordner: Pfade.aufnahmen.appendingPathComponent(name), art: art)
                zeilen.append(TaktZeile(ordner: name, art: art, wahr: wahr, gezaehlt: gezaehlt, gruppe: gruppe))
            }
        }
        return zeilen
    }

    private static func pflicht<T>(_ wert: T?) throws -> T {
        guard let wert else { throw SensorAufnahmeLeser.Fehler.unbekanntesFormat("repsWahr fehlt") }
        return wert
    }

    static func quote(_ zeilen: [TaktZeile]) -> (n: Int, exakt: Double, einsGenau: Double) {
        guard !zeilen.isEmpty else { return (0, 0, 0) }
        let exakt = zeilen.filter { $0.gezaehlt == $0.wahr }.count
        let eins = zeilen.filter { z in z.gezaehlt.map { abs($0 - z.wahr) <= 1 } ?? false }.count
        return (zeilen.count, Double(exakt) / Double(zeilen.count), Double(eins) / Double(zeilen.count))
    }

    /// Arten, deren Parameter eingefroren sind. Nur fuer sie zeigt der Bericht
    /// die Blindsaetze; vorher wuerde jeder Blick darauf zum Abstimmen.
    static let blindFrei: Set<Befestigungsart> = [.stapel]

    static func markdown(_ zeilen: [TaktZeile], blindFuer: Set<Befestigungsart> = blindFrei) -> String {
        let zeilen = zeilen.filter { $0.gruppe != .blind || blindFuer.contains($0.art) }
        func pct(_ x: Double) -> String { String(format: "%.0f %%", locale: Locale(identifier: "en_US_POSIX"), x * 100) }
        func tabelle(_ titel: String, _ zeilen: [TaktZeile]) -> String {
            var text = "### \(titel)\n\n| Art | Sätze | exakt | ±1 |\n|---|---|---|---|\n"
            for art in Befestigungsart.allCases {
                let z = zeilen.filter { $0.art == art }
                guard !z.isEmpty else { continue }
                let q = quote(z)
                text += "| \(art.rawValue) | \(q.n) | \(pct(q.exakt)) | \(pct(q.einsGenau)) |\n"
            }
            let q = quote(zeilen)
            text += "| **gepoolt** | \(q.n) | \(pct(q.exakt)) | \(pct(q.einsGenau)) |\n\n"
            return text
        }
        var text = "# Takt-Bericht (Satztakt, ganzer Satz)\n\nZiel: höchstens ±1 neben der Wahrheit. Erzeugt von `TaktBerichtTests.berichtSchreiben`.\n\n"
        text += tabelle("Abstimmung", zeilen.filter { $0.gruppe == .abstimmen })
        text += tabelle("Blindprüfung (nur Arten mit eingefrorenen Parametern: \(blindFuer.map(\.rawValue).sorted().joined(separator: ", ").isEmpty ? "keine" : blindFuer.map(\.rawValue).sorted().joined(separator: ", ")))", zeilen.filter { $0.gruppe == .blind })
        text += tabelle("Früher abgestimmt (Kurzhantel 16.10., nur Regressionsschutz)", zeilen.filter { $0.gruppe == .frueherAbgestimmt })
        text += "### Sätze außerhalb ±1\n\n| Ordner | Art | Gruppe | wahr | gezählt |\n|---|---|---|---|---|\n"
        for z in zeilen where !(z.gezaehlt.map { abs($0 - z.wahr) <= 1 } ?? false) {
            text += "| \(z.ordner) | \(z.art.rawValue) | \(z.gruppe.rawValue) | \(z.wahr) | \(z.gezaehlt.map(String.init) ?? "–") |\n"
        }
        return text
    }
}
