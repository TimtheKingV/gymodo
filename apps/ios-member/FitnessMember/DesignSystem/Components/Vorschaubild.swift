import ImageIO
import SwiftUI
import UIKit

/// Geraetefotos auf Vorschaugroesse dekodieren.
///
/// Bewusst nicht AsyncImage: das dekodiert in voller Aufloesung, und die
/// Fotos kommen unverkleinert aus dem Upload (bis 10 MiB, keine
/// Vorschaugroesse am Server).
enum Vorschau {
    /// `kantePixel` ist die Zielgroesse der KURZEN Kante, nicht der langen.
    /// Die Zeile zeigt ein quadratisches 56x56pt-Bild (`.scaledToFill`),
    /// das genau die kurze Kante der Vorlage abbildet: ein reines
    /// `kCGImageSourceThumbnailMaxPixelSize` begrenzt aber die LANGE Kante,
    /// bei einem nicht quadratischen Foto waere die kurze Kante danach
    /// kleiner als kantePixel und `.scaledToFill` streckt sie unscharf hoch.
    static func verkleinert(_ daten: Data, kantePixel: Int) -> CGImage? {
        // ShouldCache false: sonst haelt die Quelle die volle Bitmap trotzdem.
        guard let quelle = CGImageSourceCreateWithData(
            daten as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: langeKantenGroesse(quelle, kantePixel: kantePixel),
        ]
        return CGImageSourceCreateThumbnailAtIndex(quelle, 0, optionen as CFDictionary)
    }

    /// Rechnet die Zielgroesse der KURZEN Kante (kantePixel) in eine
    /// Zielgroesse der LANGEN Kante um, denn nur die kennt
    /// ThumbnailMaxPixelSize: `min(laengste Originalkante, kantePixel *
    /// laengste / kuerzeste)`. Das vergroessert nie (das `min` mit der
    /// Originalkante) und macht die kurze Kante nach der Verkleinerung
    /// genau kantePixel gross. Fehlen die Originalmasse, bleibt kantePixel
    /// die Vorgabe wie bisher (ThumbnailMaxPixelSize begrenzt dann die
    /// lange Kante, das ist besser als gar keine Verkleinerung).
    private static func langeKantenGroesse(_ quelle: CGImageSource, kantePixel: Int) -> Int {
        guard let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any],
              let breite = eigenschaften[kCGImagePropertyPixelWidth] as? Int,
              let hoehe = eigenschaften[kCGImagePropertyPixelHeight] as? Int,
              breite > 0, hoehe > 0
        else { return kantePixel }
        let laengste = Double(max(breite, hoehe))
        let kuerzeste = Double(min(breite, hoehe))
        let ziel = Double(kantePixel) * laengste / kuerzeste
        return Int(min(laengste, ziel).rounded())
    }
}

/// Laedt und merkt sich Vorschaubilder je Modell.
///
/// Schluessel ist das Modell, nicht die URL: die signierte URL traegt einen
/// Token und ist bei jedem Oeffnen der Liste eine andere.
actor VorschauLader {
    private let session: URLSession
    private var fertig: [String: UIImage] = [:]
    /// Laufende Downloads je Modell. Ohne das saehe eine zweite Zeile
    /// desselben Modells den fertig-Cache noch leer (Actor-Reentrancy legt
    /// den ersten Download bei seinem await frei) und stiesse einen
    /// zweiten Download desselben Originalfotos an.
    private var laufend: [String: Task<UIImage?, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func bild(modellId: String, url: URL, kantePixel: Int) async -> UIImage? {
        if let vorhanden = fertig[modellId] { return vorhanden }
        if let laufenderDownload = laufend[modellId] {
            return await laufenderDownload.value
        }
        // Erzeugen und in `laufend` ablegen passiert hier ohne await
        // dazwischen: eine gleichzeitige zweite Zeile desselben Modells
        // sieht den Eintrag deshalb garantiert, bevor sie selbst einen
        // Download anstossen koennte.
        let download = Task<UIImage?, Never> { [session] in
            guard let geladen = try? await session.data(from: url),
                  (geladen.1 as? HTTPURLResponse)?.statusCode == 200,
                  let verkleinert = Vorschau.verkleinert(geladen.0, kantePixel: kantePixel)
            else { return nil }
            return UIImage(cgImage: verkleinert)
        }
        laufend[modellId] = download
        let bild = await download.value
        laufend[modellId] = nil
        if let bild {
            fertig[modellId] = bild
        }
        // Eine Zeile, die waehrenddessen wegscrollt, storniert den
        // gemeinsamen Download nicht: der Task gehoert dem Modell, nicht
        // der Zeile -- eine andere Zeile desselben Modells oder ein
        // erneuter Besuch braucht das Ergebnis noch, und ein storniertes
        // Ergebnis wuerde beide leer ausgehen lassen.
        return bild
    }
}
