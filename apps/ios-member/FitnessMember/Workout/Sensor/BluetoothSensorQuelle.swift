#if DEBUG
@preconcurrency import CoreBluetooth
import Foundation
import Observation

/// Die einzige Datei mit Core Bluetooth (Spec 5.3).
///
/// queue: nil -- alle Delegate-Aufrufe kommen auf dem Main Thread. Bei 100 Hz
/// sind das rund 25 Notifications je Sekunde, das ist keine Last, und es erspart jede Uebergabe
/// zwischen Threads. Die Konformitaeten sind deshalb @preconcurrency: Swift
/// prueft zur Laufzeit, dass der Aufruf wirklich vom MainActor kommt.
@MainActor
@Observable
final class BluetoothSensorQuelle: NSObject, SensorQuelle {
    // 128-Bit-UUIDs des Herstellers: die Basis endet auf 9A34FB, nicht auf
    // der Bluetooth-Basis 9B34FB. Die Kurzform "FFE5" passt deshalb nicht
    // (Spec 4.1).
    private static let dienst = CBUUID(string: "0000FFE5-0000-1000-8000-00805F9A34FB")
    private static let daten = CBUUID(string: "0000FFE4-0000-1000-8000-00805F9A34FB")
    private static let befehle = CBUUID(string: "0000FFE9-0000-1000-8000-00805F9A34FB")
    private static let merkSchluessel = "sensor.peripheralId"

    private(set) var zustand: SensorZustand = .aus
    private(set) var rate: SensorRate = .hz50
    /// Ueber Wiederverbindungen hinweg aufsummiert: der Koordinator rechnet
    /// mit der Differenz seit Aufnahmestart, die darf nie rueckwaerts laufen.
    var verworfeneBytes: Int { verworfenFrueher + parser.verworfeneBytes }

    @ObservationIgnored private let einstellungen: UserDefaults
    @ObservationIgnored private let verteiler = SensorVerteiler()
    @ObservationIgnored private var parser = WitMotionParser()
    @ObservationIgnored private var verworfenFrueher = 0
    /// Erst beim ersten verbinden() angelegt: der CBCentralManager loest die
    /// Berechtigungsfrage aus, und die soll nicht beim App-Start kommen.
    @ObservationIgnored private var zentrale: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var schreibziel: CBCharacteristic?
    @ObservationIgnored private var funde: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var fundliste: [SensorFund] = []
    @ObservationIgnored private var sammelfrist: Task<Void, Never>?
    @ObservationIgnored private var akkuTakt: Task<Void, Never>?
    @ObservationIgnored private var akku: Int?
    @ObservationIgnored private var gewollt = false

    init(einstellungen: UserDefaults = .standard) {
        self.einstellungen = einstellungen
    }

    func ereignisse() -> AsyncStream<SensorEreignis> { verteiler.strom() }

    // MARK: - SensorQuelle

    func verbinden() {
        gewollt = true
        if let zentrale {
            zustandPruefen(zentrale)
        } else {
            zentrale = CBCentralManager(delegate: self, queue: nil)
        }
    }

    func waehlen(_ fund: SensorFund) {
        guard let gewaehlt = funde[fund.id] else { return }
        einstellungen.set(fund.id.uuidString, forKey: Self.merkSchluessel)
        verbindeMit(gewaehlt)
    }

