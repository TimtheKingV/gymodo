import Foundation

/// Wohin es nach der Wahl von Geraet und Uebung geht -- und wann der Screen
/// "Training starten" dazwischen steht (Sammelstelle Punkt 10, entschieden
/// 15. September).
///
/// Nur ohne laufendes Training. Mitten im Training kostet das naechste
/// Geraet keinen Tap mehr als bisher (Scan, Uebung, Satz); der Zirkel ueber
/// die Blockliste hat ohnehin immer ein laufendes Training. Drei Aufrufer
/// in TrainingRootView, eine Regel -- deshalb hier, mit Test.
enum TrainingStart {
    ///
    /// Beim Erstkontakt geht es ebenfalls direkt zum Satzpfad: dort laufen
    /// Einweisung und Einstellung, und "Training starten" kommt als ihr
    /// letzter Schritt -- die Uhr laeuft erst danach (Testnotiz 06.10., #5).
    static func ziel(machineId: String, exerciseId: String, token: String?,
                     trainingLaeuft: Bool, erstkontakt: Bool) -> GeraetRoute {
        trainingLaeuft || erstkontakt
            ? .geraet(machineId: machineId, exerciseId: exerciseId, token: token)
            : .start(machineId: machineId, exerciseId: exerciseId, token: token)
    }
}
