import Foundation

public enum WitMotionPaket: Sendable, Equatable {
    case messwert(beschleunigung: Vektor3, drehrate: Vektor3, winkel: Vektor3)
    /// Antwort auf einen Lesebefehl: acht Register ab `adresse`.
    case register(adresse: UInt16, werte: [Int16])

    public static let laenge = 20
}

/// Haelt einen Puffer ueber Aufrufe hinweg: Core Bluetooth garantiert nicht,
/// dass eine Notification genau ein Paket traegt (Spec 5.1).
public struct WitMotionParser: Sendable {
    private var puffer: [UInt8] = []
    /// Bytes, die zu keinem Paket gehoerten. Gezaehlt statt still verworfen,
    /// damit eine kaputte Verbindung in der Statistik sichtbar wird.
    public private(set) var verworfeneBytes = 0

    public init() {}

    public mutating func lesen(_ daten: Data) -> [WitMotionPaket] {
        puffer.append(contentsOf: daten)
        var pakete: [WitMotionPaket] = []
        var i = 0
        while i < puffer.count {
            guard puffer[i] == 0x55 else {
                i += 1; verworfeneBytes += 1
                continue
            }
            // Header oder Paket noch unvollstaendig: auf die naechste
            // Notification warten statt zu raten.
            guard i + 1 < puffer.count else { break }
            let typ = puffer[i + 1]
            guard typ == 0x61 || typ == 0x71 else {
                i += 1; verworfeneBytes += 1
                continue
            }
            guard i + WitMotionPaket.laenge <= puffer.count else { break }

            let werte = (0..<9).map { n -> Int16 in
                let lo = UInt16(puffer[i + 2 + n * 2])
                let hi = UInt16(puffer[i + 3 + n * 2])
                return Int16(bitPattern: lo | hi << 8)
            }
            if typ == 0x61 {
                func vektor(_ ab: Int, _ bereich: Double) -> Vektor3 {
                    Vektor3(x: Double(werte[ab]) / 32768 * bereich,
                            y: Double(werte[ab + 1]) / 32768 * bereich,
                            z: Double(werte[ab + 2]) / 32768 * bereich)
                }
                pakete.append(.messwert(beschleunigung: vektor(0, 16),
                                        drehrate: vektor(3, 2000),
                                        winkel: vektor(6, 180)))
            } else {
                pakete.append(.register(adresse: UInt16(bitPattern: werte[0]),
                                        werte: Array(werte.dropFirst())))
            }
            i += WitMotionPaket.laenge
        }
        puffer.removeFirst(i)
        return pakete
    }
}
