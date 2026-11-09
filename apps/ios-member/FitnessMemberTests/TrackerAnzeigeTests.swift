#if DEBUG
import Foundation
import Testing
import Sensorik
@testable import FitnessMember

/// Paket 3: grün = verbunden, grau = alles andere (nie rot); sichtbar nur
/// mit gemerktem Tracker.
struct TrackerAnzeigeTests {
    @Test func verbundenIstGruen() {
        let zustand = SensorZustand.verbunden(name: "WT901BLE", akkuProzent: 80)
        #expect(TrackerAnzeige.symbol(zustand) == .verbunden)
        #expect(TrackerAnzeige.status(zustand) == "Verbunden · Akku 80 %")
    }

    @Test func verbundenOhneAkkuwert() {
        #expect(TrackerAnzeige.status(.verbunden(name: "WT901BLE", akkuProzent: nil)) == "Verbunden")
    }

    @Test func akkuNiedrigBleibtGruen() {
        let zustand = SensorZustand.verbunden(name: "WT901BLE", akkuProzent: 10)
        #expect(TrackerAnzeige.symbol(zustand) == .verbunden)
        #expect(TrackerAnzeige.status(zustand) == "Verbunden · Akku 10 %")
    }

    @Test func suchtIstGrau() {
        #expect(TrackerAnzeige.symbol(.sucht) == .nichtVerbunden)
        #expect(TrackerAnzeige.status(.sucht) == "Wird gesucht …")
    }

    @Test func bluetoothAusIstGrau() {
        let zustand = SensorZustand.bluetoothNichtBereit(.ausgeschaltet)
        #expect(TrackerAnzeige.symbol(zustand) == .nichtVerbunden)
        #expect(TrackerAnzeige.status(zustand) == "Bluetooth ist aus")
    }

    @Test func weitereZustaendeSindGrau() {
        let fund = SensorFund(id: UUID(), name: "WT901BLE", rssi: -50)
        #expect(TrackerAnzeige.status(.bluetoothNichtBereit(.verweigert)) == "Bluetooth nicht erlaubt")
        #expect(TrackerAnzeige.status(.bluetoothNichtBereit(.nichtUnterstuetzt)) == "Nicht verbunden")
        #expect(TrackerAnzeige.status(.verbindet) == "Verbindet …")
        #expect(TrackerAnzeige.status(.getrennt(wirdNeuVerbunden: true)) == "Getrennt · wird neu verbunden …")
        #expect(TrackerAnzeige.status(.getrennt(wirdNeuVerbunden: false)) == "Nicht verbunden")
        #expect(TrackerAnzeige.status(.mehrereGefunden([fund])) == "Mehrere Tracker gefunden")
        #expect(TrackerAnzeige.status(.aus) == "Nicht verbunden")
        for zustand in [SensorZustand.aus, .verbindet, .getrennt(wirdNeuVerbunden: true),
                        .mehrereGefunden([fund]), .bluetoothNichtBereit(.verweigert)] {
            #expect(TrackerAnzeige.symbol(zustand) == .nichtVerbunden)
        }
    }

    @Test func ohneGemerktenUnsichtbar() {
        #expect(!TrackerAnzeige.sichtbar(hatGemerktenSensor: false))
        #expect(TrackerAnzeige.sichtbar(hatGemerktenSensor: true))
    }

    @Test func nurDerBausteinnameWirdUmbenannt() {
        #expect(SensorName.anzeige("WT901BLE67") == "Gymtavo Tracker")
        #expect(SensorName.anzeige("wt901ble5") == "Gymtavo Tracker")
        #expect(SensorName.anzeige("Anderer Sensor") == "Anderer Sensor")
    }

    /// Review Focus 3: Vergessen im Profil muss sofort in der Kopfzeile ankommen.
    @MainActor
    @Test func vergessenSchaltetSofortUm() throws {
        let suite = "TrackerAnzeigeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(UUID().uuidString, forKey: "sensor.peripheralId")

        let quelle = BluetoothSensorQuelle(einstellungen: defaults)
        #expect(quelle.hatGemerktenSensor)

        // Gespeicherte Property: ein Defaults-Eintrag von aussen ändert nichts mehr.
        defaults.set(UUID().uuidString, forKey: "sensor.peripheralId")
        quelle.vergessen()
        defaults.set(UUID().uuidString, forKey: "sensor.peripheralId")
        #expect(!quelle.hatGemerktenSensor)
    }
}
#endif
