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
    static func ziel(machineId: String, exerciseId: String, token: String?,
                     trainingLaeuft: Bool) -> GeraetRoute {
        trainingLaeuft
            ? .geraet(machineId: machineId, exerciseId: exerciseId, token: token)
            : .start(machineId: machineId, exerciseId: exerciseId, token: token)
    }
}
