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

    /// Training fortsetzen (Testnotiz 14.10., 18:45 #3): wird die Einheit
    /// des stehenden Abschlusses wieder aktiv, geht es zur Wurzel -- dort
    /// steht "Training laeuft". Nur genau diese Einheit: ein anderes Training
    /// setzt seinen Pfad selbst.
    static func nachFortsetzenLeeren(aktiveId: UUID?, pfad: [GeraetRoute]) -> Bool {
        guard let aktiveId, case .abschluss(let id, _)? = pfad.last else { return false }
        return id == aktiveId
    }
}
