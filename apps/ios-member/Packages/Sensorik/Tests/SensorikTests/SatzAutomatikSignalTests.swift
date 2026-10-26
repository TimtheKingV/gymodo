import Foundation
import Testing
@testable import Sensorik
struct SatzAutomatikSignalTests {
    @Test func ruhigerNachlaufErhaeltDieEndzahl() {
        let dt = 1.0 / 50
        var a: [Double] = Array(repeating: 0, count: 150)
        for k in 0..<500 { a.append(0.4 * 2 * .pi / 2 * cos(2 * .pi * Double(k) * dt / 2)) }
        a += Array(repeating: 0, count: 600)
        let werte = a.enumerated().map { i, wert in
            SensorMesswert(t: 100 + Double(i) * dt, beschleunigung: .init(x: 0, y: 0, z: 1 + wert / 9.81),
                drehrate: .init(x: 0, y: 0, z: 0), winkel: .init(x: 0, y: 0, z: 0))
        }
        for sekunden in [15, 20, 25] {
            let e = Satztakt.auswerten(Array(werte.prefix(sekunden * 50)), profil: .stapel)
            // Die Phasen-Auswertung kann ihre Anfangszeit nachtraeglich
            // verschieben. Die erhaltene Zahl darf deshalb nicht durch
            // Abschneiden synthetischer Wiederholungsintervalle sinken.
            #expect(e?.anzahl == 5)
        }
    }
}
