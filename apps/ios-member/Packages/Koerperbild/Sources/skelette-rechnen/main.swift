// Rechnet die Uebungsvideos des Katalogs zu Skelett-Dateien:
//
//   swift run -c release skelette-rechnen <Ordner mit mp4> <Ausgabeordner>
//
// Je Video entsteht <Name>.skelett.json (eine `Skelettfolge`) und eine Zeile
// `<key> <Bilder> <Anteil erkannt %>`.

#if canImport(AVFoundation) && canImport(Vision)
import AVFoundation
import CoreVideo
import Foundation
import Koerperbild
import KoerperErkennung

let argumente = CommandLine.arguments
guard argumente.count == 3 else {
    print("Aufruf: skelette-rechnen <Ordner mit mp4> <Ausgabeordner>")
    exit(2)
}
let eingabe = URL(fileURLWithPath: argumente[1])
let ausgabe = URL(fileURLWithPath: argumente[2])
try FileManager.default.createDirectory(at: ausgabe, withIntermediateDirectories: true)

struct Ergebnis { var bilder: Int; var erkannt: Int }

func rechnen(_ datei: URL) async throws -> Ergebnis {
    let key = datei.deletingPathExtension().lastPathComponent
    let erkenner = PoseErkenner()
    let asset = AVURLAsset(url: datei)
    guard let spur = try await asset.loadTracks(withMediaType: .video).first else {
        throw NSError(domain: "skelette", code: 1, userInfo: [NSLocalizedDescriptionKey: "keine Videospur"])
    }
    let rate = Double(try await spur.load(.nominalFrameRate))
    let leser = try AVAssetReader(asset: asset)
    let einstellungen: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    // Ist das Video gedreht gespeichert, liefert die Spur die Bilder liegend.
    // Dann gibt die Bildkomposition sie aufrecht aus, wie sie angezeigt werden.
    let transform = try await spur.load(.preferredTransform)
    let roh = try await spur.load(.naturalSize)
    let gedreht = transform != .identity
    let aus: AVAssetReaderOutput
    if gedreht {
        let ausgabe = AVAssetReaderVideoCompositionOutput(videoTracks: [spur], videoSettings: einstellungen)
        ausgabe.videoComposition = try await AVVideoComposition.videoComposition(withPropertiesOf: asset)
        aus = ausgabe
    } else {
        aus = AVAssetReaderTrackOutput(track: spur, outputSettings: einstellungen)
    }
    leser.add(aus)
    guard leser.startReading() else {
        throw leser.error ?? NSError(domain: "skelette", code: 2)
    }

    var bilder: [Skelett?] = []
    var seitenverhaeltnis = 0.0
    while let probe = aus.copyNextSampleBuffer() {
        guard let bild = CMSampleBufferGetImageBuffer(probe) else { continue }
        if seitenverhaeltnis == 0 {
            seitenverhaeltnis = Double(CVPixelBufferGetWidth(bild)) / Double(CVPixelBufferGetHeight(bild))
        }
        bilder.append(erkenner.erkennen(bild))
    }
    guard !bilder.isEmpty else {
        throw NSError(domain: "skelette", code: 3, userInfo: [NSLocalizedDescriptionKey: "keine Bilder"])
    }
    if gedreht { FileHandle.standardError.write(Data("\(key): gedreht gespeichert, roh \(roh), Ausgabe \(seitenverhaeltnis)\n".utf8)) }

    let folge = Skelettfolge(bildrate: rate, seitenverhaeltnis: seitenverhaeltnis, bilder: bilder)
    try folge.daten().write(to: ausgabe.appendingPathComponent("\(key).skelett.json"))
    return Ergebnis(bilder: bilder.count, erkannt: bilder.compactMap { $0 }.count)
}

let dateien = try FileManager.default.contentsOfDirectory(at: eingabe, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "mp4" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var fehler = 0
for datei in dateien {
    let key = datei.deletingPathExtension().lastPathComponent
    do {
        let e = try await rechnen(datei)
        print(String(format: "%@ %d %.1f", key, e.bilder, 100 * Double(e.erkannt) / Double(e.bilder)))
    } catch {
        fehler += 1
        print("FEHLER \(key): \(error)")
    }
}
exit(fehler == 0 ? 0 : 1)
#else
import Foundation

print("skelette-rechnen laeuft nur unter macOS")
exit(2)
#endif
