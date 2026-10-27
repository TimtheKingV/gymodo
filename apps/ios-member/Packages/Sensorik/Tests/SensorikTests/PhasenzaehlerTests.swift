import Foundation
import Testing
@testable import Sensorik

struct PhasenzaehlerTests {
    private func y(_ i: Int) -> Double { 0.5 + 0.3 * sin(0.4 * Double(i)) + (i > 12 ? 0.2 : 0) }

    /// Referenzwerte aus `scipy.signal.butter(2, hz, fs=50)` mit `sosfilt_zi * x[0]`
    /// auf demselben Eingang (Indizes 0, 1, 5, 12, 13, 14, 29).
    @Test func filterGleichenScipy() {
        let x = (0..<30).map(y)
        let tief = Biquad.tiefpass(hz: 2, rate: 50).filtern(x)
        let hoch = Biquad.hochpass(hz: 0.15, rate: 50).filtern(x)
        let stellen = [0, 1, 5, 12, 13, 14, 29]
        let tiefSoll = [0.500000000000, 0.501560695259, 0.577594971826, 0.570758953272, 0.525910965569, 0.487504373931, 0.707820472613]
        let hochSoll = [0.0, 0.115278707387, 0.245578468251, -0.313066019930, -0.074201511928, 0.002343098579, -0.125867180261]
        for (k, i) in stellen.enumerated() {
            #expect(abs(tief[i] - tiefSoll[k]) < 1e-9)
            #expect(abs(hoch[i] - hochSoll[k]) < 1e-9)
        }
    }

    private func sinus(takt: Double, wiederholungen: Int, amplitude: Double = 0.3) -> [SensorMesswert] {
        let rate = 50.0
        let vor = 2.0
        let gesamt = vor + Double(wiederholungen) * takt + vor
        return (0..<Int(gesamt * rate)).map { i in
            let t = Double(i) / rate
            let a = (vor..<(vor + Double(wiederholungen) * takt)).contains(t) ? amplitude * sin((t - vor) * 2 * .pi / takt) : 0
            return SensorMesswert(t: 100 + t, beschleunigung: Vektor3(x: 0, y: 1 + a, z: 0),
                                  drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
    }

    @Test(arguments: [8, 12, 20])
    func zaehltEinfacheWiederholungen(n: Int) throws {
        let e = try #require(Phasenzaehler.auswerten(sinus(takt: 2.5, wiederholungen: n), rateHz: 50))
        #expect(abs(e.anzahl - n) <= 1)
        #expect(abs(e.takt - 2.5) < 0.3)
    }

    @Test func ruheGibtNichts() {
        let still = (0..<1000).map { i in
            SensorMesswert(t: Double(i) / 50, beschleunigung: Vektor3(x: 0, y: 1, z: 0.002 * sin(Double(i))),
                           drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
        #expect(Phasenzaehler.auswerten(still, rateHz: 50) == nil)
    }

    @Test func profilStapelNutztPhasenAndereArtenDieKette() {
        #expect(TaktProfil.fuer(.stapel)?.verfahren == .phasen)
        #expect(TaktProfil.fuer(.kurzhantel)?.verfahren == .kette)
        #expect(TaktProfil.fuer(.langhantel)?.verfahren == .kette)
        #expect(Satztakt.algo(fuer: .stapel) == "stapel/phasen1")
        #expect(Satztakt.algo(fuer: .kurzhantel) == "kurzhantel/takt2")
        #expect(Satztakt.algo(fuer: .langhantel) == "langhantel/takt1")
    }

    /// Alle 37 Stapelsaetze (14. und 18.10.): (Ordner, Wahrheit, Zahl des Python-Versuchs
    /// `phasenversuch.py`, Spalte `raw_phases`). Die Swift-Zahl muss mit Python uebereinstimmen;
    /// das ist die Gleichheit der Portierung, nicht der Nachweis, dass die Zahl stimmt.
    static let stapelSaetze: [(String, Int, Int)] = [
        ("2026-10-14-1747-01", 10, 10), ("2026-10-14-1749-01", 10, 10), ("2026-10-14-1751-01", 12, 12),
        ("2026-10-14-1753-01", 15, 15), ("2026-10-14-1755-01", 15, 15), ("2026-10-14-1756-01", 15, 15),
        ("2026-10-14-1758-01", 10, 10), ("2026-10-14-1759-01", 20, 20), ("2026-10-14-1801-01", 15, 15),
        ("2026-10-14-1803-01", 12, 12), ("2026-10-14-1807-01", 8, 8), ("2026-10-14-1810-01", 17, 18),
        ("2026-10-14-1812-01", 15, 15), ("2026-10-14-1814-01", 15, 15), ("2026-10-14-1837-01", 8, 8),
        ("2026-10-14-1838-01", 10, 10), ("2026-10-14-1840-01", 10, 10), ("2026-10-14-1846-01", 25, 25),
        ("2026-10-14-1848-01", 40, 40), ("2026-10-18-1626-01", 15, 15), ("2026-10-18-1628-01", 12, 12),
        ("2026-10-18-1630-01", 14, 14), ("2026-10-18-1632-01", 30, 30), ("2026-10-18-1634-01", 30, 30),
        ("2026-10-18-1635-01", 30, 30), ("2026-10-18-1638-01", 20, 20), ("2026-10-18-1640-01", 17, 17),
        ("2026-10-18-1642-01", 20, 20), ("2026-10-18-1643-01", 17, 18), ("2026-10-18-1645-01", 15, 15),
        ("2026-10-18-1646-01", 30, 31), ("2026-10-18-1648-01", 40, 40), ("2026-10-18-1649-02", 25, 25),
        ("2026-10-18-1650-02", 30, 30), ("2026-10-18-1652-01", 25, 25), ("2026-10-18-1708-01", 20, 20),
        ("2026-10-18-1709-01", 15, 14),
    ]

    @Test func stapelSaetzeGleichenDemPythonVersuch() throws {
        var exakt = 0, innerhalbEins = 0
        for (name, wahr, python) in Self.stapelSaetze {
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
            // Der Python-Versuch prueft den unveraenderten Phasenkern, nicht
            // die neue abschnittsweise Behandlung von Empfangsluecken.
            let roh = Phasenzaehler.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz))
            let gezaehlt = roh?.anzahl
            if !Satztakt.hatLuecke(in: eintraege) {
                #expect(AufnahmeLauf.taktergebnis(datei: datei, eintraege: eintraege, art: .stapel) == roh)
            }
            #expect(gezaehlt == python, "\(name): Swift \(gezaehlt.map(String.init) ?? "nil"), Python \(python)")
            if gezaehlt == wahr { exakt += 1 }
            if let gezaehlt, abs(gezaehlt - wahr) <= 1 { innerhalbEins += 1 }
        }
        #expect(exakt == 33)
        #expect(innerhalbEins == 37)
    }
}
