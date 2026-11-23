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
    var endeT: Double?             // Zeit des ersten nicht mehr eingespeisten Messwerts; nil = ganze Aufnahme
    var ausschlagGrad = 0.0        // groesster Ausschlag aus der Ruhelage
}

struct WinkelTor: Equatable { let saetze: Int; let wdhFehler: Double; let sicherAnteil: Double; let spruenge: Int }

/// Eine Aufnahme in beiden Laeufen: ohne Start und mit Start (Los-Marke oder geschaetzt).
struct WinkelPaar {
    let ohneStart: WinkelZeile
    let mitStart: WinkelZeile
    /// Die Aufnahme traegt eine Zeile `# los <t>`; `mitStart` laeuft dann von dieser Marke bis `# ende`.
    let mitLosMarke: Bool
    /// Ohne Los-Marke liess sich kein Start schaetzen; `mitStart` ist dann der Lauf ohne Start.
    var startUnbestimmt = false
    /// Zahl der Zeilen `# takt oben` (Metronom), 0 ohne Metronom.
    var taktGipfel = 0
}

/// Vergleich beider Laeufe: Saetze, die nur in einem Lauf geeignet sind, und die Kennzahlen ueber die
/// Saetze, die in beiden Laeufen geeignet sind.
struct WinkelVergleich: Equatable {
    let nurOhne: Int; let nurMit: Int; let gemeinsam: Int
    let ohne: WinkelTor; let mit: WinkelTor
}

/// Der Winkel ist eine direkte Messung der Lage; deshalb wird er gegen die gezaehlten Wiederholungen geprueft,
/// nicht gegen eine nachtraegliche Rechnung.
enum WinkelBericht {
    static let mindesthubGrad = Winkellage.mindesthubGrad
    static let sprungMax = 0.2
    static let wdhFehlerMax = 1.0
    static let sicherMin = 0.9
    static let mindestWiederholungen = 5
    /// Rand des Satzbands fuer den geschaetzten Start, in Grad.
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

    /// Nur ohne / nur mit Start geeignet, und `tor` beider Laeufe ueber die in beiden geeigneten Saetze.
    static func vergleich(_ paare: [WinkelPaar]) -> WinkelVergleich {
        let beide = paare.filter { geeignet($0.ohneStart) && geeignet($0.mitStart) }
        return WinkelVergleich(nurOhne: paare.filter { geeignet($0.ohneStart) && !geeignet($0.mitStart) }.count,
                               nurMit: paare.filter { !geeignet($0.ohneStart) && geeignet($0.mitStart) }.count,
                               gemeinsam: beide.count, ohne: tor(beide.map(\.ohneStart)), mit: tor(beide.map(\.mitStart)))
    }

    /// Aufnahmen ohne Los-Marke, bei denen der geschaetzte Start schlechter ist: in mindestens einem Lauf geeignet,
    /// und der Wdh.-Fehler ist groesser, oder der groesste Schritt liegt ueber 0,2 und ist groesser als ohne Start.
    static func schlechter(_ paare: [WinkelPaar]) -> [WinkelPaar] {
        paare.filter { p in
            let o = p.ohneStart, m = p.mitStart
            guard !p.mitLosMarke, !p.startUnbestimmt, geeignet(o) || geeignet(m) else { return false }
            return m.wdhFehler > o.wdhFehler || (m.groessterSprung > sprungMax && m.groessterSprung > o.groessterSprung)
        }
    }

    /// Fuer „Wo der Winkel traegt“: der Lauf ohne Start (kein nachtraegliches Wissen), bei Los-Marke der echte Ablauf.
    static func traegtZeilen(_ paare: [WinkelPaar]) -> [WinkelZeile] {
        paare.map { $0.mitLosMarke ? $0.mitStart : $0.ohneStart }
    }

    // MARK: - Eine Aufnahme

