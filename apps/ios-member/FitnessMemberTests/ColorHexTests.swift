import SwiftUI
import Testing
@testable import FitnessMember

@Suite("Color+Hex")
struct ColorHexTests {
    @Test("dekodiert Akzentfarbe D4FF3F korrekt")
    func decodesAccent() {
        let color = Color(hex: 0xD4FF3F)
        let components = color.rgbaComponents
        #expect(abs(components.red - 0xD4.doubleValue) < 0.01)
        #expect(abs(components.green - 0xFF.doubleValue) < 0.01)
        #expect(abs(components.blue - 0x3F.doubleValue) < 0.01)
    }

    @Test("dekodiert Schwarzton bg 0A0B0D korrekt")
    func decodesBackground() {
        let components = Color(hex: 0x0A0B0D).rgbaComponents
        #expect(abs(components.red - 0x0A.doubleValue) < 0.01)
        #expect(abs(components.green - 0x0B.doubleValue) < 0.01)
        #expect(abs(components.blue - 0x0D.doubleValue) < 0.01)
    }
}

private extension Int {
    var doubleValue: Double { Double(self) / 255.0 }
}
