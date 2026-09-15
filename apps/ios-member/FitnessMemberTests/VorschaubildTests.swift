import Foundation
import Testing
import UIKit
@testable import FitnessMember

/// Die Liste dekodiert Geraetefotos direkt auf Vorschaugroesse -- ein
/// 12-MP-Foto in voller Aufloesung waeren rund 48 MB je Zeile.
struct VorschaubildTests {

    private func jpeg(breite: CGFloat, hoehe: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let bild = UIGraphicsImageRenderer(size: CGSize(width: breite, height: hoehe), format: format)
            .image { kontext in
                UIColor.gray.setFill()
                kontext.fill(CGRect(x: 0, y: 0, width: breite, height: hoehe))
            }
        return bild.jpegData(compressionQuality: 0.8)!
    }

    @Test func verkleinertAufDieLaengsteKante() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 2000, hoehe: 1000), kantePixel: 168))
        #expect(max(bild.width, bild.height) == 168)
        #expect(bild.width == 168 && bild.height == 84)
    }

    @Test func vergroessertKleineBilderNicht() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 100, hoehe: 80), kantePixel: 168))
        #expect(bild.width <= 100)
    }

    @Test func keinBildGibtNil() {
        #expect(Vorschau.verkleinert(Data("kein bild".utf8), kantePixel: 168) == nil)
    }
}
