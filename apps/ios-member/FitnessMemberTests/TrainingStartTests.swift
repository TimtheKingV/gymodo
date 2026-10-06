import Testing
@testable import FitnessMember

/// Wann zwischen Uebungswahl und Satzpfad der Screen "Training starten"
/// steht (Sammelstelle Punkt 10, Frage a).
struct TrainingStartTests {
    @Test func ohneLaufendesTrainingKommtDerStartscreen() {
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: "t", trainingLaeuft: false, erstkontakt: false)
                == .start(machineId: "m1", exerciseId: "e1", token: "t"))
    }

    @Test func mittenImTrainingGehtEsDirektZumSatz() {
        // Das naechste Geraet kostet keinen Tap mehr als bisher.
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: nil, trainingLaeuft: true, erstkontakt: false)
                == .geraet(machineId: "m1", exerciseId: "e1", token: nil))
    }

    @Test func beimErstkontaktKommtDerStartErstNachDerEinstellung() {
        // Testnotiz 06.10., #5: die Uhr soll nicht schon waehrend Einweisung
        // und Einstellung laufen. Der Erstkontakt haengt am Satzpfad und
        // bietet "Training starten" selbst als letzten Schritt an.
        #expect(TrainingStart.ziel(machineId: "m1", exerciseId: "e1", token: "t",
                                   trainingLaeuft: false, erstkontakt: true)
                == .geraet(machineId: "m1", exerciseId: "e1", token: "t"))
    }
}
