import Foundation
@testable import Sensorik

/// Ein Satz, durch die `Winkellage` gespielt und gegen die bekannte Zahl der Wiederholungen gemessen.
struct WinkelZeile {
    let ordner: String; let art: Befestigungsart?; let pruefung: Bool
    let repsWahr: Int
    let hubGrad: Double            // gemerkter Hub am Satzende, 0 wenn keiner
    let wdhFehler: Double          // |Umkehrpunkte / 2 − repsWahr|
    let sicherAnteil: Double       // Anteil sicherer Messwerte zwischen dem 3. und dem letzten Umkehrpunkt
    let hubStreuung: Double        // Standardabweichung / Mittel der Hube je Wiederholung
    let groessterSprung: Double    // groesster Schritt der Lage zwischen zwei Messwerten
    var uebung = ""                // kontext.exerciseName
    var luecken = 0                // Zahl der Luecken-Zeilen der Aufnahme
    var erkannt = 0.0              // Umkehrpunkte / 2
    var losT: Double?              // Zeit des Messwerts, vor dem `los()` kam; nil ohne Start
}

struct WinkelTor: Equatable { let saetze: Int; let wdhFehler: Double; let sicherAnteil: Double; let spruenge: Int }

/// Eine Aufnahme in beiden Laeufen: ohne Start und mit Start (Los-Marke oder nachtraeglich bestimmt).
struct WinkelPaar {
    let ohneStart: WinkelZeile
    let mitStart: WinkelZeile
    /// Die Aufnahme traegt eine Zeile `# los <t>`; `mitStart` laeuft dann ueber diese Marke.
    let mitLosMarke: Bool
}

/// Der Winkel ist eine direkte Messung der Lage; deshalb wird er gegen die gezaehlten Wiederholungen geprueft,
/// nicht gegen eine nachtraegliche Rechnung.
enum WinkelBericht {
    static let mindesthubGrad = Winkellage.mindesthubGrad
    static let sprungMax = 0.2
    static let wdhFehlerMax = 1.0
    static let sicherMin = 0.9
    static let mindestWiederholungen = 5
    /// Rand des Satzbands fuer den nachtraeglichen Start, in Grad.
    static let satzbandRandGrad = 15.0

    static func geeignet(_ z: WinkelZeile) -> Bool { z.hubGrad >= mindesthubGrad }

    static func tragfaehig(_ t: WinkelTor) -> Bool {
        t.saetze > 0 && t.wdhFehler <= wdhFehlerMax && t.sicherAnteil >= sicherMin && t.spruenge == 0
    }

    /// Mediane ueber die geeigneten Saetze; `spruenge` zaehlt die geeigneten Saetze mit Sprung ueber 0,2.
    static func tor(_ zeilen: [WinkelZeile]) -> WinkelTor {
        let g = zeilen.filter(geeignet)
        return WinkelTor(saetze: g.count, wdhFehler: TempoBericht.median(g.map(\.wdhFehler)),
                         sicherAnteil: TempoBericht.median(g.map(\.sicherAnteil)),
                         spruenge: g.filter { $0.groessterSprung > sprungMax }.count)
    }

    // MARK: - Eine Aufnahme