    func trennen() {
        gewollt = false
        sammelfristBeenden()
        akkuTakt?.cancel()
        zentrale?.stopScan()
        if let peripheral { zentrale?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        schreibziel = nil
        setze(.aus)
    }

    func vergessen() {
        einstellungen.removeObject(forKey: Self.merkSchluessel)
        trennen()
    }

    func rateSetzen(_ neu: SensorRate) {
        rate = neu
        senden(.rate(neu))
    }

    func akkuLesen() { senden(.akkuLesen) }

    // MARK: - Ablauf

    private var gemerkt: UUID? {
        einstellungen.string(forKey: Self.merkSchluessel).flatMap(UUID.init(uuidString:))
    }

    private func zustandPruefen(_ zentrale: CBCentralManager) {
        guard gewollt else { return }
        switch zentrale.state {
        case .poweredOn: suchen(zentrale)
        case .poweredOff:
            verbindungAufgeben()
            setze(.bluetoothNichtBereit(.ausgeschaltet))
        case .unauthorized:
            verbindungAufgeben()
            setze(.bluetoothNichtBereit(.verweigert))
        case .unsupported: setze(.bluetoothNichtBereit(.nichtUnterstuetzt))
        default: break   // .unknown, .resetting: der naechste Aufruf kommt von selbst
        }
    }

    /// Ohne Bluetooth sind alle CBPeripheral-Objekte ungueltig, und ein
    /// didDisconnect kommt dafuer nicht. Bliebe `peripheral` stehen, haelt
    /// suchen() nach dem Wiedereinschalten den Sensor fuer verbunden und tut
    /// nichts -- am iPhone blieb die Zeile so auf "Bluetooth ist
    /// ausgeschaltet", bis die App neu startete. `gewollt` bleibt: das
    /// Mitglied hat nicht getrennt, nach dem Einschalten geht es weiter.
    private func verbindungAufgeben() {
        sammelfristBeenden()
        akkuTakt?.cancel()
        peripheral = nil
        schreibziel = nil
        funde = [:]
        fundliste = []
    }

    private func suchen(_ zentrale: CBCentralManager) {
        guard peripheral == nil else { return }
        funde = [:]; fundliste = []
        if let gemerkt, let bekannt = zentrale.retrievePeripherals(withIdentifiers: [gemerkt]).first {
            verbindeMit(bekannt)
            return
        }
        setze(.sucht)
        // Ohne Dienstfilter: der Sensor nennt den Dienst nicht in jedem
        // Advertisement (Spec 4.1). Gefiltert wird in istSensor.
        zentrale.scanForPeripherals(withServices: nil)
    }

    private static func istSensor(name: String?, dienste: [String]) -> Bool {
        dienste.contains(dienst.uuidString) || (name?.hasPrefix("WT") ?? false)
    }

    /// Eine abgebrochene Frist muss auch weg sein: bliebe sie stehen, startete
    /// der naechste Scan keine neue und haenge fuer immer in .sucht.
    private func sammelfristBeenden() {
        sammelfrist?.cancel()
        sammelfrist = nil
    }

    private func verbindeMit(_ ziel: CBPeripheral) {
        sammelfristBeenden()
        zentrale?.stopScan()
        peripheral = ziel
        ziel.delegate = self
        setze(.verbindet)
        // Kein Timeout: Core Bluetooth haelt den Versuch, bis der Sensor da
        // ist oder trennen() gerufen wird (Spec 5.3).
        zentrale?.connect(ziel)
    }

    private func senden(_ befehl: WitMotionBefehl) {
        guard let peripheral, let schreibziel else { return }
        let art: CBCharacteristicWriteType =
            schreibziel.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(befehl.bytes, for: schreibziel, type: art)
    }

    private func setze(_ neu: SensorZustand) {
        guard neu != zustand else { return }
        zustand = neu
        verteiler.senden(.zustand(neu))
    }

    private func nachDemAbonnieren(_ peripheral: CBPeripheral) {
        setze(.verbunden(name: peripheral.name ?? "WT901BLE", akkuProzent: akku))
        akkuTakt?.cancel()
        akkuTakt = Task { [weak self] in
            // Der Sensor verschluckt Befehle, die zu dicht aufeinander folgen.
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            // Bei jedem Verbinden neu: der Sensor behaelt die zuletzt gesetzte
            // Rate auch ohne "Konfiguration speichern" ueber einen Neustart
            // (Spec 4.5), auf einen Ausgangszustand ist kein Verlass.
            self.senden(.rate(self.rate))
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                self.senden(.akkuLesen)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

extension BluetoothSensorQuelle: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        zustandPruefen(central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let dienste = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard Self.istSensor(name: name, dienste: dienste), funde[peripheral.identifier] == nil else { return }

        // Ein gemerkter Sensor, den retrievePeripherals nicht kannte: nur
        // auf ihn warten, keinen fremden nehmen (Spec 8).
        if let gemerkt {
            if peripheral.identifier == gemerkt { verbindeMit(peripheral) }
            return
        }
        funde[peripheral.identifier] = peripheral
        fundliste.append(SensorFund(id: peripheral.identifier, name: name ?? "Sensor", rssi: RSSI.intValue))
        guard sammelfrist == nil else { return }
        // Zwei Sekunden sammeln, damit ein zweiter Sensor in Reichweite die
        // Auswahl oeffnet statt dem ersten still zu unterliegen.
        sammelfrist = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            self.sammelfrist = nil
            if self.fundliste.count == 1, let einziger = self.fundliste.first {
                self.waehlen(einziger)
            } else {
                self.setze(.mehrereGefunden(self.fundliste.sorted { $0.rssi > $1.rssi }))
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        verworfenFrueher += parser.verworfeneBytes
        parser = WitMotionParser()
        peripheral.discoverServices([Self.dienst])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        wiederVerbinden(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        wiederVerbinden(peripheral)
    }

    private func wiederVerbinden(_ peripheral: CBPeripheral) {
        akkuTakt?.cancel()
        schreibziel = nil
        guard gewollt, self.peripheral?.identifier == peripheral.identifier else { return }
        setze(.getrennt(wirdNeuVerbunden: true))
        zentrale?.connect(peripheral)
    }
}

extension BluetoothSensorQuelle: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let dienst = peripheral.services?.first(where: { $0.uuid == Self.dienst }) else { return }
        peripheral.discoverCharacteristics([Self.daten, Self.befehle], for: dienst)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for merkmal in service.characteristics ?? [] {
            if merkmal.uuid == Self.befehle { schreibziel = merkmal }
            if merkmal.uuid == Self.daten { peripheral.setNotifyValue(true, for: merkmal) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.daten, characteristic.isNotifying else { return }
        nachDemAbonnieren(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // ZUERST die Uhr: alles, was davor steht, landet als Jitter in den
        // Daten (Spec 5.3).
        let t = ProcessInfo.processInfo.systemUptime
        guard let wert = characteristic.value else { return }
        for paket in parser.lesen(wert) {
            switch paket {
            case .messwert(let beschleunigung, let drehrate, let winkel):
                verteiler.senden(.messwert(SensorMesswert(
                    t: t, beschleunigung: beschleunigung, drehrate: drehrate, winkel: winkel)))
            case .register(let adresse, let werte):
                guard adresse == Akkustand.register, let roh = werte.first else { continue }
                akku = Akkustand.prozent(hundertstelVolt: Int(roh))
                if case .verbunden(let name, _) = zustand { setze(.verbunden(name: name, akkuProzent: akku)) }
            }
        }
    }
}
#endif
