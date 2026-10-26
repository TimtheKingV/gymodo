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
        #expect(Satztakt.algo(fuer: .stapel) == "stapel/phasen1")
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

    private func werte(_ name: String) throws -> (messwerte: [SensorMesswert], rate: Double) {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        return (eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }, Double(datei.sensor.rateSollHz))
    }

    /// Bankdruecken 18.10.: die Kette findet 4 von 8, die Aktivdauer der Huellkurve 7.
    @Test func ketteZuKurzSchaetztAusDerAktivdauer() throws {
        let (m, rate) = try werte("2026-10-18-1619-01")
        let e = try #require(Satztakt.auswerten(m, rateHz: rate))
        #expect(abs(e.anzahl - 8) <= 1)
        #expect(e.guete < 0.5)
    }

    /// Latzug/Beinpresse mit Stapel-Profil: die Kette riss bei 14 von 30 ab.
    @Test func rissInDerKetteWirdUeberbruecktMitStapelProfil() throws {
        let (m, rate) = try werte("2026-10-18-1646-01")
        let stapel = TaktProfil(taktMin: 1.0, taktMax: 4.0, kappFaktor: 1.5, kandidatAnteil: 0.85,
                                gleichheitMin: 0.8, abstandMin: 0.75, abstandMax: 1.3, mindestDauer: 5)
        let e = try #require(Satztakt.auswerten(m, rateHz: rate, profil: stapel))
        #expect(abs(e.anzahl - 30) <= 1)
    }

    /// Takt ausserhalb der Profilgrenzen (3,2 s bei taktMax 3): trotzdem eine
    /// Zahl, aber als unsicher gekennzeichnet.
    @Test func taktAusserhalbDerGrenzenGibtEineUnsichereZahl() throws {
        let (m, rate) = try werte("2026-10-14-1747-01")
        let e = try #require(Satztakt.auswerten(m, rateHz: rate))
        #expect(abs(e.anzahl - 10) <= 1)
        #expect(e.guete < 0.5)
    }

    /// Zwei Haelften mit acht Sekunden Pause (Unterhaltung): beide zaehlen.
    @Test func pauseImSatzZaehltBeideHaelften() throws {
        let rate = 50.0, takt = 2.0
        let dt = 1 / rate
        func y(_ t: Double) -> Double {
            if t < 2 { return 1 + 0.8 * sin(t * .pi / 2) }
            if (2..<14).contains(t) || (22..<34).contains(t) {
                let lokal = t < 14 ? t - 2 : t - 22
                return 1 + 0.3 * sin(lokal * 2 * .pi / takt)
            }
            return 1
        }
        let m = (0..<Int(37 * rate)).map { i -> SensorMesswert in
            let t = Double(i) * dt
            return SensorMesswert(t: 100 + t, beschleunigung: Vektor3(x: 0, y: y(t), z: 0.05),
                                  drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
        let e = try #require(Satztakt.auswerten(m, rateHz: rate))
        // Die Huellkurve verlaengert jeden Lauf an den Raendern um rund einen Takt; mit zwei
        // Laeufen sind das +2. Wichtig ist, dass beide Haelften zaehlen (sonst 6).
        #expect(abs(e.anzahl - 12) <= 2)
    }

    /// Empfangszeiten im Hintergrund koennen gebuendelt sein. Ueber der
    /// bestehenden 0,5-s-Grenze gilt auch die Satzende-Zahl als unsicher;
    /// Abschnitte duerfen nicht mehr durch diese Empfangsluecken reichen.
    @Test(arguments: ["2026-10-18-1628-01", "2026-10-18-1630-01"])
    func hintergrundSaetzeBleibenBeiPaketlueckenUnsicher(name: String) throws {
        let (m, rate) = try werte(name)
        let e = Satztakt.auswerten(m, rateHz: rate, profil: .stapel)
        if let e {
            #expect(e.hatLuecke)
            #expect(e.guete <= Satztakt.unsicherGrenze)
            for w in Satztakt.wiederholungen(e) {
                #expect(!zip(m, m.dropFirst()).contains { a, b in
                    b.t - a.t > Satztakt.lueckeAb && w.beginn < b.t && w.ende > a.t
                })
            }
        }
    }

    @Test(arguments: [false, true])
    func lueckenTrennenDieAuswertungOhneFehlendeWiederholungenZuErfinden(explizit: Bool) throws {
        let a = synthetisch(wiederholungen: 8)
        let ende = try #require(a.last).t
        let versatz = ende - 100 + (explizit ? 0.02 : 5)
        let b = a.map { SensorMesswert(t: $0.t + versatz, beschleunigung: $0.beschleunigung,
                                      drehrate: $0.drehrate, winkel: $0.winkel) }
        let einzel = try #require(Satztakt.auswerten(a))
        let e = try #require(Satztakt.auswerten(a + b, trennstellen: explizit ? [a.count] : []))
        #expect(e.hatLuecke)
        #expect(e.abschnitte.count == 2)
        #expect(e.anzahl == 2 * einzel.anzahl)
        let w = Satztakt.wiederholungen(e)
        #expect(w.count == e.anzahl)
        #expect(w.map(\.nummer) == Array(1...e.anzahl))
        #expect(w.allSatisfy { $0.ende <= ende || $0.beginn >= b[0].t })
        #expect(e.guete <= Satztakt.unsicherGrenze)
    }

    @Test func offeneLueckeAmSatzendeBleibtUnsicher() throws {
        let m = synthetisch(wiederholungen: 8)
        let e = try #require(Satztakt.auswerten(m, trennstellen: [m.count]))
        #expect(e.hatLuecke)
        #expect(e.anzahl == Satztakt.auswerten(m)?.anzahl)
    }

    @Test func bankdrueckenVom26OktoberHatEineEchteUnterbrechung() throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(
            ordner: Pfade.aufnahmen.appendingPathComponent("2026-10-26-1741-01"))
        let e = try #require(Satztakt.auswerten(eintraege))
        #expect(datei.label.reps == 20)
        #expect(datei.zaehler?.gezaehlt == 19)
        #expect(e.hatLuecke)
        for w in Satztakt.wiederholungen(e) {
            for eintrag in eintraege {
                if case .luecke(let von, let bis) = eintrag {
                    #expect(w.ende <= von || w.beginn >= bis)
                }
            }
        }
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