    /// Spielt die Eintraege live (ohne gemerkten Wert) durch die `Winkellage`; Luecken-Zeilen gehen als `luecke` hinein.
    /// Mit `losBei` wartet die `Winkellage` auf den Start; `los()` kommt vor dem ersten Messwert mit `t >= losBei`.
    static func zeile(ordner: String, art: Befestigungsart?, pruefung: Bool, repsWahr: Int,
                      eintraege: [SensorAufnahmeLeser.Eintrag], rateHz: Double, uebung: String = "",
                      losBei: Double? = nil) -> WinkelZeile {
        var schaetzer = Winkellage(rateHz: rateHz, wartetAufLos: losBei != nil)
        var lagen: [Lage] = [], winkel: [Double] = [], luecken = 0
        var losT: Double?
        for e in eintraege {
            switch e {
            case .messwert(let m):
                if let losBei, losT == nil, m.t >= losBei { schaetzer.los(); losT = m.t }
                lagen.append(schaetzer.verarbeite(m)); winkel.append(schaetzer.drehwinkelGrad)
            case .luecke(let von, let bis): schaetzer.luecke(von: von, bis: bis); luecken += 1
            case .rate, .marke: break
            }
        }
        let punkte = schaetzer.umkehrpunkte
        var sprung = 0.0
        for i in lagen.indices.dropFirst() { sprung = max(sprung, abs(lagen[i].lage - lagen[i - 1].lage)) }

        // Sicherer Anteil zwischen dem dritten und dem letzten Umkehrpunkt (Zeit auf den Messwerten).
        var sicher = 0.0
        if punkte.count >= 3 {
            let von = punkte[2].t, bis = punkte[punkte.count - 1].t
            let im = lagen.filter { $0.t >= von && $0.t <= bis }
            if !im.isEmpty { sicher = Double(im.filter(\.sicher).count) / Double(im.count) }
        }

        let hub = schaetzer.gemerkt?.hubGrad ?? 0
        let erkannt = Double(punkte.count) / 2
        return WinkelZeile(ordner: ordner, art: art, pruefung: pruefung, repsWahr: repsWahr, hubGrad: hub,
                           wdhFehler: abs(erkannt - Double(repsWahr)), sicherAnteil: sicher,
                           hubStreuung: streuung(punkte, lagen: lagen, winkel: winkel),
                           groessterSprung: sprung, uebung: uebung, luecken: luecken, erkannt: erkannt, losT: losT)
    }

    /// Hub je Wiederholung = Drehwinkel φ der `Winkellage` (entfaltet) vom oberen Umkehrpunkt zum folgenden
    /// unteren; Standardabweichung / Mittel. Unter zwei Hueben 0.
    private static func streuung(_ punkte: [Umkehrpunkt], lagen: [Lage], winkel: [Double]) -> Double {
        guard winkel.count == lagen.count, !winkel.isEmpty else { return 0 }
        func winkelBei(_ t: TimeInterval) -> Double? {
            lagen.firstIndex { $0.t >= t }.map { winkel[$0] }
        }
        var hube: [Double] = []
        for (i, p) in punkte.enumerated() where p.oben && i + 1 < punkte.count && !punkte[i + 1].oben {
            if let a = winkelBei(p.t), let b = winkelBei(punkte[i + 1].t) { hube.append(abs(a - b)) }
        }
        guard hube.count >= 2 else { return 0 }
        let mittel = hube.reduce(0, +) / Double(hube.count)
        guard mittel > 0 else { return 0 }
        let varianz = hube.reduce(0) { $0 + ($1 - mittel) * ($1 - mittel) } / Double(hube.count)
        return varianz.squareRoot() / mittel
    }

    // MARK: - Start

