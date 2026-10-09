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

    /// Das Sicherheitsnetz dort, wo der Satz entsteht: ein Geraet nennt sein
    /// Studio selbst, und der Server weist einen Satz ab, dessen Einheit an
    /// einem anderen Ort liegt -- er landete sicher unter den verworfenen.
    /// Liefert den Ort der laufenden Einheit, wenn das Geraet nicht dorthin
    /// gehoert. Ein Typ nimmt den Ort der Einheit an und ist nie ein Konflikt.
    static func satzKonflikt(station: Station, offeneEinheit: LokaleSession?) -> Ort? {
        guard station.machineId != nil, let laufend = offeneEinheit?.ort else { return nil }
        let geraeteOrt = station.studioId.map(Ort.studio) ?? .freiesTraining
        return geraeteOrt == laufend ? nil : laufend
    }
}
