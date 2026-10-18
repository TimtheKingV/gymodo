import Foundation
import Testing
@testable import Sensorik

struct SatztaktTests {
    /// Aufheben, zehn gleichmaessige Wiederholungen, Ablegen, Ruhe.
    private func synthetisch(wiederholungen: Int, takt: Double = 1.9, rate: Double = 50) -> [SensorMesswert] {
        let dt = 1 / rate
        let vorlauf = 2.0, nachlauf = 3.0
        let gesamt = vorlauf + Double(wiederholungen) * takt + nachlauf
        return (0..<Int(gesamt * rate)).map { i in
            let t = Double(i) * dt
            var y = 1.0
            if t < vorlauf { y += 0.8 * sin(t * .pi / vorlauf) } // Aufheben: ein Hub, kein Takt
            else if t < vorlauf + Double(wiederholungen) * takt { y += 0.3 * sin((t - vorlauf) * 2 * .pi / takt) }
            return SensorMesswert(t: 100 + t, beschleunigung: Vektor3(x: 0, y: y, z: 0.05),
                                  drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
    }

    @Test(arguments: [6, 8, 10, 12])
    func zaehltDenTaktOhneAufhebenUndAblegen(n: Int) throws {
        let e = try #require(Satztakt.auswerten(synthetisch(wiederholungen: n)))
        // Auf eins genau: die Zuschlaege sind an echten Saetzen abgestimmt, deren
        // Ausschlag am Rand ausklingt; die Kastenform hier ist haerter.
        #expect(abs(e.anzahl - n) <= 1)
        #expect(abs(e.takt - 1.9) < 0.1)
    }

    @Test func kurzhantelProfilHatDieHeutigenWerte() throws {
        let p = try #require(TaktProfil.fuer(.kurzhantel))
        #expect(p.taktMin == 1.2 && p.taktMax == 3.0)
        #expect(p.kappFaktor == 1.5 && p.kandidatAnteil == 0.85)
        #expect(p.gleichheitMin == 0.9 && p.abstandMin == 0.75 && p.abstandMax == 1.3)
        #expect(p.mindestDauer == 5.0)
        #expect(Satztakt.algo(fuer: .kurzhantel) == "kurzhantel/takt2")
        #expect(Satztakt.algo(fuer: .stapel) == "stapel/takt1")
    }

    @Test func artenOhneProfilHabenKeins() {
        for art in [Befestigungsart.hebelarm, .kabelgriff, .koerper] { #expect(TaktProfil.fuer(art) == nil) }
        for art in [Befestigungsart.stapel, .langhantel, .kurzhantel] { #expect(TaktProfil.fuer(art) != nil) }
    }

    @Test func profilgrenzenRechnenInSekundenNichtInAbtastwerten() throws {
        let a = try #require(Satztakt.auswerten(synthetisch(wiederholungen: 8, rate: 50), rateHz: 50))
        let b = try #require(Satztakt.auswerten(synthetisch(wiederholungen: 8, rate: 100), rateHz: 100))
        #expect(abs(a.anzahl - b.anzahl) <= 1)
        #expect(abs(a.takt - b.takt) < 0.1)
    }

    @Test func ruheGibtNichts() {
        let still = (0..<500).map { i in
            SensorMesswert(t: Double(i) / 50, beschleunigung: Vektor3(x: 0, y: 1, z: 0),
                           drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
        #expect(Satztakt.auswerten(still) == nil)
    }

    @Test func zuKurzGibtNichts() {
        #expect(Satztakt.auswerten(Array(synthetisch(wiederholungen: 10).prefix(100))) == nil)
    }

    /// Die Saetze vom 16.10., fuer die der Takt eindeutig ist. Das Druecken
    /// ueber Kopf (Schulter, Trizeps) steht in `breiteMitToleranz`.
    @Test(arguments: [
        ("2026-10-16-0935-01", 10), ("2026-10-16-0936-02", 8), ("2026-10-16-0937-01", 6),
        ("2026-10-16-0938-01", 10), ("2026-10-16-0939-01", 10), ("2026-10-16-0940-01", 10),
    ])
    func echteSaetzeExakt(name: String, wahr: Int) throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        let e = try #require(Satztakt.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz)))
        #expect(e.anzahl == wahr)
    }

    @Test(arguments: [
        ("2026-10-16-0938-02", 10), ("2026-10-16-0940-02", 10), ("2026-10-16-0942-01", 9),
        ("2026-10-16-0944-01", 8), ("2026-10-16-1144-01", 7), ("2026-10-16-1145-02", 8),
        ("2026-10-16-1146-03", 7), ("2026-10-16-1148-01", 6),
        // Kurze Saetze, die Kette findet eine zu wenig: die erste Wiederholung
        // gleicht der zweiten zu wenig.
        ("2026-10-16-1149-02", 5), ("2026-10-16-1149-04", 6),
    ])
    func echteSaetzeAufEinsGenau(name: String, wahr: Int) throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        let e = try #require(Satztakt.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz)))
        #expect(abs(e.anzahl - wahr) <= 1)
    }

    /// Saetze, deren Rand die Schwelle auf der Huellkurve verfehlte (Schulterdruecken
    /// 12 statt 10, Trizeps 8 statt 7 und 7 statt 6): die Kette sich gleichender
    /// Wiederholungen laesst Aufheben und Ablegen heraus.
    @Test(arguments: [
        ("2026-10-16-0943-02", 10), ("2026-10-16-0945-01", 10), ("2026-10-16-1149-03", 5),
        ("2026-10-16-1146-03", 7), ("2026-10-16-1325-03", 6),
    ])
    func randAusDerKetteExakt(name: String, wahr: Int) throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        let e = try #require(Satztakt.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz)))
        #expect(e.anzahl == wahr)
    }

    /// Schulterdruecken: Aufheben und Ablegen sind staerker als die Wiederholungen
    /// und verschieben Takt und Huellkurve, wenn sie nicht gekappt werden.
    @Test(arguments: [
        ("2026-10-16-1327-02", 5), ("2026-10-16-1327-03", 5), ("2026-10-16-1327-04", 6),
    ])
    func schulterdrueckenExakt(name: String, wahr: Int) throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        let e = try #require(Satztakt.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz)))
        #expect(e.anzahl == wahr)
    }
}
