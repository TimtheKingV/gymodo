#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

@MainActor
final class AttrappenQuelle: SensorQuelle {
    var zustand: SensorZustand = .aus
    var rate: SensorRate = .hz50
    var verworfeneBytes = 0
    let verteiler = SensorVerteiler()
    func ereignisse() -> AsyncStream<SensorEreignis> { verteiler.strom() }
    func verbinden() {}
    func waehlen(_ fund: SensorFund) {}
    func trennen() {}
    func vergessen() {}
    func rateSetzen(_ rate: SensorRate) { self.rate = rate }
    func akkuLesen() {}
}

@MainActor
struct SensorAufnahmeKoordinatorTests {
    static let verbunden = SensorZustand.verbunden(name: "WT901BLE67", akkuProzent: 82)
    static let kontext = SatzMitschnittKontext(machineId: "m1", machineName: "Beinpresse",
                                               exerciseId: "e1", exerciseName: "Beidbeinig")
    static let satz = GesicherterSatz(sessionId: UUID(), setId: UUID(), setIndex: 2,
                                      weightKg: 77.5, reps: 11, problemFlag: false)

    final class Uhr { var t: TimeInterval = 100 }

    private func aufbau(zustand: SensorZustand = verbunden, wurzel: URL? = nil)
        -> (sut: SensorAufnahmeKoordinator, quelle: AttrappenQuelle, wurzel: URL, uhr: Uhr) {
        let quelle = AttrappenQuelle()
        quelle.zustand = zustand
        let wurzel = wurzel ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let uhr = Uhr()
        let einstellungen = UserDefaults(suiteName: UUID().uuidString)!
        let sut = SensorAufnahmeKoordinator(
            quelle: quelle, wurzel: wurzel, geraet: SensorAufnahmeTests.geraet,
            einstellungen: einstellungen, uhr: { uhr.t }, jetzt: { SensorAufnahmeTests.start })
        return (sut, quelle, wurzel, uhr)
    }

