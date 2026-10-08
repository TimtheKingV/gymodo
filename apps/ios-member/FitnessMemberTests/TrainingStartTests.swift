import Testing
@testable import FitnessMember

/// Wann zwischen Uebungswahl und Satzpfad der Screen "Training starten"
/// steht (Sammelstelle Punkt 10, Frage a).
struct TrainingStartTests {
    @Test func ohneLaufendesTrainingKommtDerStartscreen() {
        #expect(TrainingStart.ziel(station: "geraet:m1", exerciseId: "e1", token: "t", trainingLaeuft: false, erstkontakt: false)
                == .start(station: "geraet:m1", exerciseId: "e1", token: "t"))
    }

    @Test func mittenImTrainingGehtEsDirektZumSatz() {
        // Das naechste Geraet kostet keinen Tap mehr als bisher.
        #expect(TrainingStart.ziel(station: "geraet:m1", exerciseId: "e1", token: nil, trainingLaeuft: true, erstkontakt: false)
                == .geraet(station: "geraet:m1", exerciseId: "e1", token: nil))
    }

    @Test func beimErstkontaktKommtDerStartErstNachDerEinstellung() {
        // Testnotiz 06.10., #5: die Uhr soll nicht schon waehrend Einweisung
        // und Einstellung laufen. Der Erstkontakt haengt am Satzpfad und
        // bietet "Training starten" selbst als letzten Schritt an.
        #expect(TrainingStart.ziel(station: "geraet:m1", exerciseId: "e1", token: "t",
                                   trainingLaeuft: false, erstkontakt: true)
                == .geraet(station: "geraet:m1", exerciseId: "e1", token: "t"))
    }

    /// Ein Typ nimmt denselben Weg wie ein Geraet -- die Route kennt nur den
    /// Stationsschluessel.
    @Test func einTypNimmtDenselbenWeg() {
        #expect(TrainingStart.ziel(station: "typ:em1", exerciseId: "e1", token: nil,
                                   trainingLaeuft: false, erstkontakt: false)
                == .start(station: "typ:em1", exerciseId: "e1", token: nil))
    }
}
