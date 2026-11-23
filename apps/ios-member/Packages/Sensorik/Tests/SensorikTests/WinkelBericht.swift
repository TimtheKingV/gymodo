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
}

struct WinkelTor: Equatable { let saetze: Int; let wdhFehler: Double; let sicherAnteil: Double; let spruenge: Int }

/// Der Winkel ist eine direkte Messung der Lage; deshalb wird er gegen die gezaehlten Wiederholungen geprueft,
/// nicht gegen eine nachtraegliche Rechnung.
enum WinkelBericht {
    static let mindesthubGrad = Winkellage.mindesthubGrad
    static let sprungMax = 0.2
    static let wdhFehlerMax = 1.0
    static let sicherMin = 0.9
    static let mindestWiederholungen = 5

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
    static func zeile(ordner: String, art: Befestigungsart?, pruefung: Bool, repsWahr: Int,
                      eintraege: [SensorAufnahmeLeser.Eintrag], rateHz: Double, uebung: String = "") -> WinkelZeile {
        var schaetzer = Winkellage(rateHz: rateHz)
        var lagen: [Lage] = [], winkel: [Vektor3] = [], luecken = 0
        for e in eintraege {
            switch e {
            case .messwert(let m): lagen.append(schaetzer.verarbeite(m)); winkel.append(m.winkel)
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
        return WinkelZeile(ordner: ordner, art: art, pruefung: pruefung, repsWahr: repsWahr, hubGrad: hub,
                           wdhFehler: abs(Double(punkte.count) / 2 - Double(repsWahr)), sicherAnteil: sicher,
                           hubStreuung: streuung(punkte, lagen: lagen, winkel: winkel, achse: schaetzer.gemerkt?.achse),
                           groessterSprung: sprung, uebung: uebung, luecken: luecken)
    }

    /// Hub je Wiederholung = Winkelweg vom oberen Umkehrpunkt zum folgenden unteren, auf der gewaehlten Achse
    /// und mit herausgerechneten Spruengen ueber ±180°; Standardabweichung / Mittel. Unter zwei Hueben 0.
    private static func streuung(_ punkte: [Umkehrpunkt], lagen: [Lage], winkel: [Vektor3], achse: Winkelachse?) -> Double {
        guard let achse, winkel.count == lagen.count, !winkel.isEmpty else { return 0 }
        var entfaltet: [Double] = [], letzter = 0.0, vorher = 0.0
        for (i, w) in winkel.enumerated() {
            let roh = achse == .roll ? w.x : w.y
            if i == 0 { letzter = roh } else {
                var d = (roh - vorher).truncatingRemainder(dividingBy: 360)
                if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                letzter += d
            }
            vorher = roh
            entfaltet.append(letzter)
        }
        func winkelBei(_ t: TimeInterval) -> Double? {
            lagen.firstIndex { $0.t >= t }.map { entfaltet[$0] }
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

    // MARK: - Alle Aufnahmen

    /// Alle Aufnahmen mit bekannter Wiederholungszahl >= 5, auch solche unter 40° Hub: (a) Ordner mit Eintrag in
    /// `korrekturen.json` und `repsWahr`, gleich welcher Art; (b) Ordner, deren `aufnahme.json` den Schluessel
    /// `tempo` traegt (Mac-Aufnahmen mit Metronom), dort gilt `label.reps`. Lueckenzeilen gehen an die `Winkellage`.
    static func zeilen() throws -> [WinkelZeile] {
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
        var ergebnis: [WinkelZeile] = []
        for (name, reps) in wahr.sorted(by: { $0.key < $1.key }) {
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            guard fm.fileExists(atPath: ordner.appendingPathComponent("messwerte.csv").path) else { continue }
            let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            ergebnis.append(zeile(ordner: name, art: datei.befestigungsart ?? k.aufnahmen[name]?.befestigungsart,
                                  pruefung: TempoBericht.teil(name) == .pruefung, repsWahr: reps,
                                  eintraege: eintraege, rateHz: Double(datei.sensor.rateSollHz),
                                  uebung: datei.kontext.exerciseName))
        }
        return ergebnis
    }

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

    static func markdown(_ zeilen: [WinkelZeile]) -> String {
        var text = """
            # Winkellage

            Der Winkel ist eine direkte Messung der Lage der Last; deshalb wird die `Winkellage` hier gegen die gezählten \
            Wiederholungen geprüft, nicht gegen eine nachträgliche Rechnung.

            Auswahl: alle Aufnahmen mit bekannter Wiederholungszahl ≥ \(mindestWiederholungen), auch ohne oder mit anderer \
            Befestigungsart: `repsWahr` aus `korrekturen.json`, bei den Mac-Aufnahmen mit Metronom (`tempo` in `aufnahme.json`) \
            die von Hand gezählten Perioden aus `label.reps`. Live-Lauf ohne gemerkten Hub; Lücken gehen an die `Winkellage`.
            „geeignet“: gemerkter Hub am Satzende ≥ \(zahl(mindesthubGrad, 0))°. Alle Kennzahlen sind Mediane über die geeigneten Sätze; \
            Wdh.-Fehler = Median von |Umkehrpunkte/2 − Wiederholungen|; Sicher = Anteil sicherer Messwerte zwischen dem dritten \
            und letzten Umkehrpunkt; Streuung = Standardabweichung/Mittel des Hubs je Wiederholung; „Sprung“ = ein Schritt der Lage \
            über \(zahl(sprungMax, 1)) zwischen zwei Messwerten (Lücken nicht ausgenommen).
            „tragfähig“: Wdh.-Fehler ≤ \(zahl(wdhFehlerMax, 0)), Sicher ≥ \(zahl(sicherMin, 1)) und kein Satz mit Sprung.

            """
        for pruefung in [false, true] {
            let z = zeilen.filter { $0.pruefung == pruefung }
            text += "\n## \(pruefung ? TempoBericht.Teil.pruefung.rawValue : TempoBericht.Teil.abstimmung.rawValue) "
                + "(\(pruefung ? "ab" : "vor") \(TempoBericht.pruefungAb))\n\n"
                + "| Art | Sätze | geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung | Sätze mit Sprung | tragfähig |\n"
                + "|---|---|---|---|---|---|---|---|---|\n"
            for art in artenGeordnet {
                let a = z.filter { $0.art == art }
                guard !a.isEmpty else { continue }
                let g = a.filter(geeignet), t = tor(a)
                guard !g.isEmpty else { text += "| \(artName(art)) | \(a.count) | 0 | – | – | – | – | – | nein |\n"; continue }
                text += "| \(artName(art)) | \(a.count) | \(g.count) | \(zahl(TempoBericht.median(g.map(\.hubGrad)), 0)) ° "
                    + "| \(zahl(t.wdhFehler, 1)) | \(TempoBericht.pct(t.sicherAnteil)) "
                    + "| \(zahl(TempoBericht.median(g.map(\.hubStreuung)), 3)) | \(t.spruenge) | \(tragfaehig(t) ? "ja" : "nein") |\n"
            }
        }
        let geeignete = zeilen.filter(geeignet)
        let mitSprung = geeignete.filter { $0.groessterSprung > sprungMax }
        text += "\n## Geeignete Sätze mit Sprung\n\n"
        if mitSprung.isEmpty { text += "Keine.\n" } else {
            text += "| Aufnahme | Teil | Art | Übung | Hub | größter Sprung | Lücken |\n|---|---|---|---|---|---|---|\n"
            for z in mitSprung {
                text += "| \(z.ordner) | \(z.pruefung ? "Prüfung" : "Abstimmung") | \(artName(z.art)) | \(z.uebung) "
                    + "| \(zahl(z.hubGrad, 0)) ° | \(zahl(z.groessterSprung, 2)) | \(z.luecken) |\n"
            }
        }
        text += "\n## Die zehn geeigneten Sätze mit dem größten Wiederholungsfehler\n\n"
            + "| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | Sicher |\n|---|---|---|---|---|---|---|---|\n"
        for z in geeignete.sorted(by: { ($0.wdhFehler, $1.ordner) > ($1.wdhFehler, $0.ordner) }).prefix(10) {
            text += "| \(z.ordner) | \(z.pruefung ? "Prüfung" : "Abstimmung") | \(artName(z.art)) | \(z.uebung) "
                + "| \(z.repsWahr) | \(zahl(z.hubGrad, 0)) ° | \(zahl(z.wdhFehler, 1)) | \(TempoBericht.pct(z.sicherAnteil)) |\n"
        }
        text += "\n## Wo der Winkel trägt\n\n"
            + "Je Befestigungsart und Übung (`kontext.exerciseName`): Aufnahmen und wie viele davon einen Hub von mindestens "
            + "\(zahl(mindesthubGrad, 0))° erreichen.\n\n" + woDerWinkelTraegt(zeilen)
        return text + "\n"
    }
}