    private func ordner(in wurzel: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: wurzel, includingPropertiesForKeys: nil)) ?? [])
            .filter(\.hasDirectoryPath).sorted { $0.path < $1.path }
    }

    private func datei(_ ordner: URL) throws -> SensorAufnahmeDatei {
        try SensorAufnahmeLeser.lesen(ordner: ordner).datei
    }

    @Test func startetMitDerEingabeWennVerbunden() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        #expect(sut.aufnahmeLaeuft)
        #expect(try datei(ordner(in: wurzel)[0]).kontext.exerciseName == "Beidbeinig")
    }

    @Test func ohneVerbundenenSensorKeineAufnahme() {
        let (sut, _, wurzel, _) = aufbau(zustand: .aus)
        sut.eingabeBegonnen(Self.kontext)
        sut.satzGesichert(Self.satz)
        #expect(!sut.aufnahmeLaeuft)
        #expect(ordner(in: wurzel).isEmpty)
    }

    @Test func startetErstWennDerSensorSichMittenInDerEingabeVerbindet() {
        let (sut, quelle, wurzel, _) = aufbau(zustand: .sucht)
        sut.eingabeBegonnen(Self.kontext)
        #expect(!sut.aufnahmeLaeuft)
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        #expect(sut.aufnahmeLaeuft)
        #expect(ordner(in: wurzel).count == 1)
    }

    @Test func sichernSchliesstMitLabelsAb() throws {
        let (sut, _, wurzel, uhr) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        for n in 0..<5 { sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100 + Double(n) * 0.02))) }
        uhr.t = 130
        sut.satzGesichert(Self.satz)

        #expect(!sut.aufnahmeLaeuft)
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: ordner(in: wurzel)[0])
        #expect(gelesen.datei.abschluss == .gesichert)
        #expect(gelesen.datei.label == .init(weightKg: 77.5, reps: 11, problemFlag: false))
        #expect(gelesen.datei.kontext.setId == Self.satz.setId.uuidString)
        #expect(gelesen.datei.kontext.sessionId == Self.satz.sessionId.uuidString)
        #expect(gelesen.datei.kontext.setIndex == 2)
        #expect(gelesen.datei.statistik.pakete == 5)
        #expect(gelesen.datei.statistik.rateIstHz == 50)
        #expect(gelesen.eintraege.count == 5)
    }

    @Test func inDerPauseLaeuftNichtsUndDerNaechsteSatzBeginntNeu() {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.satzGesichert(Self.satz)
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 140)))   // Pause: geht nirgends hin
        sut.eingabeBegonnen(Self.kontext)
        #expect(ordner(in: wurzel).count == 2)
        #expect(sut.aufnahmeLaeuft)
    }

    @Test func verlassenOhneSichernBrichtAb() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.screenVerlassen()
        let d = try datei(ordner(in: wurzel)[0])
        #expect(d.abschluss == .abgebrochen)
        #expect(d.label.reps == nil)
        // Nach dem Verlassen wartet niemand mehr auf einen Sensor.
        sut.empfangen(.zustand(Self.verbunden))
        #expect(!sut.aufnahmeLaeuft)
    }

    @Test func neueEingabeBrichtEineLaufendeAufnahmeAb() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.eingabeBegonnen(SatzMitschnittKontext(machineId: "m1", machineName: "Beinpresse",
                                                  exerciseId: "e2", exerciseName: "Einbeinig"))
        let alle = ordner(in: wurzel)
        #expect(alle.count == 2)
        #expect(try datei(alle[0]).abschluss == .abgebrochen)
        #expect(try datei(alle[1]).kontext.exerciseId == "e2")
    }

    @Test func abrissSchreibtEineLueckeUndDieAufnahmeLaeuftWeiter() throws {
        let (sut, quelle, wurzel, uhr) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100)))
        uhr.t = 105
        quelle.zustand = .getrennt(wirdNeuVerbunden: true)
        sut.empfangen(.zustand(quelle.zustand))
        #expect(sut.aufnahmeLaeuft)
        uhr.t = 108
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 108)))
        sut.satzGesichert(Self.satz)

        let gelesen = try SensorAufnahmeLeser.lesen(ordner: ordner(in: wurzel)[0])
        #expect(gelesen.eintraege.contains(.luecke(von: 5, bis: 8)))
        #expect(gelesen.datei.statistik.luecken == 1)
        #expect(gelesen.datei.abschluss == .gesichert)
    }

    @Test func einSchreibfehlerLaesstDasSichernDurchlaufen() throws {
        // Die Wurzel ist eine DATEI: der Ordner laesst sich nicht anlegen.
        let kaputt = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: kaputt)
        let (sut, _, _, _) = aufbau(wurzel: kaputt)

        sut.eingabeBegonnen(Self.kontext)
        #expect(!sut.aufnahmeLaeuft)
        #expect(sut.fehler != nil)
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100)))
        sut.satzGesichert(Self.satz)     // wirft nicht, stuerzt nicht ab
        sut.screenVerlassen()
    }

    @Test func derFehlerVerschwindetMitDemNaechstenSatz() throws {
        let kaputt = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: kaputt)
        let (sut, _, _, _) = aufbau(wurzel: kaputt)
        sut.eingabeBegonnen(Self.kontext)
        #expect(sut.fehler != nil)
        try FileManager.default.removeItem(at: kaputt)
        sut.eingabeBegonnen(Self.kontext)
        #expect(sut.fehler == nil)
        #expect(sut.aufnahmeLaeuft)
    }

    @Test func befestigungWirdJeGeraetGemerktUndLandetInDerAufnahme() throws {
        let (sut, _, wurzel, _) = aufbau()
        #expect(sut.befestigung(fuer: "m1") == "")
        sut.befestigungSetzen("Gewichtsstapel oben", fuer: "m1")
        #expect(sut.befestigung(fuer: "m1") == "Gewichtsstapel oben")
        #expect(sut.befestigung(fuer: "m2") == "")
        sut.eingabeBegonnen(Self.kontext)
        #expect(try datei(ordner(in: wurzel)[0]).befestigung == "Gewichtsstapel oben")
    }

    @Test func anzeigeRateFolgtDenMesswerten() {
        let (sut, _, _, uhr) = aufbau()
        for n in 0..<100 {
            uhr.t = 100 + Double(n) * 0.02
            sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: uhr.t)))
        }
        #expect(sut.anzeigeRateHz == 50)
        #expect(sut.statistik.pakete > 0)
    }

    @Test func ratentestSchreibtNachFuenfMinutenEineDatei() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.ratentestStarten()
        #expect(sut.ratentestRest == 300)
        // 10 Hz reichen, um die Logik zu pruefen, und halten den Test kurz.
        for n in 0...3001 { sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100 + Double(n) * 0.1))) }

        #expect(sut.ratentestRest == nil)
        let url = try #require(sut.letzterRatentest)
        #expect(url.deletingLastPathComponent().path == wurzel.path)
        #expect(url.lastPathComponent == "ratentest-2026-09-19-1412.json")
        let ergebnis = try JSONDecoder.testnotiz().decode(SensorRatentestDatei.self, from: Data(contentsOf: url))
        #expect(ergebnis.format == SensorRatentestDatei.formatkennung)
        #expect(ergebnis.statistik.rateIstHz == 10)
        #expect(ergebnis.sensor.name == "WT901BLE67")
    }
}
#endif
