#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct SensorStatistikTests {
    @Test func leerIstNull() {
        #expect(SensorStatistik().ergebnis(verworfeneBytes: 0) == .leer)
    }

    @Test func rateUndAbstaendeAusZeitstempeln() {
        var sut = SensorStatistik()
        // Abstaende 20, 20, 20, 40 ms -> 4 Abstaende in 100 ms = 40 Hz.
        for t in [10.00, 10.02, 10.04, 10.06, 10.10] { sut.erfassen(t: t) }
        let e = sut.ergebnis(verworfeneBytes: 3)
        #expect(e.pakete == 5)
        #expect(e.rateIstHz == 40.0)
        #expect(e.abstandMs == .init(median: 20, p95: 40, max: 40))
        #expect(e.luecken == 0)
        #expect(e.verworfeneBytes == 3)
    }

    @Test func gebuendelteMesswerteZeigenSichAlsAbstandNull() {
        var sut = SensorStatistik()
        for t in [1.00, 1.00, 1.04, 1.04] { sut.erfassen(t: t) }
        // Abstaende 0, 40, 0 -> Median 0. Die Buendelung bleibt sichtbar
        // statt herausgerechnet zu werden (Spec 5.1).
        #expect(sut.ergebnis(verworfeneBytes: 0).abstandMs.median == 0)
        #expect(sut.ergebnis(verworfeneBytes: 0).abstandMs.max == 40)
    }

    @Test func eineLueckeZaehltNichtAlsAbstand() {
        var sut = SensorStatistik()
        sut.erfassen(t: 1.00); sut.erfassen(t: 1.02)
        sut.lueckeBegonnen()
        sut.erfassen(t: 5.00); sut.erfassen(t: 5.02)
        let e = sut.ergebnis(verworfeneBytes: 0)
        #expect(e.luecken == 1)
        #expect(e.abstandMs.max == 20)
        #expect(e.rateIstHz == 50.0)
    }

    @Test func rateDerLetztenSekunde() {
        var sut = SensorStatistik()
        for n in 0..<150 { sut.erfassen(t: Double(n) * 0.02) }   // 3 s bei 50 Hz
        #expect(sut.rateLetzteSekunde(bis: 2.98) == 50)
        // Nach einer Sekunde Stille steht 0 da, nicht der alte Wert.
        #expect(sut.rateLetzteSekunde(bis: 4.5) == 0)
    }
}
#endif
