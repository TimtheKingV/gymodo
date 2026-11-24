import Foundation
import Sensorik

public enum Tempophase: String, Sendable { case senken, halten, heben }

/// Tempo einer Uebung in den Worten der Uebung (senken, halten, heben) und seine Abbildung auf die Soll-Welle:
/// Der erste Weg der Bewegung ist der Kraftweg, der zweite das Ablassen.
public struct Uebungstempo: Sendable, Equatable {
    public let senken: Double
    public let halten: Double
    public let heben: Double
    /// Womit die Wiederholung beginnt: `.senken` (z. B. Kniebeuge) oder `.heben` (z. B. Curl).
    public let beginntMit: Tempophase

    public init(senken: Double, halten: Double, heben: Double, beginntMit: Tempophase) {
        precondition(beginntMit == .senken || beginntMit == .heben, "beginntMit ist .senken oder .heben")
        self.senken = senken; self.halten = halten; self.heben = heben; self.beginntMit = beginntMit
    }

    /// 1,5 s heben, 2,5 s senken, kein Halten.
    public static func standard(beginntMit: Tempophase) -> Uebungstempo {
        Uebungstempo(senken: 2.5, halten: 0, heben: 1.5, beginntMit: beginntMit)
    }

    private var beginntMitSenken: Bool { beginntMit == .senken }

    public var vorgabe: Tempovorgabe {
        beginntMitSenken
            ? Tempovorgabe(kraftweg: senken, ablassen: heben, halten: halten)
            : Tempovorgabe(kraftweg: heben, ablassen: senken, halten: halten)
    }

    public func phase(_ weg: Weg) -> Tempophase {
        switch weg {
        case .halten: .halten
        case .kraftweg: beginntMitSenken ? .senken : .heben
        case .ablassen: beginntMitSenken ? .heben : .senken
        }
    }

    /// In der Reihenfolge der Bewegung, z. B. "3 s senken · 1 s halten · 2 s heben"; Halten 0 entfaellt.
    public var inWorten: String {
        let erste = beginntMitSenken ? "\(Self.zahl(senken)) s senken" : "\(Self.zahl(heben)) s heben"
        let zweite = beginntMitSenken ? "\(Self.zahl(heben)) s heben" : "\(Self.zahl(senken)) s senken"
        var teile = [erste]
        if halten > 0 { teile.append("\(Self.zahl(halten)) s halten") }
        teile.append(zweite)
        return teile.joined(separator: " · ")
    }

    /// Deutsche Schreibweise: ganze Zahlen ohne Komma, sonst Dezimalkomma.
    private static func zahl(_ wert: Double) -> String {
        wert == wert.rounded() ? String(Int(wert)) : String(wert).replacingOccurrences(of: ".", with: ",")
    }
}
