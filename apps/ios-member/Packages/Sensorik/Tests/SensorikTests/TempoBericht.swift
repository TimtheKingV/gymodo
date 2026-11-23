import Foundation
@testable import Sensorik

/// Eine Aufnahme, live durch den `Lageschaetzer` gespielt und mit dem
/// nachtraeglichen `Lagebezug` verglichen, alles im aktiven Teil des Bezugs.
struct TempoZeile {
    let ordner: String; let art: Befestigungsart
    let verzoegerungMs: Double      // Verschiebung mit der groessten Kreuzkorrelation im aktiven Teil
    let abweichung: Double          // Mittel von |live − bezug| im aktiven Teil, unverschoben
    let ausreisser: Bool            // laenger als eine Periode ausserhalb −0,25…1,25
    let sicherAnteil: Double        // Anteil der Messwerte im aktiven Teil mit `sicher`; nur zur Information
}

struct TempoTor: Equatable { let saetze: Int; let verzoegerungMs: Double; let abweichung: Double; let ausreisser: Int }

/// Guetetor des Tempo-Modus (Tempo-Spec 6.4).
enum TempoBericht {
    static let verzoegerungMaxMs = 150.0
    static let abweichungMax = 0.15
    static let grenzen = -0.25...1.25
    static let arten: [Befestigungsart] = [.stapel, .kurzhantel, .langhantel]
    static let mindestWiederholungen = 5
    static let mindestMesswerte = 300

    /// Auswahl wie tools/sensorik-sim/tempo_nachrechnung.py: Art Stapel, Kurz- oder
    /// Langhantel, `repsWahr >= 5`, ohne Luecke (weder Zeile noch in der Statistik),
    /// mindestens 300 Messwerte. Der Schaetzer laeuft ohne gemerkten Umfang.
    static func zeilen() throws -> [TempoZeile] {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        var zeilen: [TempoZeile] = []
        for (name, eintrag) in k.aufnahmen.sorted(by: { $0.key < $1.key }) {
            guard let art = eintrag.befestigungsart, arten.contains(art),
                  let wahr = eintrag.repsWahr, wahr >= mindestWiederholungen else { continue }
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            guard fm.fileExists(atPath: ordner.appendingPathComponent("messwerte.csv").path) else { continue }
            let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            // Nur ausdrueckliche Luecken zaehlen, wie im Skript; ein spaet zugestelltes
            // Buendel (Zeitsprung ohne Luecken-Zeile) verliert keine Messwerte.
            let hatLueckenZeile = eintraege.contains { if case .luecke = $0 { true } else { false } }
            guard datei.statistik.luecken == 0, !hatLueckenZeile else { continue }
            let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
            guard werte.count >= mindestMesswerte else { continue }
            let rate = Double(datei.sensor.rateSollHz)
            guard let bezug = Lagebezug.berechne(werte, rateHz: rate) else { continue }
            var schaetzer = Lageschaetzer(rateHz: rate)
            let live = werte.map { schaetzer.verarbeite($0) }
            zeilen.append(zeile(ordner: name, art: art, live: live, bezug: bezug, rateHz: rate))
        }
        return zeilen
    }

    static func zeile(ordner: String, art: Befestigungsart, live: [Lage], bezug: Lagebezug.Ergebnis,
                      rateHz: Double) -> TempoZeile {
        let a = bezug.aktiv
        let l = a.map { live[$0].lage }, b = a.map { bezug.lage[$0] }
        let abweichung = zip(l, b).reduce(0) { $0 + abs($1.0 - $1.1) } / Double(a.count)
        var laengster = 0, lauf = 0
        for x in l {
            lauf = grenzen.contains(x) ? 0 : lauf + 1
            laengster = max(laengster, lauf)
        }
        return TempoZeile(
            ordner: ordner, art: art,
            verzoegerungMs: verzoegerungMs(live: l, bezug: b, rateHz: rateHz, hoechstens: min(1, bezug.periode / 2)),
            abweichung: abweichung,
            ausreisser: Double(laengster) > bezug.periode * rateHz,
            sicherAnteil: Double(a.filter { live[$0].sicher }.count) / Double(a.count))
    }

