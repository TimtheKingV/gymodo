#if DEBUG
import Foundation
import Sensorik

/// Zeilenweises Protokoll neben den Aufnahmen. Am 8. Oktober fehlten zwei
/// Saetze, und hinterher liess sich nicht mehr sagen, ob der Sensor getrennt
/// war oder die App neu gestartet hatte. Wirft nie: ein Debug-Protokoll darf
/// keinen Satz aufhalten.
final class SensorProtokoll {
    let datei: URL
    private let alt: URL
    private let jetzt: () -> Date
    private let grenzeBytes: Int
    private let format: ISO8601DateFormatter

    /// Eine Million Byte sind gut zehntausend Zeilen -- Wochen an Training.
    /// Danach wird die Datei einmal beiseitegelegt statt endlos zu wachsen.
    init(wurzel: URL, jetzt: @escaping () -> Date, zeitzone: TimeZone = .current,
         grenzeBytes: Int = 1_000_000) {
        datei = wurzel.appendingPathComponent("protokoll.log")
        alt = wurzel.appendingPathComponent("protokoll-alt.log")
        self.jetzt = jetzt
        self.grenzeBytes = grenzeBytes
        format = ISO8601DateFormatter()
        format.timeZone = zeitzone
        format.formatOptions = [.withInternetDateTime]
    }

    func schreiben(_ text: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let groesse = (try? fm.attributesOfItem(atPath: datei.path))?[.size] as? Int, groesse > grenzeBytes {
            try? fm.removeItem(at: alt)
            try? fm.moveItem(at: datei, to: alt)
        }
        let zeile = Data("\(format.string(from: jetzt())) \(text)\n".utf8)
        guard let griff = try? FileHandle(forWritingTo: datei) else {
            try? zeile.write(to: datei)
            return
        }
        defer { try? griff.close() }
        _ = try? griff.seekToEnd()
        try? griff.write(contentsOf: zeile)
    }

    static func text(_ zustand: SensorZustand) -> String {
        switch zustand {
        case .aus: "aus"
        case .sucht: "sucht"
        case .verbindet: "verbindet"
        case .mehrereGefunden(let funde): "mehrere gefunden (\(funde.count))"
        case .verbunden(let name, let akku): "verbunden \(name)" + (akku.map { ", \($0) %" } ?? "")
        case .getrennt(let neu): neu ? "getrennt, wird neu verbunden" : "getrennt"
        case .bluetoothNichtBereit(.ausgeschaltet): "bluetooth nicht bereit: ausgeschaltet"
        case .bluetoothNichtBereit(.verweigert): "bluetooth nicht bereit: verweigert"
        case .bluetoothNichtBereit(.nichtUnterstuetzt): "bluetooth nicht bereit: nicht unterstuetzt"
        }
    }

    /// Die Spannung bleibt hier intern: Prozent sieht das Mitglied, die
    /// Rohwerte braucht nur, wer einen falschen Prozentwert erklaeren muss.
    static func akkuText(hundertstelVolt wert: Int) -> String {
        String(format: "akku %.2f V (%d %%)", locale: Locale(identifier: "en_US_POSIX"),
               Double(wert) / 100, Akkustand.prozent(hundertstelVolt: wert))
    }
}
#endif
