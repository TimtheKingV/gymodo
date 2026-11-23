import Foundation
@testable import Sensorik

/// Eine Aufnahme, live durch den `Lageschaetzer` gespielt und mit dem
/// nachtraeglichen `Lagebezug` verglichen, alles im aktiven Teil des Bezugs.
struct TempoZeile {
    let ordner: String; let art: Befestigungsart
    let verzoegerungMs: Double      // Verschiebung mit der groessten Kreuzkorrelation im aktiven Teil
    let abweichung: Double          // Mittel von |live − bezug| im aktiven Teil, unverschoben
    let abweichungSicher: Double?   // dasselbe nur ueber sichere Messwerte; nil ohne sichere
    let ausreisser: Bool            // die unbegrenzte Schaetzung laenger als eine Periode ausserhalb −0,25…1,25
    let sicherAnteil: Double        // Anteil der Messwerte im aktiven Teil mit `sicher`
    let wiederholungsfehler: Double // |Umkehrpunkte / 2 − repsWahr| ueber die ganze Aufnahme
    var quelle: Schwerkraftquelle = .ruhe // Live-Lauf und Bezug mit derselben Schwerkraft
    var teil: TempoBericht.Teil { TempoBericht.teil(ordner) }
}

/// Mediane einer Art. Die ersten vier Felder sind das Tor der Spec, der Rest dient
/// `tragfaehig` und der Anzeige.
struct TempoTor: Equatable {
    var saetze: Int; var verzoegerungMs: Double; var abweichung: Double; var ausreisser: Int
    var verzoegerungBetragMs = 0.0
    var abweichungSicher: Double? = nil
    var sicherAnteil = 0.0
    var wiederholungsfehler = 0.0
}

/// Guetetor des Tempo-Modus (Tempo-Spec 6.4).
enum TempoBericht {
    static let verzoegerungMaxMs = 150.0
    static let abweichungMax = 0.15
    static let grenzen = -0.25...1.25
    static let arten: [Befestigungsart] = [.stapel, .kurzhantel, .langhantel]
    static let mindestWiederholungen = 5
    static let mindestMesswerte = 300
    /// Vorschlag `tragfaehig`: so viel sicher und so nah an der wahren Zahl der Wiederholungen.
    static let sicherMin = 0.8
    static let wiederholungsfehlerMax = 1.0
    /// Ein Pruefteil mit weniger Saetzen traegt keine Aussage und wird im Bericht gewarnt.
    static let mindestPruefsaetze = 5

    /// Rueckhalt: Konstanten werden nur an der Abstimmung gewaehlt, die Pruefung wird gelesen.
    enum Teil: String, CaseIterable { case abstimmung = "Abstimmung", pruefung = "Prüfung" }
    /// Erste Aufnahme der Pruefung (Datum im Ordnernamen JJJJ-MM-TT-…).
    static let pruefungAb = "2026-11-01"

    static func teil(_ ordner: String) -> Teil {
        String(ordner.prefix(10)) < pruefungAb ? .abstimmung : .pruefung
    }

    /// Eine ausgewaehlte Aufnahme, einmal gelesen fuer alle Quellen.
    struct Aufnahme { let ordner: String; let art: Befestigungsart; let repsWahr: Int
                      let werte: [SensorMesswert]; let rateHz: Double }