    /// Verschiebung (ms) mit der groessten Korrelation von `live` gegen `bezug`,
    /// positiv wenn `live` spaeter kommt. Gesucht wird bis `hoechstens` Sekunden in
    /// beide Richtungen; die Korrelation ist je Verschiebung ueber den
    /// ueberlappenden Teil normiert (Pearson), bei Gleichstand gewinnt die kleinere.
    static func verzoegerungMs(live: [Double], bezug: [Double], rateHz: Double, hoechstens: Double = 1) -> Double {
        let n = min(live.count, bezug.count)
        let grenze = min(Int(hoechstens * rateHz), n / 2)
        var bester = 0, besterWert = -Double.infinity
        for betrag in 0...max(0, grenze) {
            for k in betrag == 0 ? [0] : [betrag, -betrag] {
                // live[i + k] gegen bezug[i]
                let von = max(0, -k), bis = min(n, n - k)
                guard bis - von >= 2 else { continue }
                let x = (von..<bis).map { live[$0 + k] }, y = Array(bezug[von..<bis])
                let r = korrelation(x, y)
                if r > besterWert + 1e-12 { besterWert = r; bester = k }
            }
        }
        return Double(bester) / rateHz * 1000
    }

    private static func korrelation(_ x: [Double], _ y: [Double]) -> Double {
        let mx = x.reduce(0, +) / Double(x.count), my = y.reduce(0, +) / Double(y.count)
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for (a, b) in zip(x, y) { sxy += (a - mx) * (b - my); sxx += (a - mx) * (a - mx); syy += (b - my) * (b - my) }
        guard sxx > 0, syy > 0 else { return -1 }
        return sxy / (sxx * syy).squareRoot()
    }

    static func median(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        let s = x.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// Mediane ueber die Aufnahmen der Art.
    static func tor(_ zeilen: [TempoZeile], art: Befestigungsart) -> TempoTor {
        let z = zeilen.filter { $0.art == art }
        return TempoTor(saetze: z.count, verzoegerungMs: median(z.map(\.verzoegerungMs)),
                        abweichung: median(z.map(\.abweichung)), ausreisser: z.filter(\.ausreisser).count)
    }

    static func torErreicht(_ t: TempoTor) -> Bool {
        t.saetze > 0 && t.verzoegerungMs <= verzoegerungMaxMs && t.abweichung <= abweichungMax && t.ausreisser == 0
    }

    static func markdown(_ zeilen: [TempoZeile]) -> String {
        let posix = Locale(identifier: "en_US_POSIX")
        func zahl(_ x: Double, _ stellen: Int) -> String { String(format: "%.\(stellen)f", locale: posix, x) }
        func pct(_ x: Double) -> String { String(format: "%.0f %%", locale: posix, x * 100) }
        // Datum der juengsten Aufnahme aus dem Ordnernamen (JJJJ-MM-TT-…), nicht heute: der Bericht bleibt gleich.
        let stand = zeilen.map { String($0.ordner.prefix(10)) }.max() ?? "–"
        var text = """
            # Tempobericht Lageschätzung

            Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
            Stand: Aufnahmen bis \(stand). Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung \
            aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.
            Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ \(mindestWiederholungen), ohne Lücke, ≥ \(mindestMesswerte) Messwerte.
            Tor je Art (Tempo-Spec 6.4): Verzögerung im Median ≤ \(zahl(verzoegerungMaxMs, 0)) ms, Abweichung im Median ≤ \
            \(zahl(abweichungMax, 2)) des Hubs, kein Satz länger als eine Wiederholung außerhalb −0,25…1,25. \
            „sicher“ (Median des Anteils sicherer Messwerte) zählt nicht zum Tor.

            | Art | Sätze | Verzögerung (Median) | Abweichung (Median) | außerhalb | sicher (Median) | Tor erreicht |
            |---|---|---|---|---|---|---|

            """
        for art in arten {
            let t = tor(zeilen, art: art)
            guard t.saetze > 0 else { continue }
            let sicher = median(zeilen.filter { $0.art == art }.map(\.sicherAnteil))
            text += "| \(art.rawValue) | \(t.saetze) | \(zahl(t.verzoegerungMs, 0)) ms | \(zahl(t.abweichung, 3)) | "
                + "\(t.ausreisser) | \(pct(sicher)) | \(torErreicht(t) ? "ja" : "nein") |\n"
        }
        for art in arten {
            let z = zeilen.filter { $0.art == art }
            guard !z.isEmpty else { continue }
            let schlechteste = z.sorted { ($0.abweichung, $1.ordner) > ($1.abweichung, $0.ordner) }.prefix(10)
            text += "\n## \(art.rawValue): die zehn schlechtesten Sätze\n\n"
                + "| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |\n|---|---|---|---|---|\n"
            for e in schlechteste {
                text += "| \(e.ordner) | \(zahl(e.verzoegerungMs, 0)) ms | \(zahl(e.abweichung, 3)) | "
                    + "\(e.ausreisser ? "ja" : "–") | \(pct(e.sicherAnteil)) |\n"
            }
        }
        return text
    }
}
