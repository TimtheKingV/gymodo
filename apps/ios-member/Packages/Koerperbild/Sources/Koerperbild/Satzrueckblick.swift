import Foundation
import Sensorik

public enum Tempourteil: Sendable, Equatable { case imTempo, zuSchnell, zuLangsam }

/// Urteil ueber eine gezaehlte Wiederholung.
public struct Wiederholungsurteil: Sendable, Equatable {
    /// Anteil der sicheren Lagen in der Bahn der Soll-Welle; nil, wenn zu wenige Lagen sicher waren.
    public let anteilInBahn: Double?
    /// nil = nicht bewertet (leerer Balken).
    public let imTakt: Bool?
    public let hin: Tempourteil
    public let rueck: Tempourteil

    public init(anteilInBahn: Double?, imTakt: Bool?, hin: Tempourteil, rueck: Tempourteil) {
        self.anteilInBahn = anteilInBahn; self.imTakt = imTakt; self.hin = hin; self.rueck = rueck
    }
}

/// Rueckblick auf einen Satz; die Listen enthalten 1-basierte Nummern bewerteter Wiederholungen.
/// Die Listen sprechen von Hin- und Rueckweg; die Anzeige uebersetzt mit `Uebungstempo.phase(.kraftweg)` /
/// `.phase(.ablassen)` in senken/heben.
public struct Rueckblick: Sendable, Equatable {
    public let urteile: [Wiederholungsurteil]

    public init(urteile: [Wiederholungsurteil]) { self.urteile = urteile }

    public var imTakt: Int { urteile.filter { $0.imTakt == true }.count }
    public var bewertet: Int { urteile.filter { $0.imTakt != nil }.count }
    public var zuSchnellHin: [Int] { nummern { $0.hin == .zuSchnell } }
    public var zuLangsamHin: [Int] { nummern { $0.hin == .zuLangsam } }
    public var zuSchnellRueck: [Int] { nummern { $0.rueck == .zuSchnell } }
    public var zuLangsamRueck: [Int] { nummern { $0.rueck == .zuLangsam } }

    private func nummern(_ passt: (Wiederholungsurteil) -> Bool) -> [Int] {
        urteile.enumerated().filter { $0.element.imTakt != nil && passt($0.element) }.map { $0.offset + 1 }
    }
}

/// Sammelt waehrend des Satzes die Lagen und urteilt hinterher je Wiederholung.
public struct Satzrueckblick: Sendable {
    static let mindestWiederholungen = 3
    static let imTaktAb = 0.7
    static let wegToleranz = 0.25
    /// Wiederholungen, die ohne gemerkten Hub nicht bewertet werden.
    static let anlaufWiederholungen = 2

    private struct Eintrag: Sendable {
        let t: TimeInterval
        let sicher: Bool
        let inBahn: Bool
    }

    private let welle: Sollwelle
    private let hubWarGemerkt: Bool
    private var eintraege: [Eintrag] = []

    public init(welle: Sollwelle, hubWarGemerkt: Bool) {
        self.welle = welle; self.hubWarGemerkt = hubWarGemerkt
    }

    /// `sollzeit`: Sekunden seit der letzten Los-Marke (zweite Zeitachse neben `lage.t`).
    public mutating func erfasse(_ lage: Lage, sollzeit: TimeInterval) {
        eintraege.append(Eintrag(t: lage.t, sicher: lage.sicher, inBahn: welle.inDerBahn(lage.lage, bei: sollzeit)))
    }

    public func ergebnis(wiederholungen: [Koerperwiederholung]) -> Rueckblick? {
        guard wiederholungen.count >= Self.mindestWiederholungen else { return nil }
        let urteile = wiederholungen.enumerated().map { index, w -> Wiederholungsurteil in
            let anteil = anteilInBahn(w)
            let bewertet = anteil != nil && (hubWarGemerkt || index >= Self.anlaufWiederholungen)
            return Wiederholungsurteil(
                anteilInBahn: anteil,
                imTakt: bewertet ? (anteil ?? 0) >= Self.imTaktAb : nil,
                hin: Self.wegurteil(dauer: w.dauerHin, soll: welle.vorgabe.kraftweg, halten: welle.vorgabe.halten),
                rueck: Self.wegurteil(dauer: w.dauerRueck, soll: welle.vorgabe.ablassen, halten: welle.vorgabe.halten))
        }
        return Rueckblick(urteile: urteile)
    }

    private func anteilInBahn(_ w: Koerperwiederholung) -> Double? {
        let lagen = eintraege.filter { w.beginn <= $0.t && $0.t <= w.ende }
        let sichere = lagen.filter(\.sicher)
        guard !sichere.isEmpty, sichere.count * 2 >= lagen.count else { return nil }
        return Double(sichere.filter(\.inBahn).count) / Double(sichere.count)
    }

    /// Kuerzer als 75 % der Soll-Dauer = zu schnell, laenger als 125 % von Soll-Dauer plus Haltezeit = zu langsam;
    /// die Grenzen selbst sind im Tempo. Die Haltezeit ist Spielraum nach oben, weil der Umkehrpunkt
    /// (hoechster Messwert) irgendwo im Plateau liegt.
    static func wegurteil(dauer: TimeInterval, soll: TimeInterval, halten: TimeInterval = 0) -> Tempourteil {
        let eps = 1e-9
        if dauer < soll * (1 - wegToleranz) - eps { return .zuSchnell }
        if dauer > (soll + halten) * (1 + wegToleranz) + eps { return .zuLangsam }
        return .imTempo
    }
}
