import AVFoundation
import Koerperbild
import KoerperErkennung

/// Die Frontkamera mit Vision-Erkennung. Das Bild bleibt ungespiegelt und
/// aufrecht (damit links/rechts stimmen); gespiegelt wird nur die Anzeige.
@MainActor
final class FrontkameraQuelle: Bildquelle {
    let anzeige = AVSampleBufferDisplayLayer()
    var beiFehler: (@MainActor () -> Void)?
    private let kern: Kern
    /// Zaehlt Starts und Stopps; ein Start, der nach einem Stopp zurueckkehrt, gilt nicht mehr.
    private var laufNummer = 0

    init() {
        anzeige.videoGravity = .resizeAspectFill
        kern = Kern(renderer: anzeige.sampleBufferRenderer)
    }

    func starten(beiBild: @escaping @MainActor (Kamerabild) -> Void) async throws {
        laufNummer += 1
        let nummer = laufNummer
        guard await Kameraerlaubnis.anfragen() == .erlaubt else { throw BildquellenFehler.nichtErlaubt }
        guard nummer == laufNummer else { throw CancellationError() }
        let gefiltert: @MainActor (Kamerabild) -> Void = { [weak self] bild in
            guard let self, self.laufNummer == nummer else { return }
            beiBild(bild)
        }
        let beiAusfall: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.beiFehler?() }
        }
        let lief = await kern.starten(beiBild: gefiltert, beiAusfall: beiAusfall)
        guard nummer == laufNummer else {
            kern.stoppen()
            throw CancellationError()
        }
        guard lief else { throw BildquellenFehler.nichtVerfuegbar }
    }

    func stoppen() {
        laufNummer += 1
        kern.stoppen()
    }

    /// Alles, was AVFoundation auf der Capture-Queue anfasst.
    // @unchecked: Zustand wird nur auf `queue` gelesen und geschrieben (AVFoundation und
    // PoseErkenner sind nicht als Sendable markiert).
    private final class Kern: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
        private let queue = DispatchQueue(label: "gymtavo.kamera.front")
        private let sitzung = AVCaptureSession()
        private let ausgabe = AVCaptureVideoDataOutput()
        private let renderer: AVSampleBufferVideoRenderer
        private let erkenner = PoseErkenner()
        private var beiBild: (@MainActor (Kamerabild) -> Void)?
        private var drehung: AVCaptureDevice.RotationCoordinator?
        private var beobachtung: NSKeyValueObservation?
        private var beobachter: [NSObjectProtocol] = []

        init(renderer: AVSampleBufferVideoRenderer) { self.renderer = renderer }

        func starten(beiBild: @escaping @MainActor (Kamerabild) -> Void, beiAusfall: @escaping @Sendable () -> Void) async -> Bool {
            await withCheckedContinuation { weiter in
                queue.async {
                    self.beiBild = beiBild
                    guard self.einrichten(beiAusfall: beiAusfall) else {
                        weiter.resume(returning: false)
                        return
                    }
                    if !self.sitzung.isRunning { self.sitzung.startRunning() }
                    weiter.resume(returning: self.sitzung.isRunning)
                }
            }
        }

        func stoppen() {
            queue.async {
                self.beiBild = nil
                self.beobachter.forEach { NotificationCenter.default.removeObserver($0) }
                self.beobachter = []
                self.beobachtung = nil
                self.ausgabe.setSampleBufferDelegate(nil, queue: nil)
                if self.sitzung.isRunning { self.sitzung.stopRunning() }
            }
        }

        private func einrichten(beiAusfall: @escaping @Sendable () -> Void) -> Bool {
            guard let geraet = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let eingabe = try? AVCaptureDeviceInput(device: geraet) else { return false }
            sitzung.beginConfiguration()
            defer { sitzung.commitConfiguration() }
            sitzung.sessionPreset = .hd1280x720
            sitzung.inputs.forEach { sitzung.removeInput($0) }
            guard sitzung.canAddInput(eingabe) else { return false }
            sitzung.addInput(eingabe)
            if !sitzung.outputs.contains(ausgabe) {
                ausgabe.alwaysDiscardsLateVideoFrames = true
                guard sitzung.canAddOutput(ausgabe) else { return false }
                sitzung.addOutput(ausgabe)
            }
            // Delegate nur auf der eigenen Queue: ein Bild nach dem anderen, spaetere
            // fallen durch alwaysDiscardsLateVideoFrames weg, solange die Erkennung laeuft.
            ausgabe.setSampleBufferDelegate(self, queue: queue)
            guard let verbindung = ausgabe.connection(with: .video) else { return false }
            verbindung.automaticallyAdjustsVideoMirroring = false
            verbindung.isVideoMirrored = false

            let koordinator = AVCaptureDevice.RotationCoordinator(device: geraet, previewLayer: nil)
            drehung = koordinator
            winkelSetzen(koordinator.videoRotationAngleForHorizonLevelCapture)
            beobachtung = koordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] k, _ in
                let winkel = k.videoRotationAngleForHorizonLevelCapture
                guard let kern = self else { return }
                kern.queue.async { kern.winkelSetzen(winkel) }
            }
            beobachter.forEach { NotificationCenter.default.removeObserver($0) }
            // Laufzeitfehler und Unterbrechung (Anruf, Multitasking, Systemlast) gelten gleich als Ausfall.
            beobachter = [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification].map {
                NotificationCenter.default.addObserver(forName: $0, object: sitzung, queue: nil) { _ in beiAusfall() }
            }
            return true
        }

        /// Nur auf `queue` aufrufen.
        private func winkelSetzen(_ winkel: CGFloat) {
            guard let verbindung = ausgabe.connection(with: .video), verbindung.isVideoRotationAngleSupported(winkel) else { return }
            verbindung.videoRotationAngle = winkel
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput probe: CMSampleBuffer, from connection: AVCaptureConnection) {
            bildSofortZeigen(probe, auf: renderer)
            var skelett: Skelett?
            if let pixel = CMSampleBufferGetImageBuffer(probe) { skelett = erkenner.erkennen(pixel) }
            let bild = Kamerabild(t: CMSampleBufferGetPresentationTimeStamp(probe).seconds, skelett: skelett, anzeige: nil)
            guard let beiBild else { return }
            Task { @MainActor in beiBild(bild) }
        }
    }
}