    /// Zeit aus der Zeile `# los <t>` der CSV, falls vorhanden (der `SensorAufnahmeLeser` ueberliest sie).
    static func losMarke(csv: String) -> Double? {
        for zeile in csv.split(whereSeparator: \.isNewline) where zeile.hasPrefix("# los ") {
            return Double(zeile.dropFirst("# los ".count).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Nachtraeglicher Start mit Wissen ueber den ganzen Satz. Satzband: normiertes Mittel der Schwerkraftrichtung ĝ
    /// ueber die mittlere Haelfte der Aufnahme (nach der Zeit), Radius = groesster Abstand dort plus `satzbandRandGrad`.
    /// Aktiver Teil: der zusammenhaengende Abschnitt im Satzband, der die mittlere Haelfte enthaelt, rueckwaerts von
    /// ihrem Beginn verfolgt. `los()` kommt am Ende des ersten Stillstands (Kriterium der `Winkellage`: 0,5 s, 4°),
    /// der in den ersten 2 s dieses Abschnitts beginnt; ohne Stillstand dort (Aufnehmen bis in den Satz) am ersten
    /// Messwert des Abschnitts, an dem die Drehung unter 20 °/s faellt. Ergebnis: Zeit dieses Messwerts; nil ohne Messwerte.
    static func startNachtraeglich(_ eintraege: [SensorAufnahmeLeser.Eintrag], rateHz: Double) -> Double? {
        let messwerte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        guard !messwerte.isEmpty else { return nil }
        let g = messwerte.map { Winkellage.schwerkraft($0.winkel) }
        let n = g.count, mitte = (n / 4)..<max(n / 4 + 1, 3 * n / 4)
        let c = Winkellage.mittel(g[mitte])
        func abstand(_ v: Vektor3) -> Double { acos(min(max(Winkellage.punkt(v, c), -1), 1)) * 180 / .pi }
        let radius = mitte.map { abstand(g[$0]) }.max()! + satzbandRandGrad
        var a = mitte.lowerBound
        while a > 0, abstand(g[a - 1]) <= radius { a -= 1 }

        let halbe = Int(0.5 * rateHz), grenze = cos(4.0 * .pi / 180)
        func still(_ i: Int) -> Bool {
            guard i + 1 >= halbe, halbe > 0 else { return false }
            let w = g[(i + 1 - halbe)...i], m = Winkellage.mittel(w)
            return w.allSatisfy { Winkellage.punkt($0, m) >= grenze }
        }
        // Die erste halbe Sekunde kann noch nicht still heissen; gesucht wird ab ihrem Ende.
        let beginn = min(max(a, halbe - 1), n - 1)
        if let j = (beginn...min(n - 1, beginn + Int(2 * rateHz))).first(where: still) {
            var i = j
            while i + 1 < n, still(i + 1) { i += 1 }
            return messwerte[i].t
        }
        // Ohne Stillstand: der erste Messwert, an dem die Drehung unter 20 °/s faellt (Ende des Aufnehmens).
        let schritt = max(1, Int(0.1 * rateHz))
        func langsam(_ i: Int) -> Bool {
            guard i >= schritt else { return false }
            let grad = acos(min(max(Winkellage.punkt(g[i - schritt], g[i]), -1), 1)) * 180 / .pi
            return grad * rateHz / Double(schritt) < 20
        }
        return messwerte[(beginn..<n).first(where: langsam) ?? beginn].t
    }

    // MARK: - Alle Aufnahmen

    /// Alle Aufnahmen mit bekannter Wiederholungszahl >= 5, auch solche unter 40° Hub: (a) Ordner mit Eintrag in
    /// `korrekturen.json` und `repsWahr`, gleich welcher Art; (b) Ordner, deren `aufnahme.json` den Schluessel
    /// `tempo` traegt (Mac-Aufnahmen mit Metronom), dort gilt `label.reps`. Lueckenzeilen gehen an die `Winkellage`.
    /// Je Aufnahme zwei Laeufe: ohne Start und mit Start (Los-Marke, sonst `startNachtraeglich`).
    static func paare() throws -> [WinkelPaar] {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        var wahr: [String: Int] = [:]
        for (name, eintrag) in k.aufnahmen { if let r = eintrag.repsWahr, r >= mindestWiederholungen { wahr[name] = r } }
        let namen = try fm.contentsOfDirectory(atPath: Pfade.aufnahmen.path)
        for name in namen where wahr[name] == nil && k.aufnahmen[name] == nil {
            let json = Pfade.aufnahmen.appendingPathComponent(name).appendingPathComponent("aufnahme.json")
            guard let daten = try? Data(contentsOf: json),
                  let obj = try JSONSerialization.jsonObject(with: daten) as? [String: Any], obj["tempo"] != nil,
                  let label = obj["label"] as? [String: Any], let reps = label["reps"] as? Int,
                  reps >= mindestWiederholungen else { continue }
            wahr[name] = reps
        }
        var ergebnis: [WinkelPaar] = []
        for (name, reps) in wahr.sorted(by: { $0.key < $1.key }) {
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            let csvPfad = ordner.appendingPathComponent("messwerte.csv")
            guard fm.fileExists(atPath: csvPfad.path) else { continue }
            let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            let rate = Double(datei.sensor.rateSollHz)
            let marke = losMarke(csv: try String(contentsOf: csvPfad, encoding: .utf8))
            func lauf(_ losBei: Double?) -> WinkelZeile {
                zeile(ordner: name, art: datei.befestigungsart ?? k.aufnahmen[name]?.befestigungsart,
                      pruefung: TempoBericht.teil(name) == .pruefung, repsWahr: reps, eintraege: eintraege,
                      rateHz: rate, uebung: datei.kontext.exerciseName, losBei: losBei)
            }
            ergebnis.append(WinkelPaar(ohneStart: lauf(nil), mitStart: lauf(marke ?? startNachtraeglich(eintraege, rateHz: rate)),
                                       mitLosMarke: marke != nil))
        }
        return ergebnis
    }

    /// Die Laeufe ohne Start.
    static func zeilen() throws -> [WinkelZeile] { try paare().map(\.ohneStart) }

    // MARK: - Bericht

    private static func zahl(_ x: Double, _ stellen: Int) -> String { TempoBericht.zahl(x, stellen) }
    private static func artName(_ a: Befestigungsart?) -> String { a?.rawValue ?? "ohne Art" }
    private static func artRang(_ a: Befestigungsart?) -> Int { a.flatMap { Befestigungsart.allCases.firstIndex(of: $0) } ?? Int.max }
    /// Befestigungsarten in der Reihenfolge der Deklaration, „ohne Art“ zuletzt.
    private static let artenGeordnet: [Befestigungsart?] = Befestigungsart.allCases.map { Optional($0) } + [nil]

    /// Je Befestigungsart (auch „ohne Art“) und Uebungsname: Aufnahmen und wie viele davon 40° erreichen.
    static func woDerWinkelTraegt(_ zeilen: [WinkelZeile]) -> String {
        var zaehler: [String: (art: Befestigungsart?, uebung: String, alle: Int, geeignet: Int)] = [:]
        for z in zeilen {
            let schluessel = artName(z.art) + "\u{0}" + z.uebung
            var e = zaehler[schluessel] ?? (z.art, z.uebung, 0, 0)
            e.alle += 1; if geeignet(z) { e.geeignet += 1 }
            zaehler[schluessel] = e
        }
        let sortiert = zaehler.values.sorted {
            (artRang($0.art), -$0.alle, $0.uebung) < (artRang($1.art), -$1.alle, $1.uebung)
        }
        var text = "| Art | Übung | Aufnahmen | davon ab 40° |\n|---|---|---|---|\n"
        for e in sortiert { text += "| \(artName(e.art)) | \(e.uebung.isEmpty ? "–" : e.uebung) | \(e.alle) | \(e.geeignet) |\n" }
        return text
    }

    /// Kennzahlen eines Laufs als Zellen: geeignet, Hub, Wdh.-Fehler, Sicher, Streuung, Sprung, tragfaehig.
    private static func zellen(_ z: [WinkelZeile]) -> [String] {
        let g = z.filter(geeignet), t = tor(z)
        guard !g.isEmpty else { return ["0", "–", "–", "–", "–", "–", "nein"] }
        return ["\(g.count)", "\(zahl(TempoBericht.median(g.map(\.hubGrad)), 0)) °", zahl(t.wdhFehler, 1),
                TempoBericht.pct(t.sicherAnteil), zahl(TempoBericht.median(g.map(\.hubStreuung)), 3), "\(t.spruenge)",
                tragfaehig(t) ? "ja" : "nein"]
    }

    private static func tabellenzeile(_ name: String, _ p: [WinkelPaar]) -> String {
        let ohne = zellen(p.map(\.ohneStart)), mit = zellen(p.map(\.mitStart))
        return "| \(name) | \(p.count) | " + zip(ohne, mit).map { "\($0) / \($1)" }.joined(separator: " | ") + " |\n"
    }

    static func markdown(_ paare: [WinkelPaar]) -> String {
        var text = """
            # Winkellage

            Der Winkel ist eine direkte Messung der Lage der Last; deshalb wird die `Winkellage` hier gegen die gezählten \
            Wiederholungen geprüft, nicht gegen eine nachträgliche Rechnung.

            Signal: Drehung der Schwerkraftrichtung ĝ = (−sin p, sin r · cos p, cos r · cos p) aus Roll r und Pitch p gegenüber \
            der Ruherichtung, in der Drehebene der ersten Bewegung gemessen und über ±180° entfaltet. Es hat keine Sprungstelle \
            bei Pitch ±90°. Grenze: Eine Drehung um die Senkrechte (waagerecht schwenkende Hebelarme) ändert die \
            Schwerkraftrichtung nicht und ist für den Winkel unsichtbar.

            Auswahl: alle Aufnahmen mit bekannter Wiederholungszahl ≥ \(mindestWiederholungen), auch ohne oder mit anderer \
            Befestigungsart: `repsWahr` aus `korrekturen.json`, bei den Mac-Aufnahmen mit Metronom (`tempo` in `aufnahme.json`) \
            die von Hand gezählten Perioden aus `label.reps`. Live-Lauf ohne gemerkten Hub; Lücken gehen an die `Winkellage`.
            „geeignet“: gemerkter Hub am Satzende ≥ \(zahl(mindesthubGrad, 0))°. Alle Kennzahlen sind Mediane über die geeigneten Sätze; \
            Wdh.-Fehler = Median von |Umkehrpunkte/2 − Wiederholungen|; Sicher = Anteil sicherer Messwerte zwischen dem dritten \
            und letzten Umkehrpunkt; Streuung = Standardabweichung/Mittel des Hubs je Wiederholung; „Sprung“ = ein Schritt der Lage \
            über \(zahl(sprungMax, 1)) zwischen zwei Messwerten (Lücken nicht ausgenommen).
            „tragfähig“: Wdh.-Fehler ≤ \(zahl(wdhFehlerMax, 0)), Sicher ≥ \(zahl(sicherMin, 1)) und kein Satz mit Sprung.

            Jede Zelle zeigt zwei Läufe: **ohne Start / mit Start**. „Ohne Start“: die `Winkellage` legt die Ruherichtung \
            mit der ersten Bewegung fest; das Aufnehmen der Hantel zählt mit. „Mit Start“: `los()` kommt vor dem Satz. \
            Bei den Mac-Aufnahmen steht der Start als Zeile `# los <t>` in der Aufnahme (Zeile „mit Los-Marke“), das ist \
            der echte Ablauf. Bei allen anderen Aufnahmen gibt es keine Marke; der Start wird **nachträglich mit Wissen über \
            den ganzen Satz** gesetzt und ist deshalb eine **obere Schranke, kein Ergebnis**: Satzband = Mittelrichtung \
            von ĝ über die mittlere Hälfte der Aufnahme, Radius = größter Abstand dort + \(zahl(satzbandRandGrad, 0))°; \
            aktiver Teil = der zusammenhängende Abschnitt im Satzband um diese Mitte; `los()` am Ende des ersten Stillstands \
            (0,5 s, 4°), der in den ersten 2 s dieses Abschnitts beginnt, ohne Stillstand dort am ersten Messwert, an dem die \
            Drehung unter 20 °/s fällt (Ende des Aufnehmens).

            """
        for pruefung in [false, true] {
            let p = paare.filter { $0.ohneStart.pruefung == pruefung }
            text += "\n## \(pruefung ? TempoBericht.Teil.pruefung.rawValue : TempoBericht.Teil.abstimmung.rawValue) "
                + "(\(pruefung ? "ab" : "vor") \(TempoBericht.pruefungAb))\n\n"
                + "| Art | Sätze | geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung | Sätze mit Sprung | tragfähig |\n"
                + "|---|---|---|---|---|---|---|---|---|\n"
            for art in artenGeordnet {
                let a = p.filter { $0.ohneStart.art == art && !$0.mitLosMarke }
                if !a.isEmpty { text += tabellenzeile(artName(art), a) }
                let mac = p.filter { $0.ohneStart.art == art && $0.mitLosMarke }
                if !mac.isEmpty { text += tabellenzeile("\(artName(art)) mit Los-Marke", mac) }
            }
        }
        let mac = paare.filter(\.mitLosMarke)
        if !mac.isEmpty {
            text += "\n## Aufnahmen mit Los-Marke\n\n"
                + "Je Zelle ohne Start / mit Los-Marke.\n\n"
                + "| Aufnahme | Übung | Wiederholungen | Hub | erkannt | Sicher | größter Sprung |\n|---|---|---|---|---|---|---|\n"
            for p in mac {
                let o = p.ohneStart, m = p.mitStart
                func hub(_ z: WinkelZeile) -> String { z.hubGrad > 0 ? "\(zahl(z.hubGrad, 0)) °" : "–" }
                text += "| \(o.ordner) | \(o.uebung) | \(o.repsWahr) | \(hub(o)) / \(hub(m)) "
                    + "| \(zahl(o.erkannt, 1)) / \(zahl(m.erkannt, 1)) "
                    + "| \(TempoBericht.pct(o.sicherAnteil)) / \(TempoBericht.pct(m.sicherAnteil)) "
                    + "| \(zahl(o.groessterSprung, 2)) / \(zahl(m.groessterSprung, 2)) |\n"
            }
        }
        let mitSprung = paare.filter { p in
            [p.ohneStart, p.mitStart].contains { geeignet($0) && $0.groessterSprung > sprungMax }
        }
        text += "\n## Geeignete Sätze mit Sprung\n\n"
        if mitSprung.isEmpty { text += "Keine.\n" } else {
            text += "Je Zelle ohne Start / mit Start; „–“: in diesem Lauf nicht geeignet.\n\n"
                + "| Aufnahme | Teil | Art | Übung | Hub | größter Sprung | Lücken |\n|---|---|---|---|---|---|---|\n"
            for p in mitSprung {
                let o = p.ohneStart, m = p.mitStart
                func hub(_ z: WinkelZeile) -> String { geeignet(z) ? "\(zahl(z.hubGrad, 0)) °" : "–" }
                func sprung(_ z: WinkelZeile) -> String { geeignet(z) ? zahl(z.groessterSprung, 2) : "–" }
                text += "| \(o.ordner) | \(o.pruefung ? "Prüfung" : "Abstimmung") | \(artName(o.art)) | \(o.uebung) "
                    + "| \(hub(o)) / \(hub(m)) | \(sprung(o)) / \(sprung(m)) | \(o.luecken) |\n"
            }
        }
        text += "\n## Die zehn geeigneten Sätze mit dem größten Wiederholungsfehler (mit Start)\n\n"
            + "Je Zelle ohne Start / mit Start.\n\n"
            + "| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | Sicher |\n|---|---|---|---|---|---|---|---|\n"
        let geeignetMit = paare.filter { geeignet($0.mitStart) }
        for p in geeignetMit.sorted(by: { ($0.mitStart.wdhFehler, $1.mitStart.ordner) > ($1.mitStart.wdhFehler, $0.mitStart.ordner) }).prefix(10) {
            let o = p.ohneStart, m = p.mitStart
            text += "| \(m.ordner) | \(m.pruefung ? "Prüfung" : "Abstimmung") | \(artName(m.art)) | \(m.uebung) "
                + "| \(m.repsWahr) | \(zahl(o.hubGrad, 0)) ° / \(zahl(m.hubGrad, 0)) ° | \(zahl(o.wdhFehler, 1)) / \(zahl(m.wdhFehler, 1)) "
                + "| \(TempoBericht.pct(o.sicherAnteil)) / \(TempoBericht.pct(m.sicherAnteil)) |\n"
        }
        text += "\n## Wo der Winkel trägt\n\n"
            + "Je Befestigungsart und Übung (`kontext.exerciseName`): Aufnahmen und wie viele davon mit Start einen Hub von "
            + "mindestens \(zahl(mindesthubGrad, 0))° erreichen.\n\n" + woDerWinkelTraegt(paare.map(\.mitStart))
        return text + "\n"
    }
}