    /// Spielt die Eintraege live (ohne gemerkten Wert) durch die `Winkellage`; Luecken-Zeilen gehen als `luecke` hinein.
    /// Mit `losBei` wartet die `Winkellage` auf den Start; `los()` kommt vor dem ersten Messwert mit `t >= losBei`.
    /// Mit `endeBei` endet der Lauf vor dem ersten Messwert mit `t >= endeBei` (Satzende in der App).
    static func zeile(ordner: String, art: Befestigungsart?, pruefung: Bool, repsWahr: Int,
                      eintraege: [SensorAufnahmeLeser.Eintrag], rateHz: Double, uebung: String = "",
                      losBei: Double? = nil, endeBei: Double? = nil) -> WinkelZeile {
        var schaetzer = Winkellage(rateHz: rateHz, wartetAufLos: losBei != nil)
        var lagen: [Lage] = [], winkel: [Double] = [], luecken = 0
        var losT: Double?, endeT: Double?
        lauf: for e in eintraege {
            switch e {
            case .messwert(let m):
                if let endeBei, m.t >= endeBei { endeT = m.t; break lauf }
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
                           groessterSprung: sprung, uebung: uebung, luecken: luecken, erkannt: erkannt, losT: losT,
                           endeT: endeT, ausschlagGrad: schaetzer.groessterAusschlagGrad)
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

    /// Beide Laeufe einer Aufnahme. Mit Zeile `# los` in der CSV laeuft `mitStart` von dort bis `# ende`;
    /// sonst mit geschaetztem Start ueber die ganze Aufnahme. Laesst sich kein Start schaetzen, ist `mitStart`
    /// der Lauf ohne Start und `startUnbestimmt` gesetzt.
    static func paar(ordner: String, art: Befestigungsart?, pruefung: Bool, repsWahr: Int,
                     eintraege: [SensorAufnahmeLeser.Eintrag], rateHz: Double, uebung: String, csv: String) -> WinkelPaar {
        func lauf(_ losBei: Double?, _ endeBei: Double?) -> WinkelZeile {
            zeile(ordner: ordner, art: art, pruefung: pruefung, repsWahr: repsWahr, eintraege: eintraege,
                  rateHz: rateHz, uebung: uebung, losBei: losBei, endeBei: endeBei)
        }
        let ohne = lauf(nil, nil), takt = taktGipfel(csv: csv)
        if let marke = losMarke(csv: csv) {
            return WinkelPaar(ohneStart: ohne, mitStart: lauf(marke, endeMarke(csv: csv)), mitLosMarke: true, taktGipfel: takt)
        }
        guard let geschaetzt = startNachtraeglich(eintraege, rateHz: rateHz) else {
            return WinkelPaar(ohneStart: ohne, mitStart: ohne, mitLosMarke: false, startUnbestimmt: true, taktGipfel: takt)
        }
        return WinkelPaar(ohneStart: ohne, mitStart: lauf(geschaetzt, nil), mitLosMarke: false, taktGipfel: takt)
    }

    // MARK: - Start und Ende

    /// Zahl aus der ersten Zeile `<praefix><t>` der CSV.
    private static func marke(_ praefix: String, csv: String) -> Double? {
        for zeile in csv.split(whereSeparator: \.isNewline) where zeile.hasPrefix(praefix) {
            return Double(zeile.dropFirst(praefix.count).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Zeit aus der Zeile `# los <t>` der CSV, falls vorhanden (der `SensorAufnahmeLeser` ueberliest sie).
    static func losMarke(csv: String) -> Double? { marke("# los ", csv: csv) }

    /// Zeit aus der Zeile `# ende <t>`: die Taste, mit der das Mitglied den Satz beendet hat.
    static func endeMarke(csv: String) -> Double? { marke("# ende ", csv: csv) }

    /// Zahl der Zeilen `# takt oben` (Gipfel des Metronoms).
    static func taktGipfel(csv: String) -> Int {
        csv.split(whereSeparator: \.isNewline).filter { $0.hasPrefix("# takt oben ") }.count
    }

    /// Geschaetzter Start mit Wissen ueber die ganze Aufnahme. Satzband: normiertes Mittel der Schwerkraftrichtung ĝ
    /// ueber die mittlere Haelfte der Aufnahme (nach der Zeit), Radius = groesster Abstand dort plus `satzbandRandGrad`.
    /// Aktiver Teil: der zusammenhaengende Abschnitt im Satzband, der die mittlere Haelfte enthaelt, rueckwaerts von
    /// ihrem Beginn verfolgt. `los()` kommt am Ende des ersten Stillstands (Kriterium der `Winkellage`),
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

        let halbe = Int(Winkellage.stilleSekunden * rateHz), grenze = cos(Winkellage.stilleAbweichungGrad * .pi / 180)
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
    /// `tempo` traegt (Mac-Aufnahmen mit Metronom), dort gilt `label.reps`. `ausgelassen`: ausgewaehlt, aber ohne
    /// `messwerte.csv`.
    static func auswahl() throws -> (wahr: [(name: String, reps: Int)], ausgelassen: [String]) {
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
        var gelesen: [(name: String, reps: Int)] = [], ausgelassen: [String] = []
        for (name, reps) in wahr.sorted(by: { $0.key < $1.key }) {
            let csv = Pfade.aufnahmen.appendingPathComponent(name).appendingPathComponent("messwerte.csv")
            if fm.fileExists(atPath: csv.path) { gelesen.append((name, reps)) } else { ausgelassen.append(name) }
        }
        return (gelesen, ausgelassen)
    }

    /// Je ausgewaehlter Aufnahme beide Laeufe (`paar`); Lueckenzeilen gehen an die `Winkellage`.
    static func paare() throws -> [WinkelPaar] {
        let k = try Korrekturen.laden()
        return try auswahl().wahr.map { name, reps in
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            let csv = try String(contentsOf: ordner.appendingPathComponent("messwerte.csv"), encoding: .utf8)
            return paar(ordner: name, art: datei.befestigungsart ?? k.aufnahmen[name]?.befestigungsart,
                        pruefung: TempoBericht.teil(name) == .pruefung, repsWahr: reps, eintraege: eintraege,
                        rateHz: Double(datei.sensor.rateSollHz), uebung: datei.kontext.exerciseName, csv: csv)
        }
    }

    /// Die Laeufe ohne Start.
    static func zeilen() throws -> [WinkelZeile] { try paare().map(\.ohneStart) }

    // MARK: - Bericht

    private static func zahl(_ x: Double, _ stellen: Int) -> String { TempoBericht.zahl(x, stellen) }
    private static func artName(_ a: Befestigungsart?) -> String { a?.rawValue ?? "ohne Art" }
    private static func artRang(_ a: Befestigungsart?) -> Int { a.flatMap { Befestigungsart.allCases.firstIndex(of: $0) } ?? Int.max }
    /// Befestigungsarten in der Reihenfolge der Deklaration, „ohne Art“ zuletzt.
    private static let artenGeordnet: [Befestigungsart?] = Befestigungsart.allCases.map { Optional($0) } + [nil]
    private static func teilName(_ z: WinkelZeile) -> String { z.pruefung ? "Prüfung" : "Abstimmung" }

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
        let ohne = zellen(p.map(\.ohneStart)), mit = zellen(p.map(\.mitStart)), v = vergleich(p)
        var paarweise = zip(ohne, mit).map { "\($0) / \($1)" }
        paarweise.insert("\(v.nurOhne) / \(v.nurMit)", at: 1)
        return "| \(name) | \(p.count) | " + paarweise.joined(separator: " | ") + " |\n"
    }

    private static func gemeinsamZeile(_ name: String, _ p: [WinkelPaar]) -> String {
        let v = vergleich(p)
        guard v.gemeinsam > 0 else { return "| \(name) | 0 | – | – | – |\n" }
        return "| \(name) | \(v.gemeinsam) | \(zahl(v.ohne.wdhFehler, 1)) / \(zahl(v.mit.wdhFehler, 1)) "
            + "| \(TempoBericht.pct(v.ohne.sicherAnteil)) / \(TempoBericht.pct(v.mit.sicherAnteil)) "
            + "| \(v.ohne.spruenge) / \(v.mit.spruenge) |\n"
    }

    /// Gruppen eines Teils: je Art die Aufnahmen ohne Los-Marke, danach die mit Los-Marke.
    private static func gruppen(_ p: [WinkelPaar]) -> [(name: String, paare: [WinkelPaar])] {
        var ergebnis: [(name: String, paare: [WinkelPaar])] = []
        for art in artenGeordnet {
            let a = p.filter { $0.ohneStart.art == art && !$0.mitLosMarke }
            if !a.isEmpty { ergebnis.append((artName(art), a)) }
            let mac = p.filter { $0.ohneStart.art == art && $0.mitLosMarke }
            if !mac.isEmpty { ergebnis.append(("\(artName(art)) mit Los-Marke", mac)) }
        }
        return ergebnis
    }

    /// Wie `markdown(_:ausgelassen:)`; die ausgelassenen Aufnahmen kommen aus `auswahl()`.
    static func markdown(_ paare: [WinkelPaar]) throws -> String {
        markdown(paare, ausgelassen: try auswahl().ausgelassen)
    }

    static func markdown(_ paare: [WinkelPaar], ausgelassen: [String]) -> String {
        let unbestimmt = paare.filter(\.startUnbestimmt).map(\.ohneStart.ordner)
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
            Sätze gelesen: \(paare.count), ausgelassen: \(ausgelassen.count)\
            \(ausgelassen.isEmpty ? "" : " (\(ausgelassen.joined(separator: ", ")))") (ohne `messwerte.csv`).
            „geeignet“: gemerkter Hub am Satzende ≥ \(zahl(mindesthubGrad, 0))°. Wdh.-Fehler = Median von \
            |Umkehrpunkte/2 − Wiederholungen|; Sicher = Anteil sicherer Messwerte zwischen dem dritten \
            und letzten Umkehrpunkt; Streuung = Standardabweichung/Mittel des Hubs je Wiederholung; „Sprung“ = ein Schritt der Lage \
            über \(zahl(sprungMax, 1)) zwischen zwei Messwerten (Lücken nicht ausgenommen).
            „tragfähig“: Wdh.-Fehler ≤ \(zahl(wdhFehlerMax, 0)), Sicher ≥ \(zahl(sicherMin, 1)) und kein Satz mit Sprung.

            Jede Zelle zeigt zwei Läufe: **ohne Start / geschätzter Start**. „Ohne Start“: die `Winkellage` legt die \
            Ruherichtung mit der ersten Bewegung fest; das Aufnehmen der Hantel zählt mit, die ganze Aufnahme läuft durch. \
            „Geschätzter Start“: diese Aufnahmen haben keine Start-Marke. Der Start wird nachträglich aus der ganzen Aufnahme \
            geraten (Satzband = Mittelrichtung von ĝ über die mittlere Hälfte der Aufnahme, Radius = größter Abstand dort + \
            \(zahl(satzbandRandGrad, 0))°; aktiver Teil = der zusammenhängende Abschnitt im Satzband um diese Mitte; `los()` am \
            Ende des ersten Stillstands (\(zahl(Winkellage.stilleSekunden, 1)) s, \(zahl(Winkellage.stilleAbweichungGrad, 0))°), \
            der in den ersten 2 s dieses Abschnitts beginnt, ohne Stillstand dort am ersten Messwert, an dem die Drehung unter \
            20 °/s fällt). **Diese Schätzung kann falsch sein; ein Fehler in dieser Spalte kann von der Schätzung kommen und \
            nicht von der `Winkellage`.** Die Sätze, bei denen der geschätzte Start schlechter ist als ohne Start, stehen \
            unten einzeln. Ausnahme: In den Zeilen „mit Los-Marke“ (Mac-Aufnahmen) ist die zweite Zahl der echte Ablauf, \
            `los()` an `# los`, Ende an `# ende`.
            Kein Start bestimmbar: \(unbestimmt.isEmpty ? "keine" : unbestimmt.joined(separator: ", ")).

            Die Kennzahlen jedes Laufs sind Mediane über die Sätze, die **in diesem Lauf** geeignet sind; die Mengen \
            unterscheiden sich. „nur in einem Lauf geeignet“ zählt Sätze, die nur ohne Start / nur mit Start geeignet sind. \
            Der faire Vergleich steht je Teil in der Tabelle „in beiden Läufen geeignet“.

            """
        for pruefung in [false, true] {
            let p = paare.filter { $0.ohneStart.pruefung == pruefung }
            let teil = pruefung ? TempoBericht.Teil.pruefung.rawValue : TempoBericht.Teil.abstimmung.rawValue
            text += "\n## \(teil) (\(pruefung ? "ab" : "vor") \(TempoBericht.pruefungAb))\n\n"
                + "| Art | Sätze | geeignet | nur in einem Lauf geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung "
                + "| Sätze mit Sprung | tragfähig |\n|---|---|---|---|---|---|---|---|---|---|\n"
            for g in gruppen(p) { text += tabellenzeile(g.name, g.paare) }
            text += "\n### \(teil): in beiden Läufen geeignet\n\n"
                + "| Art | Sätze | Wdh.-Fehler | Sicher | Sätze mit Sprung |\n|---|---|---|---|---|\n"
            for g in gruppen(p) { text += gemeinsamZeile(g.name, g.paare) }
        }
        text += macAbschnitt(paare.filter(\.mitLosMarke))

        let schlecht = schlechter(paare)
        text += "\n## Geschätzter Start schlechter als ohne Start\n\n"
            + "Aufnahmen ohne Los-Marke, in mindestens einem Lauf geeignet, bei denen der Wdh.-Fehler mit geschätztem Start "
            + "größer ist oder der größte Schritt über \(zahl(sprungMax, 1)) liegt und größer ist als ohne Start: "
            + "\(schlecht.count). Je Zelle ohne Start / geschätzter Start.\n\n"
        if !schlecht.isEmpty {
            text += "| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | größter Schritt |\n"
                + "|---|---|---|---|---|---|---|---|\n"
            for p in schlecht {
                let o = p.ohneStart, m = p.mitStart
                text += "| \(o.ordner) | \(teilName(o)) | \(artName(o.art)) | \(o.uebung) | \(o.repsWahr) "
                    + "| \(zahl(o.hubGrad, 0)) ° / \(zahl(m.hubGrad, 0)) ° | \(zahl(o.wdhFehler, 1)) / \(zahl(m.wdhFehler, 1)) "
                    + "| \(zahl(o.groessterSprung, 2)) / \(zahl(m.groessterSprung, 2)) |\n"
            }
        }

        let mitSprung = paare.filter { p in
            [p.ohneStart, p.mitStart].contains { geeignet($0) && $0.groessterSprung > sprungMax }
        }
        text += "\n## Geeignete Sätze mit Sprung\n\n"
        if mitSprung.isEmpty { text += "Keine.\n" } else {
            text += "Je Zelle ohne Start / geschätzter Start (Mac: Los-Marke bis Ende); „–“: in diesem Lauf nicht geeignet.\n\n"
                + "| Aufnahme | Teil | Art | Übung | Hub | größter Sprung | Lücken |\n|---|---|---|---|---|---|---|\n"
            for p in mitSprung {
                let o = p.ohneStart, m = p.mitStart
                func hub(_ z: WinkelZeile) -> String { geeignet(z) ? "\(zahl(z.hubGrad, 0)) °" : "–" }
                func sprung(_ z: WinkelZeile) -> String { geeignet(z) ? zahl(z.groessterSprung, 2) : "–" }
                text += "| \(o.ordner) | \(teilName(o)) | \(artName(o.art)) | \(o.uebung) "
                    + "| \(hub(o)) / \(hub(m)) | \(sprung(o)) / \(sprung(m)) | \(o.luecken) |\n"
            }
        }
        text += "\n## Die zehn geeigneten Sätze mit dem größten Wiederholungsfehler ohne Start\n\n"
            + "Je Zelle ohne Start / geschätzter Start (Mac: Los-Marke bis Ende).\n\n"
            + "| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | Sicher |\n|---|---|---|---|---|---|---|---|\n"
        let geeignetOhne = paare.filter { geeignet($0.ohneStart) }
        for p in geeignetOhne.sorted(by: { ($0.ohneStart.wdhFehler, $1.ohneStart.ordner) > ($1.ohneStart.wdhFehler, $0.ohneStart.ordner) }).prefix(10) {
            let o = p.ohneStart, m = p.mitStart
            text += "| \(o.ordner) | \(teilName(o)) | \(artName(o.art)) | \(o.uebung) "
                + "| \(o.repsWahr) | \(zahl(o.hubGrad, 0)) ° / \(zahl(m.hubGrad, 0)) ° | \(zahl(o.wdhFehler, 1)) / \(zahl(m.wdhFehler, 1)) "
                + "| \(TempoBericht.pct(o.sicherAnteil)) / \(TempoBericht.pct(m.sicherAnteil)) |\n"
        }
        text += "\n## Wo der Winkel trägt\n\n"
            + "Je Befestigungsart und Übung (`kontext.exerciseName`): Aufnahmen und wie viele davon einen Hub von mindestens "
            + "\(zahl(mindesthubGrad, 0))° erreichen. Gezählt wird der Lauf ohne Start (kein nachträgliches Wissen), bei den "
            + "Aufnahmen mit Los-Marke der Lauf von `# los` bis `# ende`.\n\n" + woDerWinkelTraegt(traegtZeilen(paare))
        return text + "\n"
    }

    /// Abschnitt der Aufnahmen mit Los-Marke: Lauf ohne Start ueber die ganze Aufnahme gegen den echten Ablauf.
    private static func macAbschnitt(_ mac: [WinkelPaar]) -> String {
        guard !mac.isEmpty else { return "" }
        let laeufe = mac.map(\.mitStart), g = laeufe.filter(geeignet)
        func liste(_ z: [WinkelZeile]) -> String { z.isEmpty ? "keine" : z.map { String($0.ordner.suffix(7)) }.joined(separator: ", ") }
        let zuViel = g.filter { $0.erkannt > Double($0.repsWahr) }, zuWenig = g.filter { $0.erkannt < Double($0.repsWahr) }
        let nicht = laeufe.filter { !geeignet($0) }
        let ausschlag = nicht.map(\.ausschlagGrad)
        var text = "\n## Aufnahmen mit Los-Marke\n\n"
            + "Echter Ablauf: `los()` am ersten Messwert ab `# los`; eingespeist werden die Messwerte nur bis vor den ersten mit "
            + "t ≥ `# ende` (die Taste, mit der das Mitglied den Satz beendet; in der App hält dort die `Winkellage` an). "
            + "Ohne Start läuft die ganze Aufnahme, auch das Ablegen nach dem Satz und die 5 s danach zählen als Satzzeit. "
            + "Wiederholungen = `label.reps`, die von Hand gezählten vollen Metronom-Perioden; Taktgipfel = Zahl der Zeilen "
            + "`# takt oben`.\n\n"
            + "Mit Los-Marke bis Ende, über die \(g.count) geeigneten: Wdh.-Fehler im Median \(zahl(TempoBericht.median(g.map(\.wdhFehler)), 1)) "
            + "(Schwelle ≤ \(zahl(wdhFehlerMax, 0))); zu viel erkannt: \(liste(zuViel)), davon höchstens so viele wie Taktgipfel: "
            + "\(liste(zuViel.filter { z in Double(mac.first { $0.mitStart.ordner == z.ordner }?.taktGipfel ?? 0) >= z.erkannt })) "
            + "(das Mitglied hat zum letzten Taktgipfel noch gehoben, `label.reps` zählt diese letzte, nicht volle Periode nicht); "
            + "zu wenig: \(liste(zuWenig)); halbe Werte: \(liste(g.filter { $0.erkannt != $0.erkannt.rounded() })) "
            + "(der Satz endete an `# ende` vor dem letzten unteren Umkehrpunkt). "
            + "Nicht geeignet und in keinem Median: \(nicht.map { "\(String($0.ordner.suffix(7))) (\($0.uebung))" }.joined(separator: ", ")); "
        text += ausschlag.isEmpty ? "–.\n\n"
            : "der Sensor dreht sich dort nur um \(zahl(ausschlag.min()!, 0))–\(zahl(ausschlag.max()!, 0))° (größter Ausschlag), "
              + "unter dem Mindesthub von \(zahl(mindesthubGrad, 0))°.\n\n"
        text += "| Aufnahme | Übung | Wiederholungen | Taktgipfel | erkannt ganze Aufnahme (ohne Start) | erkannt los bis ende "
            + "| Hub | Sicher | größter Schritt |\n|---|---|---|---|---|---|---|---|---|\n"
        for p in mac {
            let o = p.ohneStart, m = p.mitStart
            text += "| \(o.ordner) | \(o.uebung) | \(o.repsWahr) | \(p.taktGipfel) | \(zahl(o.erkannt, 1)) | \(zahl(m.erkannt, 1)) "
                + "| \(m.hubGrad > 0 ? "\(zahl(m.hubGrad, 0)) °" : "–") | \(TempoBericht.pct(m.sicherAnteil)) "
                + "| \(zahl(m.groessterSprung, 2)) |\n"
        }
        return text
    }
}
