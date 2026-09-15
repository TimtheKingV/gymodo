import ImageIO
import SwiftUI
import UIKit

/// Geraetefotos auf Vorschaugroesse dekodieren.
///
/// Bewusst nicht AsyncImage: das dekodiert in voller Aufloesung, und die
/// Fotos kommen unverkleinert aus dem Upload (bis 10 MiB, keine
/// Vorschaugroesse am Server).
enum Vorschau {
    static func verkleinert(_ daten: Data, kantePixel: Int) -> CGImage? {
        // ShouldCache false: sonst haelt die Quelle die volle Bitmap trotzdem.
        guard let quelle = CGImageSourceCreateWithData(
            daten as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: kantePixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(quelle, 0, optionen as CFDictionary)
    }
}

/// Laedt und merkt sich Vorschaubilder je Modell.
///
/// Schluessel ist das Modell, nicht die URL: die signierte URL traegt einen
/// Token und ist bei jedem Oeffnen der Liste eine andere.
actor VorschauLader {
    private let session: URLSession
    private var fertig: [String: UIImage] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func bild(modellId: String, url: URL, kantePixel: Int) async -> UIImage? {
        if let vorhanden = fertig[modellId] { return vorhanden }
        guard let geladen = try? await session.data(from: url),
              (geladen.1 as? HTTPURLResponse)?.statusCode == 200,
              let verkleinert = Vorschau.verkleinert(geladen.0, kantePixel: kantePixel)
        else { return nil }
        let bild = UIImage(cgImage: verkleinert)
        fertig[modellId] = bild
        return bild
    }
}
