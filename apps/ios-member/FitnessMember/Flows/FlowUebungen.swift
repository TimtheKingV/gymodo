import Foundation
import Koerperbild

/// Wie ein Flow-Schritt gezeigt wird: Ring wie bisher, das Video der
/// verknuepften Uebung, oder (nur mit Kameraangaben) der Kamera-Ablauf.
enum FlowSchrittAnsicht: Equatable {
    case ring
    case video(exerciseId: String)
    case kamera(KameraStart)
}

/// Loest den Verweis eines Flow-Schritts auf die Katalog-Uebung des Bootstraps
/// auf und bestimmt daraus die Ansicht. Reine Logik, ohne Kamera und Uhr.
struct FlowUebungen {
    private let jeId: [String: BootstrapResponse.Exercise]

    /// `testprofile`: Kameraangaben aus `KameraTestprofile` ergaenzen, nur im
    /// Debug-Build; im Release-Build ohne Wirkung.
    init(bootstrap: BootstrapResponse?, testprofile: Bool) {
        var uebungen: [String: BootstrapResponse.Exercise] = [:]
        if let bootstrap {
            let alle = bootstrap.machines.flatMap(\.exercises)
                + (bootstrap.catalog?.equipmentTypes.flatMap(\.exercises) ?? [])
            for uebung in alle where uebungen[uebung.id] == nil {
                #if DEBUG
                uebungen[uebung.id] = testprofile
                    ? KameraTestprofile.ergaenzt(uebung, eingeschaltet: true) : uebung
                #else
                uebungen[uebung.id] = uebung
                #endif
            }
        }
        jeId = uebungen
    }

    func uebung(_ schritt: FlowSchritt) -> BootstrapResponse.Exercise? {
        schritt.exerciseId.flatMap { jeId[$0] }
    }

    func ansicht(_ schritt: FlowSchritt, mitKamera: Bool) -> FlowSchrittAnsicht {
        guard let id = schritt.exerciseId, let uebung = uebung(schritt) else { return .ring }
        if mitKamera, let start = uebung.kameraStart(satzZiel: 1, sollWiederholungen: nil) {
            return .kamera(start)
        }
        return .video(exerciseId: id)
    }

    func hatKameraSchritt(_ flow: Flow) -> Bool {
        flow.schritte.contains { schritt in
            if case .kamera = ansicht(schritt, mitKamera: true) { return true }
            return false
        }
    }
}

extension Kameraprofil {
    /// Wohin das Mitglied schaut oder steht, wenn die Kamera zaehlt; nil ohne Kamera.
    var blickzeile: String? {
        switch self {
        case .ganzkoerperStehend, .stuetzBoden, .liegend: "Stell dich seitlich zur Kamera"
        case .oberkoerper, .zugHaengend: "Schau zur Kamera"
        case .ohneKamera: nil
        }
    }
}
