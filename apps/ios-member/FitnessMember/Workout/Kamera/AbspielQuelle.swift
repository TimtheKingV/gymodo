#if DEBUG
import AVFoundation
import Koerperbild
import QuartzCore

/// Nur Debug: spielt ein Katalogvideo samt vorberechnetem Skelett in Echtzeit
/// und in Schleife ab, damit der Kamera-Ablauf im Simulator laeuft.
/// Gewaehlt ueber die Launch-Option `-kameraAbspielen <Repo-Wurzel>`.
@MainActor
final class AbspielQuelle: Bildquelle {
    let anzeige = AVSampleBufferDisplayLayer()
    var beiFehler: (@MainActor () -> Void)?
    private let wurzel: String
    private let name: String
    private var lauf: Lauf?

    init(wurzel: String, start: KameraStart) {
        self.wurzel = wurzel
        self.name = start.name
        anzeige.videoGravity = .resizeAspectFill
    }

    func starten(beiBild: @escaping @MainActor (Kamerabild) -> Void) async throws {
        guard let key = KameraTestprofile.katalogKey(name: name) else { throw BildquellenFehler.nichtVerfuegbar }
        let videoUrl = URL(fileURLWithPath: wurzel).appendingPathComponent("catalog/media/videos/\(key).mp4")
        let skelettUrl = URL(fileURLWithPath: wurzel).appendingPathComponent("data/koerperbild/skelette/\(key).skelett.json")
        guard let daten = try? Data(contentsOf: skelettUrl),
              let folge = try? Skelettfolge(daten: daten),
              FileManager.default.fileExists(atPath: videoUrl.path) else { throw BildquellenFehler.nichtVerfuegbar }
        let asset = AVURLAsset(url: videoUrl)
        guard let spur = try? await asset.loadTracks(withMediaType: .video).first,
              let rate = try? await spur.load(.nominalFrameRate) else { throw BildquellenFehler.nichtVerfuegbar }
        stoppen()
        let neu = Lauf(asset: asset, spur: spur, takt: 1 / Double(max(1, rate)), folge: folge,
                       renderer: anzeige.sampleBufferRenderer, beiBild: beiBild)
        lauf = neu
        neu.starten()
    }

    func stoppen() {
        lauf?.beenden()
        lauf = nil
    }

    /// Die Abspielschleife auf einem eigenen Thread.
    // @unchecked: AVAsset/AVAssetTrack sind nicht als Sendable markiert und werden nur
    // vom Schleifen-Thread benutzt; das Stopp-Flag steht hinter einem Schloss.
    private final class Lauf: @unchecked Sendable {
        private let asset: AVURLAsset
        private let spur: AVAssetTrack
        private let takt: Double
        private let folge: Skelettfolge
        private let renderer: AVSampleBufferVideoRenderer
        private let beiBild: @MainActor (Kamerabild) -> Void
        private let schloss = NSLock()
        private var laeuft = true

        init(asset: AVURLAsset, spur: AVAssetTrack, takt: Double, folge: Skelettfolge,
             renderer: AVSampleBufferVideoRenderer, beiBild: @escaping @MainActor (Kamerabild) -> Void) {
            self.asset = asset
            self.spur = spur
            self.takt = takt
            self.folge = folge
            self.renderer = renderer
            self.beiBild = beiBild
        }

        private var weiter: Bool { schloss.withLock { laeuft } }
        func beenden() { schloss.withLock { laeuft = false } }
        func starten() { Thread.detachNewThread { self.schleife() } }

        private func schleife() {
            while weiter {
                guard let leser = try? AVAssetReader(asset: asset) else { return }
                let aus = AVAssetReaderTrackOutput(track: spur, outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                ])
                leser.add(aus)
                guard leser.startReading() else { return }
                renderer.flush()
                var naechstes = CACurrentMediaTime()
                var nummer = 0
                while weiter, let probe = aus.copyNextSampleBuffer() {
                    let skelett = nummer < folge.bilder.count ? folge.bilder[nummer] : nil
                    nummer += 1
                    bildSofortZeigen(probe, auf: renderer)
                    let bild = Kamerabild(t: CACurrentMediaTime(), skelett: skelett, anzeige: probe)
                    let ruf = beiBild
                    Task { @MainActor in ruf(bild) }
                    naechstes += takt
                    let warten = naechstes - CACurrentMediaTime()
                    if warten > 0 { Thread.sleep(forTimeInterval: warten) } else { naechstes = CACurrentMediaTime() }
                }
            }
        }
    }
}
#endif
