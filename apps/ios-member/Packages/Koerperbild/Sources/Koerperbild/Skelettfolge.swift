import Foundation

/// Eine aufgezeichnete Folge von Skeletten (ein Bild pro Eintrag, `nil` =
/// niemand erkannt). JSON: Gelenkname -> [x, y, sicherheit], Zahlen auf vier
/// Nachkommastellen gerundet, Schluessel sortiert.
public struct Skelettfolge: Sendable {
    public let bildrate: Double
    public let seitenverhaeltnis: Double
    public let bilder: [Skelett?]

    public init(bildrate: Double, seitenverhaeltnis: Double, bilder: [Skelett?]) {
        self.bildrate = bildrate
        self.seitenverhaeltnis = seitenverhaeltnis
        self.bilder = bilder
    }

    private struct Datei: Codable {
        var bildrate: Double
        var seitenverhaeltnis: Double
        var bilder: [[String: [Double]]?]
    }

    /// Liest die Folge; unbekannte Gelenknamen werden uebergangen.
    public init(daten: Data) throws {
        let datei = try JSONDecoder().decode(Datei.self, from: daten)
        var bilder: [Skelett?] = []
        for bild in datei.bilder {
            guard let bild else { bilder.append(nil); continue }
            var punkte: [Gelenk: Punkt] = [:]
            for (name, werte) in bild {
                guard let gelenk = Gelenk(rawValue: name) else { continue }
                guard werte.count == 3 else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Gelenk \(name): erwartet [x, y, sicherheit]"))
                }
                punkte[gelenk] = Punkt(x: werte[0], y: werte[1], sicherheit: werte[2])
            }
            bilder.append(Skelett(punkte: punkte, seitenverhaeltnis: datei.seitenverhaeltnis))
        }
        self.init(bildrate: datei.bildrate, seitenverhaeltnis: datei.seitenverhaeltnis, bilder: bilder)
    }

    public func daten() throws -> Data {
        func gerundet(_ z: Double) -> Double { (z * 10_000).rounded() / 10_000 }
        let bilder: [[String: [Double]]?] = self.bilder.map { bild in
            guard let bild else { return nil }
            return Dictionary(uniqueKeysWithValues: bild.punkte.map {
                ($0.key.rawValue, [gerundet($0.value.x), gerundet($0.value.y), gerundet($0.value.sicherheit)])
            })
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Datei(bildrate: bildrate, seitenverhaeltnis: seitenverhaeltnis, bilder: bilder))
    }
}
