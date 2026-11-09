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

    // MARK: - Einrichtung im Profil (Review Focus 4)

    @Test func aktionBeiMehrerenFunden() {
        let a = SensorFund(id: UUID(), name: "WT901BLE67", rssi: -50)
        let b = SensorFund(id: UUID(), name: "WT901BLE12", rssi: -70)
        #expect(TrackerAnzeige.einrichtungsAktion(.mehrereGefunden([a, b]), hatGemerktenSensor: false)
            == .auswaehlen([a, b]))
    }

    @Test func aktionBeiVerweigert() {
        #expect(TrackerAnzeige.einrichtungsAktion(.bluetoothNichtBereit(.verweigert), hatGemerktenSensor: false)
            == .einstellungenOeffnen)
        #expect(TrackerAnzeige.einrichtungsAktion(.bluetoothNichtBereit(.verweigert), hatGemerktenSensor: true)
            == .einstellungenOeffnen)
    }

    @Test func aktionOhneGemerkten() {
        #expect(TrackerAnzeige.einrichtungsAktion(.aus, hatGemerktenSensor: false) == .verbinden)
        #expect(TrackerAnzeige.einrichtungsAktion(.getrennt(wirdNeuVerbunden: false), hatGemerktenSensor: false)
            == .verbinden)
        // Laeuft schon etwas, bleibt nur das Abbrechen.
        #expect(TrackerAnzeige.einrichtungsAktion(.sucht, hatGemerktenSensor: false) == .abbrechen)
        #expect(TrackerAnzeige.einrichtungsAktion(.verbindet, hatGemerktenSensor: false) == .abbrechen)
    }

    @Test func aktionMitGemerktem() {
        let verbunden = SensorZustand.verbunden(name: "WT901BLE", akkuProzent: 80)
        #expect(TrackerAnzeige.einrichtungsAktion(verbunden, hatGemerktenSensor: true) == .keine)
        #expect(TrackerAnzeige.einrichtungsAktion(.sucht, hatGemerktenSensor: true) == .abbrechen)
        #expect(TrackerAnzeige.einrichtungsAktion(.verbindet, hatGemerktenSensor: true) == .abbrechen)
        #expect(TrackerAnzeige.einrichtungsAktion(.getrennt(wirdNeuVerbunden: true), hatGemerktenSensor: true)
            == .keine)
        #expect(TrackerAnzeige.einrichtungsAktion(.aus, hatGemerktenSensor: true) == .verbinden)
    }

    // MARK: - Letzter Fehler (Für Entwickler)

    @Test func fehlerZeileOhneFehlerIstNil() {
        #expect(TrackerAnzeige.fehlerZeile(nil) == nil)
    }

    @Test func fehlerZeileGibtDenTextUnveraendert() {
        #expect(TrackerAnzeige.fehlerZeile("Aufnahme fehlgeschlagen: x") == "Aufnahme fehlgeschlagen: x")
    }

    // MARK: - Sichern nach Ruhe (F5, Review Focus 2)

    private static func wert(_ t: Double) -> SensorMesswert {
        SensorMesswert(t: t, beschleunigung: .init(x: 0, y: 0, z: 1),
                       drehrate: .init(x: 0, y: 0, z: 0), winkel: .init(x: 0, y: 0, z: 0))
    }

    private static func wiederholung(_ n: Int, _ von: Double, _ bis: Double) -> Wiederholung {
        Wiederholung(nummer: n, beginn: von, umkehr: (von + bis) / 2, ende: bis,
                     ausschlag: 1, sicherheit: 1, pauseDavor: nil)
    }

    /// Zwei Wiederholungen bis 4 s, dann Ruhe bis 7 s: noch 5 s bis zum Sichern.
    private static func laufenderSatz() -> SatzAutomatik {
        var a = SatzAutomatik()
        for tick in 0...40 { a.empfangen(wert(Double(tick) / 10)) }
        _ = a.wiederholungen([wiederholung(1, 0, 2), wiederholung(2, 2, 4)])
        for tick in 41...70 { a.empfangen(wert(Double(tick) / 10)) }
        return a
    }

    @Test func ruheTextNurBeiLaufendemSatz() {
        let laeuft = Self.laufenderSatz()
        #expect(laeuft.zustand == .laeuft)
        #expect(TrackerAnzeige.ruheText(laeuft, aktiv: true, verbunden: true) == "Sichern nach Ruhe · 5 s")
        // Wartet noch auf den Satzstart: keine Zeile.
        #expect(TrackerAnzeige.ruheText(SatzAutomatik(), aktiv: true, verbunden: true) == nil)
    }

    /// Abriss mitten im Satz: kein eingefrorener Countdown.
    @Test func ruheTextNichtWennNichtVerbunden() {
        let verbunden = TrackerAnzeige.ruheVerbunden(.getrennt(wirdNeuVerbunden: true), hatGemerktenSensor: true)
        #expect(!verbunden)
        #expect(TrackerAnzeige.ruheText(Self.laufenderSatz(), aktiv: true, verbunden: verbunden) == nil)
    }

    /// "Tracker vergessen" mitten im Satz: auch die Zeile verschwindet.
    @Test func ruheTextNichtOhneGemerktenTracker() {
        let zustand = SensorZustand.verbunden(name: "WT901BLE", akkuProzent: 80)
        #expect(TrackerAnzeige.ruheVerbunden(zustand, hatGemerktenSensor: true))
        let verbunden = TrackerAnzeige.ruheVerbunden(zustand, hatGemerktenSensor: false)
        #expect(!verbunden)
        #expect(TrackerAnzeige.ruheText(Self.laufenderSatz(), aktiv: true, verbunden: verbunden) == nil)
    }

    @Test func ruheTextNichtBeiAutomatikAus() {
        #expect(TrackerAnzeige.ruheText(Self.laufenderSatz(), aktiv: false, verbunden: true) == nil)
    }
}
#endif
