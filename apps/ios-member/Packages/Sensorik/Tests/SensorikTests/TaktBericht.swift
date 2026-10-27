import Foundation
@testable import Sensorik

/// Gruppe eines Satzes beim Abstimmen von Satztakt: Abstimmung darf der
/// Bauende ansehen, die Blindpruefung erst nach dem Einfrieren der
/// Parameter (und nur einmal). Kurzhantel vom 16.10. wurde schon frueher
/// abgestimmt und zaehlt nur als Regressionsschutz.
enum Gruppe: String { case abstimmen, blind, frueherAbgestimmt, gegenprobe }

struct TaktZeile {
    let ordner: String
    let art: Befestigungsart
    let wahr: Int
    let gezaehlt: Int?
    let gruppe: Gruppe
    var gespeichert: Int? = nil
    var unsicher: UnsicherGrund? = nil
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
            let gegenprobe = namen.filter { $0.hasPrefix("2026-10-26-") }
            let rest = namen.filter { !frueh.contains($0) && !gegenprobe.contains($0) }
            let gruppen = aufteilen(rest)
            let alle = frueh.map { ($0, Gruppe.frueherAbgestimmt) } + zip(rest, gruppen).map { ($0, $1) }
                + gegenprobe.map { ($0, Gruppe.gegenprobe) }
            for (name, gruppe) in alle {
                let wahr = try pflicht(k.aufnahmen[name]?.repsWahr)
                let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
                let ergebnis = AufnahmeLauf.taktergebnis(datei: datei, eintraege: eintraege, art: art)
                let unsicher: UnsicherGrund? = Satztakt.hatLuecke(in: eintraege) ? .luecke
                    : ergebnis.flatMap { $0.guete <= Satztakt.unsicherGrenze ? .signalSchwach : nil }
                zeilen.append(TaktZeile(ordner: name, art: art, wahr: wahr, gezaehlt: ergebnis?.anzahl,
                    gruppe: gruppe, gespeichert: datei.zaehler?.gezaehlt, unsicher: unsicher))
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
    static let blindFrei: Set<Befestigungsart> = [.stapel, .langhantel, .kurzhantel]

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
        text += "**Grenzen:** Alle Sätze stammen von einer Person, ihren Geräten und vier Trainingstagen (14., 16., 18. und 26.10.); die Aussage gilt nur dafür. "
        text += "Beinpresse, Waden und Kniebeuge haben 2 bis 4 Sätze, die Blindprüfung ist dort nur ein Hinweis. "
        text += "Aufteilung: je Art jeder zweite Satz (nach Ordnername) zum Abstimmen, der Rest blind. "
        text += "Die Blindsätze wurden erst nach dem Einfrieren der Parameter gelesen; eine Ausnahme: Der erste Bericht vor jedem Abstimmen zeigte schon die Baseline der Blindsätze (Stapel 56 % bei ±1).\n\n"
        text += "Seit der Lückenbehandlung werden Empfangsabstände über 0,5 s und explizite Abrisse getrennt ausgewertet. Hintergrund-Bündelung lässt sich anhand der Empfangszeiten nicht sicher von fehlenden Paketen unterscheiden. Solche Sätze bleiben unsicher; auch zuvor richtige Zahlen können sich ändern. Schwellen und Profile wurden unverändert gelassen.\n\n"
        text += tabelle("Abstimmung", zeilen.filter { $0.gruppe == .abstimmen })
        text += tabelle("Blindprüfung (nur Arten mit eingefrorenen Parametern: \(blindFuer.map(\.rawValue).sorted().joined(separator: ", ").isEmpty ? "keine" : blindFuer.map(\.rawValue).sorted().joined(separator: ", ")))", zeilen.filter { $0.gruppe == .blind })
        text += tabelle("Früher abgestimmt (Kurzhantel 16.10., nur Regressionsschutz)", zeilen.filter { $0.gruppe == .frueherAbgestimmt })
        let gegenprobe = zeilen.filter { $0.gruppe == .gegenprobe }
        if !gegenprobe.isEmpty {
            text += tabelle("Gegenprobe 26.10. – aktuell neu berechnet", gegenprobe)
            let gespeichert = gegenprobe.map { z in
                TaktZeile(ordner: z.ordner, art: z.art, wahr: z.wahr, gezaehlt: z.gespeichert, gruppe: z.gruppe)
            }
            text += tabelle("Gegenprobe 26.10. – unverändert gespeicherte App-Ergebnisse", gespeichert)
            text += "Tim hat alle 27 Labels unabhängig mitgezählt und bestätigt. Diese Einheit wurde nicht zur Profilabstimmung verwendet. Die Lückenbehandlung wurde nach Sichtung der Einheit geändert: der neue Replay ist eine Regression, keine unangesehene Blindprüfung.\n\n"
            text += "| Ordner | Art | bestätigt | App gespeichert | Replay aktuell | unsicher |\n|---|---|---|---|---|---|\n"
            for z in gegenprobe {
                text += "| \(z.ordner) | \(z.art.rawValue) | \(z.wahr) | \(z.gespeichert.map(String.init) ?? "–") | \(z.gezaehlt.map(String.init) ?? "–") | \(z.unsicher?.rawValue ?? "–") |\n"
            }
            text += "\n"
        }
        text += "### Sätze außerhalb ±1\n\n| Ordner | Art | Gruppe | wahr | gezählt |\n|---|---|---|---|---|\n"
        for z in zeilen where !(z.gezaehlt.map { abs($0 - z.wahr) <= 1 } ?? false) {
            text += "| \(z.ordner) | \(z.art.rawValue) | \(z.gruppe.rawValue) | \(z.wahr) | \(z.gezaehlt.map(String.init) ?? "–") |\n"
        }
        return text
    }
}
