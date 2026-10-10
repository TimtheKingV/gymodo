import Foundation

public enum SensorRate: Int, Sendable, CaseIterable, Codable {
    case hz20 = 20
    case hz50 = 50
    case hz100 = 100

    /// Wert fuer das Raten-Register 0x03.
    fileprivate var registerwert: UInt8 {
        switch self {
        case .hz20: 0x07
        case .hz50: 0x08
        case .hz100: 0x09
        }
    }
}

/// Bewusst nur, was A braucht. Kalibrieren und "Konfiguration speichern"
/// fehlen mit Absicht (Spec 2) -- wer sie braucht, fuehrt die Diskussion
/// in der Spec, nicht hier.
public enum WitMotionBefehl: Sendable, Equatable {
    case rate(SensorRate)
    case akkuLesen

    public static var alle: [WitMotionBefehl] { SensorRate.allCases.map(WitMotionBefehl.rate) + [.akkuLesen] }

    public var bytes: Data {
        switch self {
        case .rate(let rate): Data([0xFF, 0xAA, 0x03, rate.registerwert, 0x00])
        case .akkuLesen: Data([0xFF, 0xAA, 0x27, 0x64, 0x00])
        }
    }
}

public enum Akkustand {
    public static let register: UInt16 = 0x64

    /// Der Sensor meldet die Zellspannung in Hundertstel Volt. Die Stufen
    /// stammen aus der Herstellertabelle; eine LiPo-Kurve ist nicht linear,
    /// eine Geradengleichung wuerde bei 3,7 V "50 %" behaupten.
    public static func prozent(hundertstelVolt wert: Int) -> Int {
        let stufen: [(ab: Int, prozent: Int)] = [
            (397, 100), (393, 90), (387, 75), (382, 60), (379, 50), (377, 40),
            (373, 30), (370, 20), (368, 15), (350, 10), (340, 5),
        ]
        return stufen.first { wert >= $0.ab }?.prozent ?? 0
    }
}
