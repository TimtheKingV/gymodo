import Testing
@testable import FitnessMember

/// Wann zwischen Uebungswahl und Satzpfad der Screen "Training starten"
/// steht (Sammelstelle Punkt 10, Frage a).
struct TrainingStartTests {
    @Test func ohneLaufendesTrainingKommtDerStartscreen() {
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: "t", trainingLaeuft: false)
                == .start(machineId: "m1", exerciseId: "e1", token: "t"))
    }

    @Test func mittenImTrainingGehtEsDirektZumSatz() {
        // Das naechste Geraet kostet keinen Tap mehr als bisher.
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: nil, trainingLaeuft: true)
                == .geraet(machineId: "m1", exerciseId: "e1", token: nil))
    }
}