    /// Auswahl wie tools/sensorik-sim/tempo_nachrechnung.py: Art Stapel, Kurz- oder
    /// Langhantel, `repsWahr >= 5`, ohne Luecke (weder Zeile noch in der Statistik),
    /// mindestens 300 Messwerte.
    static func aufnahmen() throws -> [Aufnahme] {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        var ergebnis: [Aufnahme] = []
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
            ergebnis.append(Aufnahme(ordner: name, art: art, repsWahr: wahr, werte: werte,
                                     rateHz: Double(datei.sensor.rateSollHz)))
        }
        return ergebnis
    }

    /// Der Schaetzer laeuft ohne gemerkten Umfang; Live-Lauf und Bezug mit `quelle`.
    static func zeilen(_ aufnahmen: [Aufnahme], quelle: Schwerkraftquelle = .ruhe) -> [TempoZeile] {
        aufnahmen.compactMap {
            zeile(ordner: $0.ordner, art: $0.art, werte: $0.werte, rateHz: $0.rateHz, repsWahr: $0.repsWahr, quelle: quelle)
        }
    }

    /// Spielt die Messwerte live durch den Schaetzer und misst gegen den Bezug; nil ohne Bezug.
    static func zeile(ordner: String, art: Befestigungsart, werte: [SensorMesswert], rateHz: Double,
                      repsWahr: Int, quelle: Schwerkraftquelle = .ruhe) -> TempoZeile? {
        guard let bezug = Lagebezug.berechne(werte, rateHz: rateHz, schwerkraft: quelle) else { return nil }
        var schaetzer = Lageschaetzer(rateHz: rateHz, schwerkraft: quelle)
        var live: [Lage] = [], roh: [Double] = []
        live.reserveCapacity(werte.count); roh.reserveCapacity(werte.count)
        for m in werte {
            live.append(schaetzer.verarbeite(m))
            roh.append(schaetzer.rohlage)
        }
        let a = bezug.aktiv
        let l = a.map { live[$0].lage }, b = a.map { bezug.lage[$0] }
        let abweichung = zip(l, b).reduce(0) { $0 + abs($1.0 - $1.1) } / Double(a.count)
        let sichere = a.filter { live[$0].sicher }
        let abweichungSicher = sichere.isEmpty ? nil
            : sichere.reduce(0) { $0 + abs(live[$1].lage - bezug.lage[$1]) } / Double(sichere.count)
        var laengster = 0, lauf = 0
        for i in a {
            lauf = grenzen.contains(roh[i]) ? 0 : lauf + 1
            laengster = max(laengster, lauf)
        }
        return TempoZeile(
            ordner: ordner, art: art,
            verzoegerungMs: verzoegerungMs(live: l, bezug: b, rateHz: rateHz, hoechstens: min(1, bezug.periode / 2)),
            abweichung: abweichung, abweichungSicher: abweichungSicher,
            ausreisser: Double(laengster) > bezug.periode * rateHz,
            sicherAnteil: Double(sichere.count) / Double(a.count),
            wiederholungsfehler: abs(Double(schaetzer.umkehrpunkte.count) / 2 - Double(repsWahr)),
            quelle: quelle)
    }

    // MARK: - Winkel-Versuch

    /// B1: Winkel (°) zwischen der Richtung aus Roll/Pitch und der gemessenen
    /// Beschleunigung, je ruhendem Messwert, nach Art. Ruhend: Betrag auf 0,01 g
    /// bei 1 g, Drehrate unter 5 °/s, seit mindestens 0,5 s.
    static func ruhewinkelfehler(_ aufnahmen: [Aufnahme]) -> [Befestigungsart: [Double]] {
        var fehler: [Befestigungsart: [Double]] = [:]
        for a in aufnahmen {
            let ruheVor = Int((0.5 * a.rateHz).rounded())
            var ruhig = 0
            for m in a.werte {
                let b = m.beschleunigung, w = m.drehrate
                let betrag = (b.x * b.x + b.y * b.y + b.z * b.z).squareRoot()
                ruhig = abs(betrag - 1) < 0.01 && (w.x * w.x + w.y * w.y + w.z * w.z).squareRoot() < 5 ? ruhig + 1 : 0
                guard ruhig >= ruheVor else { continue }
                let r = Schwerkraftquelle.richtung(winkel: m.winkel)
                let cosinus = (b.x * r.x + b.y * r.y + b.z * r.z) / betrag
                fehler[a.art, default: []].append(acos(min(max(cosinus, -1), 1)) * 180 / .pi)
            }
        }
        return fehler
    }

    /// B3: Mittel von |Bezug `.ruhe` − Bezug `.winkel`| ueber den gemeinsamen aktiven
    /// Teil; `.some(nil)`, wenn beide Bezuege verschiedene Abschnitte als aktiv nehmen,
    /// nil ohne einen der Bezuege.
    static func bezugUnterschied(_ a: Aufnahme) -> Double?? {
        guard let r = Lagebezug.berechne(a.werte, rateHz: a.rateHz, schwerkraft: .ruhe),
              let w = Lagebezug.berechne(a.werte, rateHz: a.rateHz, schwerkraft: .winkel) else { return nil }
        let von = max(r.aktiv.lowerBound, w.aktiv.lowerBound), bis = min(r.aktiv.upperBound, w.aktiv.upperBound)
        guard bis > von else { return .some(nil) }
        return (von..<bis).reduce(0) { $0 + abs(r.lage[$1] - w.lage[$1]) } / Double(bis - von)
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
        let sicher = z.compactMap(\.abweichungSicher)
        return TempoTor(saetze: z.count, verzoegerungMs: median(z.map(\.verzoegerungMs)),
                        abweichung: median(z.map(\.abweichung)), ausreisser: z.filter(\.ausreisser).count,
                        verzoegerungBetragMs: median(z.map { abs($0.verzoegerungMs) }),
                        abweichungSicher: sicher.isEmpty ? nil : median(sicher),
                        sicherAnteil: median(z.map(\.sicherAnteil)),
                        wiederholungsfehler: median(z.map(\.wiederholungsfehler)))
    }

    /// Das Tor der Spec, wörtlich: drei Schwellen; die Verzoegerung im Betrag.
    static func torErreicht(_ t: TempoTor) -> Bool {
        t.saetze > 0 && abs(t.verzoegerungMs) <= verzoegerungMaxMs && t.abweichung <= abweichungMax && t.ausreisser == 0
    }

    /// Vorschlag, nicht Spec: Tor erreicht, die Lage traegt meist (sicher im Median
    /// ≥ 0,8) und die Umkehrpunkte treffen die wahre Zahl der Wiederholungen (Median ≤ 1).
    static func tragfaehig(_ t: TempoTor) -> Bool {
        torErreicht(t) && t.sicherAnteil >= sicherMin && t.wiederholungsfehler <= wiederholungsfehlerMax
    }

    private static let posix = Locale(identifier: "en_US_POSIX")
    static func zahl(_ x: Double, _ stellen: Int) -> String { String(format: "%.\(stellen)f", locale: posix, x) }
    static func pct(_ x: Double) -> String { String(format: "%.0f %%", locale: posix, x * 100) }

    /// Tabelle je Teil: eine Zeile je Art, darunter Warnungen fuer zu kleine Pruefteile.
    static func tabellen(_ zeilen: [TempoZeile]) -> String {
        var text = ""
        for teil in Teil.allCases {
            let z = zeilen.filter { $0.teil == teil }
            text += "\n### \(teil.rawValue) (\(teil == .abstimmung ? "vor" : "ab") \(pruefungAb))\n\n"
                + "| Art | Sätze | Verzögerung | \\|Verzögerung\\| | Abweichung | Abweichung sicher | außerhalb (roh) "
                + "| sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |\n"
                + "|---|---|---|---|---|---|---|---|---|---|---|\n"
            var warnungen: [String] = []
            for art in arten {
                let t = tor(z, art: art)
                if teil == .pruefung, t.saetze < mindestPruefsaetze {
                    warnungen.append("**Warnung:** \(art.rawValue) hat in der Prüfung nur \(t.saetze) Sätze "
                        + "(unter \(mindestPruefsaetze)); daraus folgt keine Aussage.")
                }
                guard t.saetze > 0 else {
                    text += "| \(art.rawValue) | 0 | – | – | – | – | – | – | – | – | – |\n"
                    continue
                }
                text += "| \(art.rawValue) | \(t.saetze) | \(zahl(t.verzoegerungMs, 0)) ms | \(zahl(t.verzoegerungBetragMs, 0)) ms "
                    + "| \(zahl(t.abweichung, 3)) | \(t.abweichungSicher.map { zahl($0, 3) } ?? "–") | \(t.ausreisser) "
                    + "| \(pct(t.sicherAnteil)) | \(zahl(t.wiederholungsfehler, 1)) | \(torErreicht(t) ? "ja" : "nein") "
                    + "| \(tragfaehig(t) ? "ja" : "nein") |\n"
            }
            if !warnungen.isEmpty { text += "\n" + warnungen.joined(separator: "\n") + "\n" }
        }
        return text
    }

    /// Zusatzangaben des Winkel-Versuchs: Winkelfehler in Ruhe je Art (B1) und
    /// Unterschied Bezug `.ruhe` gegen `.winkel` je Aufnahme (B3).
    struct Versuch {
        var ruhewinkel: [Befestigungsart: [Double]] = [:]
        var bezugUnterschied: [(ordner: String, art: Befestigungsart, wert: Double?)] = []
    }

    static func titel(_ q: Schwerkraftquelle) -> String {
        switch q {
        case .ruhe: "Schwerkraft aus der Ruhe (`.ruhe`, bisher)"
        case .winkel: "Schwerkraft aus Roll/Pitch je Messwert (`.winkel`)"
        case .drehrate: "Schwerkraft mit der Drehrate fortgeschrieben (`.drehrate`)"
        }
    }

    /// `zeilen` aller Quellen; je Quelle ein Abschnitt in der Reihenfolge `.ruhe`, `.winkel`, `.drehrate`.
    static func markdown(_ zeilen: [TempoZeile], versuch: Versuch = Versuch()) throws -> String {
        // Datum der juengsten Aufnahme aus dem Ordnernamen (JJJJ-MM-TT-…), nicht heute: der Bericht bleibt gleich.
        let stand = zeilen.map { String($0.ordner.prefix(10)) }.max() ?? "–"
        var text = try WinkelBericht.markdown(WinkelBericht.paare()) + """
            # Tempobericht Lageschätzung

            Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
            Stand: Aufnahmen bis \(stand). Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung \
            aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.

            Es gibt keine gemessene Wahrheit der Lage, nur die Übereinstimmung mit dieser nachträglichen Rechnung. \
            Die Hilfslage im unsicheren Zustand ist dem Bezug nachgebaut, die Abweichung ist deshalb über sichere \
            Messwerte („Abweichung sicher“) aussagekräftiger.

            Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ \(mindestWiederholungen), ohne Lücke, ≥ \(mindestMesswerte) Messwerte.
            Rückhalt: Abstimmung = Aufnahmen vor \(pruefungAb), Prüfung = ab \(pruefungAb). Konstanten werden nur an der \
            Abstimmung gewählt; die Prüfung wird gelesen, nicht optimiert.
            Tor je Art (Tempo-Spec 6.4): Betrag der Verzögerung im Median ≤ \(zahl(verzoegerungMaxMs, 0)) ms, Abweichung im \
            Median ≤ \(zahl(abweichungMax, 2)) des Hubs, kein Satz, dessen unbegrenzte Schätzung länger als eine Wiederholung \
            außerhalb −0,25…1,25 liegt („außerhalb (roh)“). „tragfähig“ ist ein Vorschlag, nicht die Spec: Tor erreicht und \
            sicher im Median ≥ \(pct(sicherMin)) und Wdh. gegen Wahrheit im Median ≤ \(zahl(wiederholungsfehlerMax, 0)).
            „Wdh. gegen Wahrheit“ (Median von |Umkehrpunkte/2 − `repsWahr`|) ist die einzige Spalte mit echter Wahrheit.
            Verzögerung: Median der Verschiebung mit der größten Korrelation (positiv = live später); |Verzögerung|: Median der Beträge. \
            Alle Spalten sind Mediane über die Sätze der Art, „außerhalb (roh)“ ist eine Anzahl.
            Winkel-Versuch (Task 5b): je Schwerkraftquelle ein Abschnitt; Live-Lauf und Bezug nutzen dieselbe Quelle.

            """
        if !versuch.ruhewinkel.isEmpty {
            text += "\n## Winkel in Ruhe\n\n"
                + "Winkel zwischen der Richtung aus Roll/Pitch und der gemessenen Beschleunigung an ruhenden Messwerten "
                + "(Betrag auf 0,01 g bei 1 g, Drehrate unter 5 °/s, seit 0,5 s). Über etwa 3° trüge `.winkel` nicht.\n\n"
                + "| Art | ruhende Messwerte | Winkelfehler (Median) |\n|---|---|---|\n"
            for art in arten {
                guard let f = versuch.ruhewinkel[art], !f.isEmpty else { continue }
                text += "| \(art.rawValue) | \(f.count) | \(zahl(median(f), 2))° |\n"
            }
        }
        if !versuch.bezugUnterschied.isEmpty {
            text += "\n## Bezug `.ruhe` gegen Bezug `.winkel`\n\n"
                + "Mittel von |Bezug `.ruhe` − Bezug `.winkel`| im gemeinsamen aktiven Teil, Median über die Sätze: "
                + "so stark verschiebt die Schwerkraft aus der Ruhe den Bezug selbst.\n\n"
                + "„verschiedener Abschnitt“: Die beiden Bezüge nehmen ganz verschiedene Teile der Aufnahme als aktiv.\n\n"
                + "| Art | Sätze | Unterschied (Median) | Unterschied (größter) | verschiedener Abschnitt |\n|---|---|---|---|---|\n"
            for art in arten {
                let alle = versuch.bezugUnterschied.filter { $0.art == art }
                let u = alle.compactMap(\.wert)
                guard !alle.isEmpty else { continue }
                text += "| \(art.rawValue) | \(u.count) | \(u.isEmpty ? "–" : zahl(median(u), 3)) "
                    + "| \(u.isEmpty ? "–" : zahl(u.max() ?? 0, 3)) | \(alle.count - u.count) |\n"
            }
        }
        for quelle in Schwerkraftquelle.allCases {
            let zq = zeilen.filter { $0.quelle == quelle }
            guard !zq.isEmpty else { continue }
            text += "\n## \(titel(quelle))\n" + tabellen(zq)
            text += schlechteste(zq)
        }
        return text
    }

    private static func schlechteste(_ zeilen: [TempoZeile]) -> String {
        var text = ""
        for art in arten {
            let z = zeilen.filter { $0.art == art }
            guard !z.isEmpty else { continue }
            let schlechteste = z.sorted { ($0.abweichung, $1.ordner) > ($1.abweichung, $0.ordner) }.prefix(10)
            text += "\n#### \(art.rawValue): die zehn schlechtesten Sätze\n\n"
                + "| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |\n"
                + "|---|---|---|---|---|---|---|---|\n"
            for e in schlechteste {
                text += "| \(e.ordner) | \(e.teil.rawValue) | \(zahl(e.verzoegerungMs, 0)) ms | \(zahl(e.abweichung, 3)) "
                    + "| \(e.abweichungSicher.map { zahl($0, 3) } ?? "–") | \(e.ausreisser ? "ja" : "–") "
                    + "| \(pct(e.sicherAnteil)) | \(zahl(e.wiederholungsfehler, 1)) |\n"
            }
        }
        return text
    }
}
