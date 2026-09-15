#if DEBUG
import UIKit

enum Bildschirmfoto {
    /// Fensterweise gezeichnet: Alerts und Systemblaetter liegen in eigenen
    /// Fenstern, ein keyWindow allein wuerde sie verlieren. Das eigene
    /// Fenster fehlt im Bild -- kein Knopf, kein Menue.
    @MainActor
    static func aufnehmen(szene: UIWindowScene, ohne eigenes: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = szene.screen.scale
        return UIGraphicsImageRenderer(bounds: szene.screen.bounds, format: format).image { _ in
            for fenster in szene.windows where fenster !== eigenes && !fenster.isHidden && fenster.alpha > 0 {
                fenster.drawHierarchy(in: fenster.frame, afterScreenUpdates: false)
            }
        }
    }
}

enum Ausschnitt {
    /// Punkte -> Pixel, nach aussen auf ganze Pixel gerundet und aufs Bild
    /// beschnitten. nil, wenn nichts uebrig bleibt.
    static func pixelRechteck(punkte: CGRect, scale: CGFloat, bildgroesse: CGSize) -> CGRect? {
        let r = punkte.standardized
        let minX = (r.minX * scale).rounded(.down)
        let minY = (r.minY * scale).rounded(.down)
        let maxX = (r.maxX * scale).rounded(.up)
        let maxY = (r.maxY * scale).rounded(.up)
        let roh = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let geschnitten = roh.intersection(CGRect(origin: .zero, size: bildgroesse))
        guard !geschnitten.isNull, geschnitten.width >= 1, geschnitten.height >= 1 else { return nil }
        return geschnitten
    }

    static func schneiden(_ bild: UIImage, punkte: CGRect) -> (bild: UIImage, rahmen: TestnotizEintrag.Ausschnittsrahmen)? {
        guard let cg = bild.cgImage else { return nil }
        let groesse = CGSize(width: cg.width, height: cg.height)
        guard let pixel = pixelRechteck(punkte: punkte, scale: bild.scale, bildgroesse: groesse),
              let teil = cg.cropping(to: pixel)
        else { return nil }
        let rahmen = TestnotizEintrag.Ausschnittsrahmen(
            points: TestnotizEintrag.Rechteck(punkte.standardized),
            pixels: TestnotizEintrag.Rechteck(pixel)
        )
        return (UIImage(cgImage: teil, scale: bild.scale, orientation: .up), rahmen)
    }
}
#endif
