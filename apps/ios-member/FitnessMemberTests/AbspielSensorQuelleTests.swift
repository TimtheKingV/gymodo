#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

@MainActor
struct AbspielSensorQuelleTests {
    private final class Marker {}

    private func beispiel() throws -> URL {
        try #require(Bundle(for: Marker.self).url(forResource: "sensoraufnahme-beispiel", withExtension: nil))
    }

    @Test func dasVerbindlicheBeispielIstLesbar() throws {
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: try beispiel())
        #expect(gelesen.datei.format == SensorAufnahmeDatei.formatkennung)
        #expect(gelesen.datei.label.reps == 11)
        #expect(gelesen.datei.abschluss == .gesichert)
        #expect(gelesen.eintraege.count == 6)
        #expect(gelesen.eintraege[3] == .luecke(von: 0.04, bis: 2.5))
        #expect(gelesen.eintraege[0] == .messwert(SensorMesswert(
            t: 0,
            beschleunigung: Vektor3(x: 0.0125, y: -0.9981, z: 0.0312),
            drehrate: Vektor3(x: 1.25, y: -0.5, z: 0),
            winkel: Vektor3(x: -88.5, y: 1.25, z: 0))))
    }

    @Test func unbekanntesFormatWirdAbgelehnt() throws {
        let kopie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: try beispiel(), to: kopie)
        let kopf = kopie.appendingPathComponent("aufnahme.json")
        let text = try String(contentsOf: kopf, encoding: .utf8)
            .replacingOccurrences(of: "gymodo.sensoraufnahme/1", with: "gymodo.sensoraufnahme/9")
        try Data(text.utf8).write(to: kopf)
        #expect(throws: (any Error).self) { try SensorAufnahmeLeser.lesen(ordner: kopie) }
    }

    /// Der Vertragstest fuer B: was der Schreiber schreibt, liest der Leser.
    @Test func schreibenUndLesenErgibtDieselbenMesswerte() throws {
        let wurzel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let aufnahme = try SensorAufnahme(
            wurzel: wurzel, start: SensorAufnahmeTests.start, startT: 100,
            sensor: SensorAufnahmeTests.sensor, geraet: SensorAufnahmeTests.geraet,
            kontext: SensorAufnahmeTests.kontext, befestigung: nil, zeitzone: SensorAufnahmeTests.berlin)
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.00))
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.02))
        try aufnahme.abschliessen(.gesichert, kontext: SensorAufnahmeTests.kontext,
                                  label: .init(weightKg: 50, reps: 8, problemFlag: false), akkuProzent: nil,
                                  statistik: .leer, ende: SensorAufnahmeTests.start, endeT: 101)

        let gelesen = try SensorAufnahmeLeser.lesen(ordner: aufnahme.ordner)

        // t ist nach dem Roundtrip relativ zum Aufnahmestart.
        #expect(gelesen.eintraege == [
            .messwert(SensorAufnahmeTests.messwert(t: 0)),
            .messwert(SensorAufnahmeTests.messwert(t: 0.02)),
        ])
        #expect(gelesen.datei.label.reps == 8)
    }

    @Test func spieltMesswerteAbUndUeberspringtLuecken() async throws {
        let sut = try AbspielSensorQuelle(ordner: try beispiel(), tempo: .sofort)
        #expect(sut.zustand == .aus)
        let strom = sut.ereignisse()
        sut.verbinden()

        var messwerte: [SensorMesswert] = []
        var zustaende: [SensorZustand] = []
        for await ereignis in strom {
            switch ereignis {
            case .messwert(let m): messwerte.append(m)
            case .zustand(let z): zustaende.append(z)
            case .akku: break
            }
            if case .zustand(.getrennt(wirdNeuVerbunden: false)) = ereignis { break }
        }

        #expect(messwerte.map(\.t) == [0, 0.02, 0.04, 2.5, 2.52])
        // Die Luecke kommt als Zustandswechsel an der richtigen Stelle an.
        #expect(zustaende == [
            .verbunden(name: "WT901BLE67", akkuProzent: 82),
            .getrennt(wirdNeuVerbunden: true),
            .verbunden(name: "WT901BLE67", akkuProzent: 82),
            .getrennt(wirdNeuVerbunden: false),
        ])
    }

    // MARK: - .echtzeit / trennen() waehrend des Wartens

    /// Sammelt Ereignisse aus dem Strom im Hintergrund ein, damit der Test
    /// nicht selbst in einem `for await` haengen bleiben kann, nachdem er
    /// schon trennen() aufgerufen hat.
    @MainActor
    private final class Sammler {
        private(set) var ereignisse: [SensorEreignis] = []
        func anhaengen(_ ereignis: SensorEreignis) { ereignisse.append(ereignis) }
    }

    /// Kurze, selbst geschriebene Aufnahme fuer .echtzeit-Tests: die Luecke
    /// dauert nur 0.4 s, damit die Tests nicht auf die 2.5 s der Beispieldatei
    /// warten muessen.
    private func kurzeAufnahme() throws -> URL {
        let wurzel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let aufnahme = try SensorAufnahme(
            wurzel: wurzel, start: SensorAufnahmeTests.start, startT: 100,
            sensor: SensorAufnahmeTests.sensor, geraet: SensorAufnahmeTests.geraet,
            kontext: SensorAufnahmeTests.kontext, befestigung: nil, zeitzone: SensorAufnahmeTests.berlin)
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.00))
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.05))
        aufnahme.lueckeBeginnt(t: 100.05)
        try aufnahme.lueckeEndet(t: 100.45)
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.45))
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.50))
        try aufnahme.abschliessen(.gesichert, kontext: SensorAufnahmeTests.kontext,
                                  label: .init(weightKg: 50, reps: 8, problemFlag: false), akkuProzent: nil,
                                  statistik: .leer, ende: SensorAufnahmeTests.start, endeT: 100.50)
        return aufnahme.ordner
    }

    /// Pollt statt zu blockieren: ein `for await` nach trennen() koennte fuer
    /// immer haengen, wenn die Quelle sich (fehlerhaft) doch nochmal meldet.
    private func warteBis(timeoutMs: Int = 2000, _ bedingung: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while !bedingung(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func trennenWaehrendDerLueckeMeldetNichtWiederVerbunden() async throws {
        let sut = try AbspielSensorQuelle(ordner: try kurzeAufnahme(), tempo: .echtzeit)
        let sammler = Sammler()
        let strom = sut.ereignisse()
        let aufgabe = Task { @MainActor in
            for await ereignis in strom { sammler.anhaengen(ereignis) }
        }

        sut.verbinden()
        try await warteBis { sammler.ereignisse.contains(.zustand(.getrennt(wirdNeuVerbunden: true))) }
        sut.trennen()

        // Laenger als die restliche Luecke (0.4 s): kaeme der Fehler wieder
        // durch, meldete sich die Quelle in dieser Zeit erneut als verbunden.
        try await Task.sleep(for: .milliseconds(700))
        aufgabe.cancel()

        #expect(sut.zustand == .aus)
        let lueckenIndex = sammler.ereignisse.firstIndex(of: .zustand(.getrennt(wirdNeuVerbunden: true)))
        let danach = lueckenIndex.map { Array(sammler.ereignisse[($0 + 1)...]) } ?? []
        // trennen() selbst meldet legitim .aus -- alles danach waere der Fehler
        // (ein wiederholtes .verbunden oder ein Messwert nach dem Abbruch).
        let unerwartet = danach.filter { $0 != .zustand(.aus) }
        #expect(unerwartet.isEmpty, "nach trennen() duerfen keine weiteren Ereignisse mehr ankommen: \(unerwartet)")
    }

    /// Beweist nur, dass keine Messwerte oder Zustaende des alten Laufs in den
    /// neuen durchsickern -- NICHT den Abschluss-Guard selbst: die Luecke ist
    /// hier nicht der letzte Eintrag, der Schleifenkopf-Check faengt den alten
    /// Lauf schon vorher ab (siehe Fix-Runde 1/2).
    @Test func einAlterLaufStoertEinenNeuenNicht() async throws {
        let sut = try AbspielSensorQuelle(ordner: try kurzeAufnahme(), tempo: .echtzeit)
        let sammler = Sammler()
        let strom = sut.ereignisse()
        let aufgabe = Task { @MainActor in
            for await ereignis in strom { sammler.anhaengen(ereignis) }
        }

        sut.verbinden()
        sut.verbinden() // sofort erneut: lauf existiert schon, muss folgenlos bleiben
        // Erst auf das erste .verbunden warten: unter Last (paralleler Build)
        // reichen feste 20 ms nicht, bis der Sammler es gesehen hat. Die
        // Wartezeit danach gibt einem faelschlichen zweiten die Gelegenheit.
        try await warteBis {
            sammler.ereignisse.contains { if case .zustand(.verbunden) = $0 { true } else { false } }
        }
        try await Task.sleep(for: .milliseconds(20))
        let verbundenNachStart = sammler.ereignisse.filter {
            if case .zustand(.verbunden) = $0 { return true }
            return false
        }
        #expect(verbundenNachStart.count == 1)

        try await warteBis { sammler.ereignisse.contains(.zustand(.getrennt(wirdNeuVerbunden: true))) }
        sut.trennen()
        sut.verbinden()

        // Laenger als eine komplette Wiedergabe (rund 0.5 s): der neue Lauf
        // muss fertig werden, ohne dass der alte (abgebrochene) noch mitmischt.
        try await warteBis(timeoutMs: 3000) {
            sammler.ereignisse.contains(.zustand(.getrennt(wirdNeuVerbunden: false)))
        }
        // Reserve, damit ein evtl. doppelter Abschluss noch ankaeme.
        try await Task.sleep(for: .milliseconds(100))
        aufgabe.cancel()

        let abschluesse = sammler.ereignisse.filter { $0 == .zustand(.getrennt(wirdNeuVerbunden: false)) }
        #expect(abschluesse.count == 1)
        #expect(sut.zustand == .getrennt(wirdNeuVerbunden: false))
        let messwerte = sammler.ereignisse.compactMap { ereignis -> TimeInterval? in
            if case .messwert(let m) = ereignis { return m.t }
            return nil
        }
        // Der alte Lauf kommt nach der Luecke nicht mehr zum Zug: nur der
        // neue Lauf liefert 0.45 und 0.5.
        #expect(messwerte == [0, 0.05, 0, 0.05, 0.45, 0.5])
    }

    /// Aufnahme, die MIT einer offenen Luecke endet: der Sensor faellt am
    /// Ende des Satzes aus, abschliessen() traegt die Luecke bis zum Ende
    /// nach (Spec 6.2) -- eine ganz natuerliche Aufnahme, kein Kunstgriff.
    /// Wichtig fuer den Test unten: die Luecke ist damit der LETZTE Eintrag,
    /// es gibt also keine weitere Schleifen-Runde mehr, die einen veralteten
    /// Lauf ueber den `!Task.isCancelled`-Check am Schleifenkopf abfangen
    /// koennte -- nur eine Pruefung direkt nach dem Luecken-Schlaf kann das.
    private func kurzeAufnahmeMitOffenerLuecke() throws -> URL {
        let wurzel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let aufnahme = try SensorAufnahme(
            wurzel: wurzel, start: SensorAufnahmeTests.start, startT: 100,
            sensor: SensorAufnahmeTests.sensor, geraet: SensorAufnahmeTests.geraet,
            kontext: SensorAufnahmeTests.kontext, befestigung: nil, zeitzone: SensorAufnahmeTests.berlin)
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.00))
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.10))
        aufnahme.lueckeBeginnt(t: 100.10)
        // Keine weiteren Messwerte, kein lueckeEndet(): abschliessen()
        // schliesst die offene Luecke bis endeT von selbst.
        try aufnahme.abschliessen(.gesichert, kontext: SensorAufnahmeTests.kontext,
                                  label: .init(weightKg: 50, reps: 8, problemFlag: false), akkuProzent: nil,
                                  statistik: .leer, ende: SensorAufnahmeTests.start, endeT: 100.70)
        return aufnahme.ordner
    }

    /// Beweist die Pruefung direkt nach dem Luecken-Schlaf: die Luecke ist der
    /// letzte Eintrag, also gibt es keine weitere Schleifen-Runde mehr, die
    /// einen veralteten Lauf noch ueber den Schleifenkopf-Check abfangen
    /// koennte -- nur diese eine Pruefung schuetzt hier. Experimentell
    /// bestaetigt (Fix-Runde 2): entfernt man sie zusammen mit dem
    /// Abschluss-Guard, schlaegt dieser Test fehl; der Abschluss-Guard allein
    /// ist an dieser Stelle defensiv und wird von diesem Test nicht einzeln
    /// erreicht, weil die Luecken-Pruefung vorher schon zurueckkehrt.
    @Test func einAlterLaufBeendetEinenNeuenNichtVorzeitig() async throws {
        let sut = try AbspielSensorQuelle(ordner: try kurzeAufnahmeMitOffenerLuecke(), tempo: .echtzeit)
        let sammler = Sammler()
        let strom = sut.ereignisse()
        let aufgabe = Task { @MainActor in
            for await ereignis in strom { sammler.anhaengen(ereignis) }
        }

        sut.verbinden()
        try await warteBis { sammler.ereignisse.contains(.zustand(.getrennt(wirdNeuVerbunden: true))) }
        sut.trennen()
        sut.verbinden()

        // Der ALTE Lauf schlaeft 0.6 s (seine Luecke). Der NEUE Lauf faengt
        // bei 0 neu an, erreicht seine EIGENE Luecke erst nach 0.1 s und
        // schlaeft dann ebenfalls 0.6 s -- bei 0.65 s ist er also noch mitten
        // in seiner Luecke, waehrend der alte Lauf laengst haette "aufwachen"
        // muessen.
        try await Task.sleep(for: .milliseconds(650))

        #expect(!sammler.ereignisse.contains(.zustand(.getrennt(wirdNeuVerbunden: false))),
                "der alte Lauf hat sich nach seinem Schlaf faelschlich beendet, bevor der neue fertig war")

        let zustandWaehrendDesLaufs = sut.zustand
        sut.verbinden() // waehrend der neue Lauf noch laeuft: muss folgenlos bleiben
        #expect(sut.zustand == zustandWaehrendDesLaufs,
                "verbinden() hat den Zustand veraendert -- lauf war also nil, der alte Lauf hat ihn geklaut")

        try await warteBis(timeoutMs: 2000) {
            sammler.ereignisse.contains(.zustand(.getrennt(wirdNeuVerbunden: false)))
        }
        // Reserve, damit ein evtl. doppelter Abschluss noch ankaeme.
        try await Task.sleep(for: .milliseconds(100))
        aufgabe.cancel()

        let abschluesse = sammler.ereignisse.filter { $0 == .zustand(.getrennt(wirdNeuVerbunden: false)) }
        #expect(abschluesse.count == 1, "genau ein Abschluss -- vom neuen Lauf, nicht vom alten")
    }
}
#endif
