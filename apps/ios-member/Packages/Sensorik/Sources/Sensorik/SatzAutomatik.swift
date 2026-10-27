import Foundation

/// Messzeit statt Wandzeit: nur beobachtete, ausgewertete Ruhe beendet einen Satz.
/// Zahlkorrekturen sind keine Eingaben dieser Maschine.
public struct SatzAutomatik: Sendable {
    public enum Zustand: Equatable, Sendable {
        case wartet
        case startkandidat
        case laeuft
        case satzende
    }
    public enum Ereignis: Equatable, Sendable {
        case begonnen(kennung: UUID, beginn: TimeInterval, bewegung: TimeInterval)
        case beendet(kennung: UUID, bewegung: TimeInterval)
    }
    public private(set) var zustand: Zustand = .wartet
    public private(set) var kennung: UUID
    public private(set) var letzteBewegung: TimeInterval?
    public private(set) var vorlauf: [SensorMesswert] = []
    private var kandidat: Wiederholung?
    private var letzteWiederholung: TimeInterval?
    private var letzterMesswert: TimeInterval?
    private var beobachtetAb: TimeInterval?
    private let vorlaufSekunden: TimeInterval
    public static let ruheSekunden: TimeInterval = 8

    public init(kennung: UUID = UUID(), vorlaufSekunden: TimeInterval = 30) {
        self.kennung = kennung
        self.vorlaufSekunden = vorlaufSekunden
    }

    public var speichernIn: TimeInterval? {
        guard zustand == .laeuft, let letzteBewegung, let beobachtetAb,
              let letzterMesswert else { return nil }
        return max(0, Self.ruheSekunden - (letzterMesswert - max(letzteBewegung, beobachtetAb)))
    }

    public mutating func empfangen(_ wert: SensorMesswert) {
        guard wert.t.isFinite, letzterMesswert.map({ wert.t > $0 }) ?? true else { return }
        if let letzterMesswert, wert.t - letzterMesswert > Satztakt.lueckeAb { luecke() }
        letzterMesswert = wert.t
        if beobachtetAb == nil { beobachtetAb = wert.t }
        if zustand == .wartet || zustand == .startkandidat {
            vorlauf.append(wert)
            if let erster = vorlauf.first, wert.t - erster.t > vorlaufSekunden + 1 {
                let grenze = wert.t - vorlaufSekunden
                vorlauf.removeAll { $0.t < grenze }
            }
        }
    }

    /// Zusaetzliche Bewegungs-Evidenz schuetzt auch langsame, noch nicht
    /// abgeschlossene Wiederholungen. Sie kann niemals einen Satz starten.
    public mutating func bewegung(bis zeit: TimeInterval) {
        guard zeit.isFinite, zustand == .laeuft else { return }
        letzteBewegung = max(letzteBewegung ?? zeit, zeit)
    }

    public mutating func wiederholungen(_ liste: [Wiederholung]) -> [Ereignis] {
        var ereignisse: [Ereignis] = []
        for w in liste.sorted(by: { $0.ende < $1.ende }) {
            guard w.beginn.isFinite, w.ende.isFinite, w.ende > w.beginn,
                  w.ende <= (letzterMesswert ?? -.infinity),
                  w.beginn >= (beobachtetAb ?? .infinity),
                  w.ende > (letzteWiederholung.map { $0 + 0.25 } ?? -.infinity), zustand != .satzende else { continue }
            // Eine erneute Schaetzung desselben Intervalls darf weder den
            // Kandidaten ersetzen noch die Ruhefrist verlaengern.
            if let letzteWiederholung, w.beginn < letzteWiederholung - 0.25 { continue }
            letzteWiederholung = w.ende
            if zustand == .laeuft {
                bewegung(bis: w.ende)
            } else if let erste = kandidat, w.beginn >= erste.ende - 0.1,
                      w.beginn - erste.ende <= 4 {
                zustand = .laeuft
                letzteBewegung = w.ende
                vorlauf.removeAll { $0.t < erste.beginn }
                ereignisse.append(.begonnen(kennung: kennung, beginn: erste.beginn, bewegung: w.ende))
            } else {
                kandidat = w
                letzteBewegung = w.ende
                zustand = .startkandidat
            }
        }
        return ereignisse
    }

    /// Erst nach Auswertung aller Werte bis zu dieser Messzeit aufrufen.
    /// Ein spaetes Ergebnis allein kann keinen Abschluss ausloesen.
    public mutating func ausgewertet(bis zeit: TimeInterval) -> Ereignis? {
        guard zeit.isFinite, zeit <= (letzterMesswert ?? -.infinity) else { return nil }
        guard zustand == .laeuft, let letzteBewegung, let beobachtetAb,
              zeit - max(letzteBewegung, beobachtetAb) >= Self.ruheSekunden else { return nil }
        zustand = .satzende
        return .beendet(kennung: kennung, bewegung: letzteBewegung)
    }

    public mutating func luecke() {
        beobachtetAb = nil
        if zustand != .laeuft && zustand != .satzende {
            kandidat = nil
            letzteWiederholung = nil
            letzteBewegung = nil
            zustand = .wartet
            vorlauf = []
        }
    }
}
