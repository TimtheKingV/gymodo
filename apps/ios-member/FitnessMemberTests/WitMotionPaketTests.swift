#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct WitMotionPaketTests {
    /// ay = -2048 (-1 g), az = 2048 (1 g), gx = 16384 (1000 Grad/s), wx = -16384 (-90 Grad).
    static let messwert: [UInt8] = [
        0x55, 0x61,
        0x00, 0x00, 0x00, 0xF8, 0x00, 0x08,
        0x00, 0x40, 0x00, 0x00, 0x00, 0x00,
        0x00, 0xC0, 0x00, 0x00, 0x00, 0x00,
    ]
    /// Antwort auf "Akku lesen": Register 0x64, erster Wert 396 (3,96 V).
    static let register: [UInt8] = [0x55, 0x71, 0x64, 0x00, 0x8C, 0x01] + [UInt8](repeating: 0, count: 14)

    static let erwartet = WitMotionPaket.messwert(
        beschleunigung: Vektor3(x: 0, y: -1, z: 1),
        drehrate: Vektor3(x: 1000, y: 0, z: 0),
        winkel: Vektor3(x: -90, y: 0, z: 0)
    )

    @Test func liestEinPaketMitVorzeichenUndSkalierung() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data(Self.messwert)) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 0)
    }

    @Test func skaliertDieRaender() {
        var bytes = Self.messwert
        bytes[2] = 0x00; bytes[3] = 0x80   // ax = Int16.min
        bytes[4] = 0xFF; bytes[5] = 0x7F   // ay = Int16.max
        var sut = WitMotionParser()
        guard case .messwert(let a, _, _)? = sut.lesen(Data(bytes)).first else {
            Issue.record("kein Messwert"); return
        }
        #expect(a.x == -16)
        #expect(a.y == 32767.0 / 32768.0 * 16)
    }

    @Test func liestZweiPaketeAusEinerNotification() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data(Self.messwert + Self.messwert)) == [Self.erwartet, Self.erwartet])
    }

    @Test func setztEinGeteiltesPaketZusammen() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data(Self.messwert.prefix(7))).isEmpty)
        #expect(sut.lesen(Data(Self.messwert.dropFirst(7))) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 0)
    }

    @Test func haeltEinEinzelnesHeaderByteAmEndeZurueck() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data([0x55])).isEmpty)
        #expect(sut.lesen(Data(Self.messwert.dropFirst())) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 0)
    }

    @Test func richtetSichNachUnbekanntemNeuAusUndZaehlt() {
        var sut = WitMotionParser()
        // 0x55 0x00 ist kein Header: beide Bytes zaehlen als verworfen.
        #expect(sut.lesen(Data([0x01, 0x02, 0x55, 0x00] + Self.messwert)) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 4)
    }

    @Test func deutetEineRegisterantwortNieAlsMesswert() {
        var sut = WitMotionParser()
        let ergebnis = sut.lesen(Data(Self.register))
        #expect(ergebnis == [.register(adresse: 0x64, werte: [396, 0, 0, 0, 0, 0, 0, 0])])
    }

    @Test func leereDatenErgebenNichts() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data()).isEmpty)
        #expect(sut.verworfeneBytes == 0)
    }
}
#endif
