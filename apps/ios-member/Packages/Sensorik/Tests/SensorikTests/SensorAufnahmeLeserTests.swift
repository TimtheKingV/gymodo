import Foundation
import Testing
@testable import Sensorik

struct SensorAufnahmeLeserTests {
    @Test func dasVerbindlicheBeispielIstLesbar() throws {
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: Pfade.beispiel)
        #expect(gelesen.datei.format == SensorAufnahmeDatei.formatkennung)
        #expect(!gelesen.eintraege.isEmpty)
    }

    /// Vom iPhone kopierte Dateien enden mit Leerzeile; ein Windows-Editor
    /// macht CRLF daraus. Beides darf den Leser nicht stoppen.
    @Test func leereZeilenUndCRLFWerdenUebersprungen() throws {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("leser-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: Pfade.beispiel, to: ordner)
        defer { try? FileManager.default.removeItem(at: ordner) }
        let csvURL = ordner.appendingPathComponent("messwerte.csv")
        let original = try String(contentsOf: csvURL, encoding: .utf8)
        let anzahlVorher = try SensorAufnahmeLeser.lesen(ordner: ordner).eintraege.count
        let verbogen = original.replacingOccurrences(of: "\n", with: "\r\n") + "\r\n\r\n"
        try verbogen.write(to: csvURL, atomically: true, encoding: .utf8)
        #expect(try SensorAufnahmeLeser.lesen(ordner: ordner).eintraege.count == anzahlVorher)
    }

    @Test func alleEchtenAufnahmenSindLesbar() throws {
        let ordner = try FileManager.default.contentsOfDirectory(
            at: Pfade.aufnahmen, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        #expect(!ordner.isEmpty)
        for aufnahme in ordner {
            _ = try SensorAufnahmeLeser.lesen(ordner: aufnahme)
        }
    }
}
