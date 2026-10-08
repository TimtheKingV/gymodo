import Foundation

/// Was der Satzpfad einem Mitschnitt erzaehlt -- und nicht mehr.
///
/// Immer kompiliert, obwohl der einzige Mitschnitt (der Sensor-Koordinator)
/// nur im Debug-Build existiert: GeraetModel wird auch im Release gebaut und
/// darf keinen Debug-Typ im Konstruktor tragen. Im Release ist der Parameter
/// nil und dieses Protokoll ohne Erfueller.
///
/// Keine Methode wirft und keine ist async: der Satz darf an einem
/// Mitschnitt weder scheitern noch auf ihn warten.
struct SatzMitschnittKontext: Equatable, Sendable {
    /// Geraet oder Geraetetyp -- die Befestigung des Sensors haengt an der
    /// Station, und am Typ gibt es keine machineId.
    let station: Station
    let exerciseId: String
    let exerciseName: String

    var machineName: String { station.equipmentModel.name }
}

struct GesicherterSatz: Equatable, Sendable {
    let sessionId: UUID
    let setId: UUID
    let setIndex: Int
    /// nil an Geraeten, die nicht in Kilogramm belasten (Cardio).
    let weightKg: Double?
    /// nil, wenn der Umfang keine Wiederholungen sind (Sekunden, Meter).
    let reps: Int?
    let problemFlag: Bool
}

@MainActor
protocol SatzMitschnitt: AnyObject {
    /// Die Raeder stehen da. Laeuft noch ein Mitschnitt (Uebungswechsel),
    /// gehoert er zum alten Kontext und wird abgebrochen.
    func eingabeBegonnen(_ kontext: SatzMitschnittKontext)
    func satzGesichert(_ satz: GesicherterSatz)
    func screenVerlassen()
}
