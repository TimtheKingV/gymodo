import CoreML
import CoreVideo
import Koerperbild
import Vision

/// Apples eingebaute Koerpererkennung (Vision), ein Bild rein, ein Skelett raus.
public final class PoseErkenner {
    private var anfrage = VNDetectHumanBodyPoseRequest()

    public init() {
        #if targetEnvironment(simulator)
        einstellen()
        #endif
    }

    public private(set) var letzterFehler: String?

    #if targetEnvironment(simulator)
    // Der Simulator hat keine Neural Engine. Welche Einstellung dort laeuft,
    // wird der Reihe nach ausprobiert.
    private var einstellung = 0

    private func einstellen() {
        anfrage = VNDetectHumanBodyPoseRequest()
        switch einstellung {
        case 0:
            let cpu = MLComputeDevice.allComputeDevices.first {
                if case .cpu = $0 { true } else { false }
            }
            if let cpu { anfrage.setComputeDevice(cpu, for: .main) }
        case 1:
            anfrage.usesCPUOnly = true
        case 2:
            let gpu = MLComputeDevice.allComputeDevices.first {
                if case .gpu = $0 { true } else { false }
            }
            if let gpu { anfrage.setComputeDevice(gpu, for: .main) }
        default:
            break
        }
    }
    #endif

    public func erkennen(_ bild: CVPixelBuffer) -> Skelett? {
        let breite = Double(CVPixelBufferGetWidth(bild))
        let hoehe = Double(CVPixelBufferGetHeight(bild))
        let handler = VNImageRequestHandler(cvPixelBuffer: bild, orientation: .up, options: [:])
        do {
            try handler.perform([anfrage])
            letzterFehler = nil
        } catch {
            letzterFehler = "\(error)"
            #if targetEnvironment(simulator)
            letzterFehler = "Einstellung \(einstellung): \(error.localizedDescription)"
            if einstellung < 3 { einstellung += 1; einstellen() }
            #endif
            return nil
        }
        // Mehrere Personen im Bild: die groesste gewinnt.
        let kandidaten = (anfrage.results ?? []).compactMap { skelett(aus: $0, sv: breite / hoehe) }
        return kandidaten.max { groesse($0) < groesse($1) }
    }

    private func skelett(aus b: VNHumanBodyPoseObservation, sv: Double) -> Skelett? {
        guard let roh = try? b.recognizedPoints(.all) else { return nil }
        var punkte: [Gelenk: Punkt] = [:]
        for (gelenk, name) in Self.namen {
            guard let p = roh[name] else { continue }
            // Vision zaehlt von unten links, wir von oben links.
            punkte[gelenk] = Punkt(x: p.location.x, y: 1 - p.location.y, sicherheit: Double(p.confidence))
        }
        return Skelett(punkte: punkte, seitenverhaeltnis: sv)
    }

    private func groesse(_ s: Skelett) -> Double {
        let p = Gelenk.allCases.compactMap { s.sicher($0) }
        guard let x0 = p.map(\.x).min(), let x1 = p.map(\.x).max(),
              let y0 = p.map(\.y).min(), let y1 = p.map(\.y).max() else { return 0 }
        return (x1 - x0) * (y1 - y0)
    }

    private static let namen: [(Gelenk, VNHumanBodyPoseObservation.JointName)] = [
        (.nase, .nose), (.hals, .neck),
        (.schulterL, .leftShoulder), (.schulterR, .rightShoulder),
        (.ellbogenL, .leftElbow), (.ellbogenR, .rightElbow),
        (.handL, .leftWrist), (.handR, .rightWrist),
        (.wurzel, .root), (.hueftL, .leftHip), (.hueftR, .rightHip),
        (.knieL, .leftKnee), (.knieR, .rightKnee),
        (.fussL, .leftAnkle), (.fussR, .rightAnkle),
    ]
}
