import Foundation

/// Eine Einheit gehoert genau einem Ort. Wer den Ort wechselt, waehrend
/// eine Einheit offen ist, soll sie erst bewusst beenden -- sonst landeten
/// Saetze des neuen Orts still in der alten Einheit.
enum Ortswechsel {
    enum Ergebnis: Equatable {
        case sofort
        case erstBeenden(laufenderOrt: Ort)
    }

    /// Eine Einheit ohne gespeicherten Ort (Datei von vor dem Katalog, oder
    /// noch kein Satz) zaehlt als am `aktuell`en Ort: sie war dort, als sie
    /// begann, und ein Dialog ohne bekannten Anlass waere nur Rauschen.
    static func pruefen(ziel: Ort, aktuell: Ort, offeneEinheit: LokaleSession?) -> Ergebnis {
        guard let offeneEinheit else { return .sofort }
        let laufend = offeneEinheit.ort ?? aktuell
        return laufend == ziel ? .sofort : .erstBeenden(laufenderOrt: laufend)
    }
}
