import Foundation

/// Regeln, die den Pfad des Training-Tabs umbauen -- als reine Funktionen,
/// damit sie ohne NavigationStack pruefbar sind.
enum Pfadregel {
    /// Das Kreuz der Einweisung fuehrt auf die Seite des Geraets, nicht
    /// zurueck zur Liste (Testnotiz 11.10., #6). Liegt sie schon unter dem
    /// Satzpfad, ein Schritt zurueck; sonst (Direktsprung beim Scan) tritt
    /// sie an seine Stelle. Ein Geraet mit nur einer Uebung hat keine
    /// Geraeteseite (#4) -- dort geht es zur Liste.
    static func nachEinweisungAbbruch(pfad: [GeraetRoute], uebungsanzahl: Int) -> [GeraetRoute] {
        guard case .geraet(let station, _, let token) = pfad.last else { return [] }
        let darunter = pfad.dropLast()
        if case .erkannt = darunter.last { return Array(darunter) }
        guard uebungsanzahl > 1 else { return [] }
        return darunter + [.erkannt(station: station, token: token)]
    }
}
