import Foundation

/// Wann der Trainings-Stack geleert wird, weil die Einheit von aussen
/// endete (Ortswechsel im Profil): ein offener Geraete-Screen stuende sonst
/// am alten Ort, und sein naechster Satz risse eine neue Einheit an.
enum Pfadbereinigung {
    /// Der Abschluss-Screen bleibt: TrainingRootView.beenden() setzt ihn im
    /// selben Zug, in dem die Einheit endet.
    static func leeren(laeuftVorher: Bool, laeuftJetzt: Bool, pfad: [GeraetRoute]) -> Bool {
        guard laeuftVorher, !laeuftJetzt else { return false }
        return !pfad.contains { if case .abschluss = $0 { true } else { false } }
    }
}
