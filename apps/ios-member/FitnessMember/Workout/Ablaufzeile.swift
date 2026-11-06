import SwiftUI

/// Wo im Ablauf das Mitglied steht -- eine Zeile unter dem Uebungsnamen am
/// Geraet und im Pausen-Screen (UX-Paket 2, Abschnitt 2.4). Im Plan zaehlt
/// der Satz ueber alle Geraete der Uebung (wie die Plankarte), frei nur
/// der Satz an diesem Geraet.
enum Ablaufzeile: Equatable {
    case plan(uebung: Int, von: Int, satz: Int, saetze: Int)
    case zirkel(station: Int, von: Int, runde: Int, runden: Int)
    case frei(satz: Int)

    var text: String {
        switch self {
        case .plan(let uebung, let von, let satz, let saetze):
            "Übung \(uebung) von \(von) · Satz \(satz) von \(saetze)"
        case .zirkel(let station, let von, let runde, let runden):
            "Station \(station) von \(von) · Runde \(runde) von \(runden)"
        case .frei(let satz):
            "Satz \(satz)"
        }
    }

    /// Die Zirkel-Zeile fuer den Slot `schritt` -- die einzige Rechnung,
    /// damit Pause und Geraet nicht auseinanderlaufen. Ohne `schritt` der
    /// naechste Slot des Zirkels (Pause; in der Rundenpause schon die neue
    /// Runde), am Geraet der Slot der Route: nach dem Sichern ist der
    /// Zirkel schon weiter, der Screen noch nicht.
    static func zirkel(_ zirkel: Zirkel, schritt: Int? = nil) -> Ablaufzeile {
        let schritt = schritt ?? zirkel.schritt
        let anzahl = zirkel.uebungen.count
        return .zirkel(station: schritt % anzahl + 1, von: anzahl,
                       runde: schritt / anzahl + 1, runden: zirkel.runden)
    }
}

/// Die Ablaufzeile als kleine Pille (Board "Gerät · Plan · Tracker"): am
/// Geraet unter dem Uebungsnamen und im Pausen-Screen dieselbe.
struct AblaufzeilePille: View {
    let zeile: Ablaufzeile

    var body: some View {
        Text(zeile.text)
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(DesignSystem.Color.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, DesignSystem.Spacing.s8)
            .padding(.vertical, DesignSystem.Spacing.s4)
            .background(DesignSystem.Color.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.pille))
    }
}

/// Die Planposition, an der die Uebung am Geraet heute steht, mit ihrer
/// Vorgabe (E1). Gibt es nur, wenn die Uebung in der Einheit von heute als
/// (nicht ausgelassene) Position steht.
struct PlanStelleAmGeraet: Equatable {
    let positionKey: String
    /// 1-basiert in Ablauf-Reihenfolge, ohne ausgelassene Positionen.
    let nummer: Int
    /// Wie der Nenner von `PlanAnzeige.fortschritt`.
    let gesamt: Int
    let saetze: Int
    let wdhVon: Int?
    let wdhBis: Int?
    /// Saetze der Uebung ueber alle Geraete der Session
    /// (`PlanAnzeige.satzzahl`), nicht nur an diesem.
    let satzGemacht: Int
}
