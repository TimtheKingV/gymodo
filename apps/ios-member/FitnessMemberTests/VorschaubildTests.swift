import Foundation
import Testing
import UIKit
@testable import FitnessMember

/// Die Liste dekodiert Geraetefotos direkt auf Vorschaugroesse -- ein
/// 12-MP-Foto in voller Aufloesung waeren rund 48 MB je Zeile. kantePixel
/// zielt auf die KURZE Kante (siehe Vorschau.verkleinert): die Zeile zeigt
/// ein quadratisches Bild, und die kurze Kante bestimmt dessen Schaerfe.
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

    @Test func verkleinertQuerformatAufDieKurzeKante() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 2000, hoehe: 1000), kantePixel: 168))
        #expect(bild.width == 336 && bild.height == 168)
    }

    @Test func verkleinertHochformatAufDieKurzeKante() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 1000, hoehe: 2000), kantePixel: 168))
        #expect(bild.width == 168 && bild.height == 336)
    }

    @Test func vergroessertKleineBilderNicht() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 100, hoehe: 80), kantePixel: 168))
        #expect(bild.width <= 100)
    }

    @Test func keinBildGibtNil() {
        #expect(Vorschau.verkleinert(Data("kein bild".utf8), kantePixel: 168) == nil)
    }
}

/// Faengt jede Anfrage ab und zaehlt sie -- prueft, dass VorschauLader
/// gleichzeitige Aufrufe fuer dasselbe Modell buendelt, statt das
/// Originalfoto zweimal zu laden.
private final class ZaehlendesURLProtocol: URLProtocol {
    nonisolated(unsafe) static var anzahl = 0
    nonisolated(unsafe) static var antwort = Data()
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.anzahl += 1
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.antwort)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("VorschauLader", .serialized)
struct VorschauLaderTests {
    private func jpeg() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 80), format: format)
            .image { kontext in
                UIColor.gray.setFill()
                kontext.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
            }
        return bild.jpegData(compressionQuality: 0.8)!
    }

    @Test func zweiGleichzeitigeAufrufeDesselbenModellsLadenNurEinmal() async throws {
        ZaehlendesURLProtocol.anzahl = 0
        ZaehlendesURLProtocol.antwort = jpeg()
        let konfiguration = URLSessionConfiguration.ephemeral
        konfiguration.protocolClasses = [ZaehlendesURLProtocol.self]
        let lader = VorschauLader(session: URLSession(configuration: konfiguration))
        let url = URL(string: "https://example.test/foto.jpg")!

        async let erste = lader.bild(modellId: "modell-1", url: url, kantePixel: 168)
        async let zweite = lader.bild(modellId: "modell-1", url: url, kantePixel: 168)
        let (bildEins, bildZwei) = await (erste, zweite)

        #expect(bildEins != nil)
        #expect(bildZwei != nil)
        #expect(ZaehlendesURLProtocol.anzahl == 1)
    }
}
