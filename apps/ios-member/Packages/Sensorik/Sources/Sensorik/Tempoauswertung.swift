import Foundation

/// Urteil ueber eine Wegart des Satzes: Zahl der Perioden mit der haeufigeren Abweichung, von allen gewerteten.
public enum Wegurteil: Sendable, Equatable {
    case imTempo
    case zuSchnell(Int, von: Int)
    case zuLangsam(Int, von: Int)
}

public struct Tempoergebnis: Sendable, Equatable {
    /// Anteil der gewerteten Messwerte in der Bahn, 0…1.
    public let quote: Double
    /// Anteil in der Bahn je gewerteter Periode (ab Periode 2); nil ohne sichere Messwerte.
    public let perioden: [Double?]
    public let kraftweg: Wegurteil
    public let ablassen: Wegurteil
}

/// Wertet einen Satz gegen die Soll-Welle aus (Tempo-Spec 7.5). Haelt nur Zaehler je Periode, keine Messwerte.
/// Gewertet wird ab Periode 2 (0-basiert) bis zum letzten Messwert, auch ueber die Zielzeit hinaus, nur mit `sicher`.
public struct Tempoauswertung: Sendable {
    private static let ersteGewertetePeriode = 2
    /// Kein Satz dauert eine Stunde; schuetzt den Speicher vor einer abwegigen Zeit.
    private static let laengsteZeit: TimeInterval = 3600

    /// Zaehler einer Periode; je Wegart `[kraftweg, ablassen]`.
    private struct Zaehler: Sendable {
        var gesamt = [0, 0]
        var inBahn = [0, 0]
        var voraus = [0, 0]      // ausserhalb der Bahn und der Welle voraus
        var zurueck = [0, 0]     // ausserhalb der Bahn und hinter der Welle
        var summe: Int { gesamt[0] + gesamt[1] }
        var treffer: Int { inBahn[0] + inBahn[1] }
    }

    private let welle: Sollwelle
    private var zaehler: [Zaehler] = []       // Index = Periode - 2
    private var letztePeriode = -1

    public init(welle: Sollwelle) {
        self.welle = welle
    }

    /// t in Sekunden seit der Los-Marke. Jeder Messwert zaehlt gleich (Sollrate), nicht nach Zeitstempel-Differenz.
    public mutating func erfasse(_ lage: Lage, bei t: TimeInterval) {
        guard t.isFinite, t <= Self.laengsteZeit, lage.lage.isFinite,
              let periode = welle.periode(bei: t), let weg = welle.weg(bei: t) else { return }
        letztePeriode = max(letztePeriode, periode)
        guard lage.sicher, periode >= Self.ersteGewertetePeriode else { return }

        let index = periode - Self.ersteGewertetePeriode
        if zaehler.count <= index {
            zaehler.append(contentsOf: Array(repeating: Zaehler(), count: index + 1 - zaehler.count))
        }
        let w = weg == .kraftweg ? 0 : 1
        zaehler[index].gesamt[w] += 1
        if welle.inDerBahn(lage.lage, bei: t) {
            zaehler[index].inBahn[w] += 1
        } else {
            let soll = welle.lage(bei: t)
            // Voraus: auf dem Kraftweg hoeher als die Welle, beim Ablassen tiefer.
            let voraus = weg == .kraftweg ? lage.lage > soll : lage.lage < soll
            if voraus { zaehler[index].voraus[w] += 1 } else { zaehler[index].zurueck[w] += 1 }
        }
    }

    /// nil, solange nichts Gewertetes da ist.
    public var laufendeQuote: Double? {
        let summe = zaehler.reduce(0) { $0 + $1.summe }
        guard summe > 0 else { return nil }
        return Double(zaehler.reduce(0) { $0 + $1.treffer }) / Double(summe)
    }

    /// nil bei weniger als drei begonnenen Perioden oder ohne gewertete Messwerte ("Zu kurz fuer eine Auswertung").
    /// `perioden` reicht von Periode 2 bis zur letzten Periode, die irgendeinen Messwert bekam (sicher oder nicht);
    /// Perioden ohne sichere Messwerte stehen als nil darin, auch am Ende.
    public func ergebnis() -> Tempoergebnis? {
        guard letztePeriode >= Self.ersteGewertetePeriode, let quote = laufendeQuote else { return nil }
        let anzahl = letztePeriode - Self.ersteGewertetePeriode + 1
        let alle = (0..<anzahl).map { $0 < zaehler.count ? zaehler[$0] : Zaehler() }
        let perioden: [Double?] = alle.map { $0.summe > 0 ? Double($0.treffer) / Double($0.summe) : nil }
        return Tempoergebnis(
            quote: quote, perioden: perioden,
            kraftweg: Self.urteil(alle, weg: 0), ablassen: Self.urteil(alle, weg: 1))
    }

    /// Ein Weg einer Periode ist zu schnell (zu langsam), wenn mehr als die Haelfte seiner Messwerte
    /// ausserhalb der Bahn und voraus (zurueck) liegt. Das Urteil nennt die haeufigere Abweichung; bei Gleichstand zu schnell.
    private static func urteil(_ perioden: [Zaehler], weg w: Int) -> Wegurteil {
        let gewertet = perioden.filter { $0.gesamt[w] > 0 }
        let schnell = gewertet.filter { $0.voraus[w] * 2 > $0.gesamt[w] }.count
        let langsam = gewertet.filter { $0.zurueck[w] * 2 > $0.gesamt[w] }.count
        if schnell == 0 && langsam == 0 { return .imTempo }
        return schnell >= langsam ? .zuSchnell(schnell, von: gewertet.count) : .zuLangsam(langsam, von: gewertet.count)
    }
}
