#if DEBUG
import UIKit
import Testing
@testable import FitnessMember

struct AusschnittTests {
    private let iphone = CGSize(width: 1125, height: 2436)

    @Test func rechnetPunkteInPixelUm() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 20, y: 412, width: 335, height: 96), scale: 3, bildgroesse: iphone)
        #expect(r == CGRect(x: 60, y: 1236, width: 1005, height: 288))
    }

    // 10,4 pt * 2 = 20,8 px -> 20; (10,4 + 10,2) * 2 = 41,2 px -> 42.
    @Test func rundetAufGanzePixelNachAussen() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 10.4, y: 10.4, width: 10.2, height: 10.2), scale: 2, bildgroesse: CGSize(width: 100, height: 100))
        #expect(r == CGRect(x: 20, y: 20, width: 22, height: 22))
    }

    @Test func beschneidetAufDasBild() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: -5, y: 790, width: 400, height: 60), scale: 3, bildgroesse: iphone)
        #expect(r == CGRect(x: 0, y: 2370, width: 1125, height: 66))
    }

    @Test func leererSchnittIstNil() {
        #expect(Ausschnitt.pixelRechteck(punkte: CGRect(x: 900, y: 0, width: 10, height: 10), scale: 3, bildgroesse: iphone) == nil)
    }

    // Von rechts unten nach links oben gezogen: negative Breite.
    @Test func normalisiertNegativeGesten() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 100, y: 100, width: -50, height: -50), scale: 2, bildgroesse: CGSize(width: 400, height: 400))
        #expect(r == CGRect(x: 100, y: 100, width: 100, height: 100))
    }

    @Test func schneidetDasBildUndMeldetBeideRahmen() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 40), format: format).image { kontext in
            UIColor.red.setFill()
            kontext.fill(CGRect(x: 0, y: 0, width: 50, height: 40))
        }
        let ergebnis = try #require(Ausschnitt.schneiden(bild, punkte: CGRect(x: 10, y: 5, width: 20, height: 10)))
        #expect(ergebnis.bild.size == CGSize(width: 20, height: 10))
        #expect(ergebnis.bild.scale == 2)
        #expect(ergebnis.rahmen.pixels == TestnotizEintrag.Rechteck(x: 20, y: 10, width: 40, height: 20))
        #expect(ergebnis.rahmen.points == TestnotizEintrag.Rechteck(x: 10, y: 5, width: 20, height: 10))
    }
}
#endif
