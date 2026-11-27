import CoreGraphics
import Testing
@testable import FitnessMember

@Suite struct StrichfigurTests {
    private let flaeche = CGSize(width: 390, height: 844)

    @Test func gespiegeltesZentrumBleibtMittig() {
        let p = Strichfigur.abbilden(x: 0.5, y: 0.5, seitenverhaeltnis: 16.0 / 9.0, in: flaeche, gespiegelt: true)
        #expect(abs(p.x - 195) < 0.001)
        #expect(abs(p.y - 422) < 0.001)
    }

    @Test func aspectFillVon16Zu9AufHochformat() {
        // Hoehe fuellt 844, Breite 844 * 16/9 = 1500,44, links ragen (1500,44 - 390) / 2 = 555,22 ueber.
        let rand = Strichfigur.abbilden(x: 0, y: 0, seitenverhaeltnis: 16.0 / 9.0, in: flaeche, gespiegelt: false)
        #expect(abs(rand.x - (-555.22)) < 0.01)
        #expect(abs(rand.y) < 0.001)
        let gespiegelt = Strichfigur.abbilden(x: 0, y: 1, seitenverhaeltnis: 16.0 / 9.0, in: flaeche, gespiegelt: true)
        #expect(abs(gespiegelt.x - (390 + 555.22)) < 0.01)
        #expect(abs(gespiegelt.y - 844) < 0.001)
    }
}
