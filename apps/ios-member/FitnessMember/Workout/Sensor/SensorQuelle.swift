#if DEBUG
import Foundation

struct SensorFund: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let rssi: Int
}

enum SensorZustand: Equatable, Sendable {
    enum Grund: Equatable, Sendable { case ausgeschaltet, verweigert, nichtUnterstuetzt }

    case aus
    case bluetoothNichtBereit(Grund)
    case sucht
    case mehrereGefunden([SensorFund])
    case verbindet
    case verbunden(name: String, akkuProzent: Int?)
    case getrennt(wirdNeuVerbunden: Bool)

    var istVerbunden: Bool {
        if case .verbunden = self { return true }
        return false
    }

    var name: String? {
        if case .verbunden(let name, _) = self { return name }
        return nil
    }

    var akkuProzent: Int? {
        if case .verbunden(_, let akku) = self { return akku }
        return nil
    }
}

/// Messwerte und Zustandswechsel in EINEM Strom: eine Luecke muss zwischen
/// den Messwerten ankommen, zwischen denen sie lag. Zwei Stroeme haetten
/// dafuer keine gemeinsame Reihenfolge.
enum SensorEreignis: Equatable, Sendable {
    case messwert(SensorMesswert)
    case zustand(SensorZustand)
    /// Rohwert der Akku-Antwort. Nur fuers Protokoll: am 8. Oktober stand
    /// direkt nach dem Verbinden 0 %, kurz danach 100 % -- ohne Spannung
    /// laesst sich nicht sagen, ob die Antwort oder die Umrechnung danebenlag.
    case akku(hundertstelVolt: Int)
}

/// Alles, was Verbraucher vom Sensor sehen (Spec 5.2). Hinter diesem
/// Protokoll stehen Bluetooth, die Abspiel-Quelle und die Attrappe der Tests.
@MainActor
protocol SensorQuelle: AnyObject, Sendable {
    var zustand: SensorZustand { get }
    var rate: SensorRate { get }
    var verworfeneBytes: Int { get }
    /// Wurde schon einmal ein Sensor gewaehlt? Dann ist die
    /// Bluetooth-Berechtigung beantwortet, und ein verbinden() beim App-Start
    /// loest keine Abfrage mehr aus.
    var hatGemerktenSensor: Bool { get }
    /// Ein eigener Strom je Aufruf.
    func ereignisse() -> AsyncStream<SensorEreignis>
    func verbinden()
    func waehlen(_ fund: SensorFund)
    func trennen()
    /// Trennt und loescht den gemerkten Sensor.
    func vergessen()
    func rateSetzen(_ rate: SensorRate)
    func akkuLesen()
}

/// Ein AsyncStream hat genau einen Leser. Zeile, Koordinator und spaeter der
/// Zaehler wollen gleichzeitig zuhoeren.
@MainActor
final class SensorVerteiler {
    private var abonnenten: [UUID: AsyncStream<SensorEreignis>.Continuation] = [:]

    func strom() -> AsyncStream<SensorEreignis> {
        let id = UUID()
        // Begrenzt: ein haengender Leser darf den Speicher nicht fuellen.
        let (strom, fortsetzung) = AsyncStream.makeStream(
            of: SensorEreignis.self, bufferingPolicy: .bufferingNewest(2048))
        abonnenten[id] = fortsetzung
        fortsetzung.onTermination = { [weak self] _ in
            Task { @MainActor in self?.abonnenten[id] = nil }
        }
        return strom
    }

    func senden(_ ereignis: SensorEreignis) {
        for abonnent in abonnenten.values { abonnent.yield(ereignis) }
    }
}
#endif
