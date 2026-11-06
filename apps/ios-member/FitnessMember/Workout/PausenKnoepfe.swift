import Foundation

/// Wofuer die Pause gerade steht: freies Training und Plan am Geraet, der
/// Mini-Zirkel ueber der Zirkel-Ebene. Beide fuettern denselben
/// Pausen-Screen (UX-Paket 2, Abschnitt 2.1).
enum PausenModus: Equatable {
    case frei(naechsterSatz: Int, kannZirkel: Bool)
    case plan(naechsterSatz: Int)
    case zirkel(naechsteUebung: String, kannErweitern: Bool)
}

/// Welche Knoepfe der Pausen-Screen zeigt, als reiner Wert. Genau ein
/// Hauptknopf je Zustand; er beendet die Pause, ein eigenes "Pause
/// ueberspringen" gibt es nicht.
struct PausenKnoepfe: Equatable {
    /// "Satz 3 starten" bzw. "Beinpresse starten".
    let haupt: String
    /// Frei "Übung abschließen", Plan "Nächste Übung", Zirkel nil (E7:
    /// dort uebernehmen "Überspringen" und "Zirkel beenden").
    let abschliessen: String?
    /// Nur im Zirkel: die naechste Station in dieser Runde auslassen.
    let ueberspringen: Bool
    /// Nur frei: "Zirkel mit weiterem Gerät".
    let zirkelBeginnen: Bool
    /// Nur im Zirkel, solange Erweitern offen ist: "+ Übung zum Zirkel".
    let erweitern: Bool
    /// Nur im Zirkel.
    let zirkelBeenden: Bool

    static func fuer(_ modus: PausenModus) -> PausenKnoepfe {
        switch modus {
        case .frei(let satz, let kannZirkel):
            PausenKnoepfe(haupt: "Satz \(satz) starten", abschliessen: "Übung abschließen",
                          ueberspringen: false, zirkelBeginnen: kannZirkel, erweitern: false,
                          zirkelBeenden: false)
        case .plan(let satz):
            PausenKnoepfe(haupt: "Satz \(satz) starten", abschliessen: "Nächste Übung",
                          ueberspringen: false, zirkelBeginnen: false, erweitern: false,
                          zirkelBeenden: false)
        case .zirkel(let name, let kannErweitern):
            PausenKnoepfe(haupt: ZirkelPauseText.startTitel(uebungsname: name), abschliessen: nil,
                          ueberspringen: true, zirkelBeginnen: false, erweitern: kannErweitern,
                          zirkelBeenden: true)
        }
    }

    /// "± kg" statt "Gewicht" (Testnotiz 12.10. abends, #4): kurz genug
    /// fuer die halbe Zeile, und am Laufband steht "± km/h".
    static func gewichtTitel(_ einheit: LoadUnit) -> String {
        "± \(einheit.kurz)"
    }
}
