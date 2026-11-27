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
    /// Nur Debug mit Testprofilen: Katalogschluessel je exerciseId fuer die Abspielquelle.
    private let katalogKeys: [String: String]

    /// `testprofile`: Kameraangaben aus `KameraTestprofile` ergaenzen, nur im
    /// Debug-Build; im Release-Build ohne Wirkung.
    init(bootstrap: BootstrapResponse?, testprofile: Bool) {
        var uebungen: [String: BootstrapResponse.Exercise] = [:]
        #if DEBUG
        var keys: [String: String] = [:]
        #endif
        if let bootstrap {
            let alle = bootstrap.machines.flatMap(\.exercises)
                + (bootstrap.catalog?.equipmentTypes.flatMap(\.exercises) ?? [])
            for uebung in alle where uebungen[uebung.id] == nil {
                #if DEBUG
                uebungen[uebung.id] = testprofile
                    ? KameraTestprofile.ergaenzt(uebung, eingeschaltet: true, imFlow: true) : uebung
                if testprofile, uebung.kamera == nil, let key = KameraTestprofile.flowKatalogKey(name: uebung.name) {
                    keys[uebung.id] = key
                }
                #else
                uebungen[uebung.id] = uebung
                #endif
            }
        }
        jeId = uebungen
        #if DEBUG
        katalogKeys = keys
        #else
        katalogKeys = [:]
        #endif
    }

    /// Der Aufloeser fuer die Ansicht: ein vorhandener bleibt; ein neuer wird nur
    /// gemerkt (`merken`), wenn der Bootstrap schon da ist. Sonst blieben alle
    /// Schritte am Ring, bis die Ansicht neu geoeffnet wird.
    static func bereit(vorhanden: FlowUebungen?, bootstrap: BootstrapResponse?,
                       testprofile: Bool) -> (uebungen: FlowUebungen, merken: Bool) {
        if let vorhanden { return (vorhanden, false) }
        return (FlowUebungen(bootstrap: bootstrap, testprofile: testprofile), bootstrap != nil)
    }

    func uebung(_ schritt: FlowSchritt) -> BootstrapResponse.Exercise? {
        schritt.exerciseId.flatMap { jeId[$0] }
    }

    func ansicht(_ schritt: FlowSchritt, mitKamera: Bool) -> FlowSchrittAnsicht {
        guard let id = schritt.exerciseId, let uebung = uebung(schritt) else { return .ring }
        if mitKamera, var start = uebung.kameraStart(satzZiel: 1, sollWiederholungen: nil) {
            start.katalogKey = katalogKeys[id]
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
