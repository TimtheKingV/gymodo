import Foundation
import Testing
@testable import Sensorik

struct RuhewaechterTests {
    private func wert(t: TimeInterval, a: Vektor3 = Vektor3(x: 0, y: 0, z: 1),
                      dreh: Vektor3 = Vektor3(x: 0, y: 0, z: 0)) -> SensorMesswert {
        SensorMesswert(t: t, beschleunigung: a, drehrate: dreh, winkel: Vektor3(x: 0, y: 0, z: 0))
    }

    private func schlaeft(_ w: inout Ruhewaechter, _ m: SensorMesswert) -> Bool { w.pruefen(m) }

    @Test func standardFristSindZwanzigMinuten() {
        #expect(Ruhewaechter.standardFrist == 1200)
    }

    @Test func schlaeftNachZehnMinutenRuhe() {
        var waechter = Ruhewaechter(frist: 600)
        #expect(!schlaeft(&waechter, wert(t: 0)))
        #expect(!schlaeft(&waechter, wert(t: 599)))
        #expect(schlaeft(&waechter, wert(t: 600)))
    }

    @Test func bewegungStartetDieFristNeu() {
        var waechter = Ruhewaechter(frist: 600)
        _ = waechter.pruefen(wert(t: 0))
        #expect(!schlaeft(&waechter, wert(t: 500, dreh: Vektor3(x: 40, y: 0, z: 0))))
        #expect(!schlaeft(&waechter, wert(t: 1000)))
        #expect(schlaeft(&waechter, wert(t: 1100)))
    }

    @Test func geaenderteLageZaehltAlsBewegung() {
        var waechter = Ruhewaechter(frist: 600)
        _ = waechter.pruefen(wert(t: 0))
        #expect(!schlaeft(&waechter, wert(t: 550, a: Vektor3(x: 0.5, y: 0, z: 0.9))))
        #expect(!schlaeft(&waechter, wert(t: 1000, a: Vektor3(x: 0.5, y: 0, z: 0.9))))
        #expect(schlaeft(&waechter, wert(t: 1150, a: Vektor3(x: 0.5, y: 0, z: 0.9))))
    }

    @Test func rauschenIstKeineBewegung() {
        var waechter = Ruhewaechter(frist: 600)
        _ = waechter.pruefen(wert(t: 0))
        #expect(schlaeft(&waechter, wert(t: 700, a: Vektor3(x: 0.01, y: -0.01, z: 1.01),
                                      dreh: Vektor3(x: 1, y: -2, z: 0.5))))
    }

    @Test func zuruecksetzenZaehltNeu() {
        var waechter = Ruhewaechter(frist: 600)
        _ = waechter.pruefen(wert(t: 0))
        waechter.zuruecksetzen()
        #expect(!schlaeft(&waechter, wert(t: 700)))
        #expect(schlaeft(&waechter, wert(t: 1300)))
    }
}
