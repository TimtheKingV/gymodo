import AVFoundation
import Koerperbild

/// Ein Kamerabild samt Erkennung. `t` ist die Zeit des Bildes in Sekunden.
/// `anzeige` ist nur fuer die Weitergabe gedacht; das Livebild stellt die
/// Quelle selbst ein.
// @unchecked: CMSampleBuffer ist nicht als Sendable markiert, wird aber nur gelesen.
struct Kamerabild: @unchecked Sendable {
    let t: TimeInterval
    let skelett: Skelett?
    let anzeige: CMSampleBuffer?
}

enum BildquellenFehler: Error, Equatable { case nichtErlaubt, nichtVerfuegbar }

/// Woher die Bilder des Kamera-Ablaufs kommen: die echte Frontkamera oder im
/// Debug-Build eine Abspielquelle.
@MainActor protocol Bildquelle: AnyObject {
    /// Liefert Bilder auf dem MainActor. Wirft bei fehlender Erlaubnis/Kamera.
    func starten(beiBild: @escaping @MainActor (Kamerabild) -> Void) async throws
    func stoppen()
    /// Ziel fuer das Livebild; die Quelle stellt Bilder selbst ein.
    var anzeige: AVSampleBufferDisplayLayer { get }
    /// Meldet einen Ausfall nach dem Start (Kamera weg, Laufzeitfehler).
    var beiFehler: (@MainActor () -> Void)? { get set }
}

@MainActor enum Bildquellen {
    static func fuer(_ start: KameraStart) -> any Bildquelle {
        #if DEBUG
        if let wurzel = UserDefaults.standard.string(forKey: "kameraAbspielen"), !wurzel.isEmpty {
            return AbspielQuelle(wurzel: wurzel, start: start)
        }
        #endif
        return FrontkameraQuelle()
    }
}

/// Stellt ein Bild sofort ein, ohne auf seinen Zeitstempel zu warten.
/// Laeuft auf der Queue der Quelle (der Renderer ist dafuer gebaut).
func bildSofortZeigen(_ probe: CMSampleBuffer, auf renderer: AVSampleBufferVideoRenderer) {
    if let anhaenge = CMSampleBufferGetSampleAttachmentsArray(probe, createIfNecessary: true),
       CFArrayGetCount(anhaenge) > 0 {
        let eintrag = unsafeBitCast(CFArrayGetValueAtIndex(anhaenge, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            eintrag,
            Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
            Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
    }
    if renderer.status == .failed { renderer.flush() }
    renderer.enqueue(probe)
}
