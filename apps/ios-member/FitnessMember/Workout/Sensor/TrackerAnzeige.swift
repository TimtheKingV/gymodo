#if DEBUG
import Sensorik

/// Was das Mitglied vom Tracker sieht (Paket 3): ein Symbol, grün oder grau,
/// und ein Statustext. Kein Rot -- ein Tracker außer Reichweite ist kein
/// Fehler, das Training läuft ohne ihn normal weiter.
enum TrackerAnzeige {
    enum Symbol: Equatable { case verbunden, nichtVerbunden }

    static func symbol(_ zustand: SensorZustand) -> Symbol {
        zustand.istVerbunden ? .verbunden : .nichtVerbunden
    }

    static func status(_ zustand: SensorZustand) -> String {
        switch zustand {
        case let .verbunden(_, akkuProzent):
            guard let akkuProzent else { return "Verbunden" }
            return "Verbunden · Akku \(akkuProzent) %"
        case .sucht: return "Wird gesucht …"
        case .verbindet: return "Verbindet …"
        case let .getrennt(wirdNeuVerbunden):
            return wirdNeuVerbunden ? "Getrennt · wird neu verbunden …" : "Nicht verbunden"
        case let .bluetoothNichtBereit(grund):
            switch grund {
            case .ausgeschaltet: return "Bluetooth ist aus"
            case .verweigert: return "Bluetooth nicht erlaubt"
            case .nichtUnterstuetzt: return "Nicht verbunden"
            }
        case .mehrereGefunden: return "Mehrere Tracker gefunden"
        case .aus: return "Nicht verbunden"
        }
    }

    /// Im Training sichtbar? Nur mit gemerktem Tracker.
    static func sichtbar(hatGemerktenSensor: Bool) -> Bool { hatGemerktenSensor }

    /// Was der Knopf in der Einrichtung im Profil tut (Paket 3, F4). Die
    /// Auswahl bei mehreren Funden gibt es nur hier, nie im Training
    /// (Review Focus 4). Laeuft schon eine Suche oder Verbindung, oder ist
    /// der gemerkte Tracker nur gerade weg, gibt es nichts zu tippen.
    enum Aktion: Equatable {
        case verbinden
        case auswaehlen([SensorFund])
        case einstellungenOeffnen
        case keine
    }

    static func einrichtungsAktion(_ zustand: SensorZustand, hatGemerktenSensor: Bool) -> Aktion {
        switch zustand {
        case let .mehrereGefunden(funde): return .auswaehlen(funde)
        case .bluetoothNichtBereit(.verweigert): return .einstellungenOeffnen
        case .bluetoothNichtBereit, .sucht, .verbindet, .verbunden: return .keine
        case .aus, .getrennt(wirdNeuVerbunden: false): return .verbinden
        case .getrennt(wirdNeuVerbunden: true): return hatGemerktenSensor ? .keine : .verbinden
        }
    }
}
#endif
