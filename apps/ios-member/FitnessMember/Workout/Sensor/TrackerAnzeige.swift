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

    /// Die Zeile "Letzter Fehler" unter "Für Entwickler": der Text der
    /// Aufnahme, nil ohne Fehler. Bewusst neutral, kein Rot.
    static func fehlerZeile(_ fehler: String?) -> String? { fehler }

    /// Im Training sichtbar? Nur mit gemerktem Tracker.
    static func sichtbar(hatGemerktenSensor: Bool) -> Bool { hatGemerktenSensor }

    /// Die eine Automatik-Zeile am Geraet (F5): nur bei Automatik an,
    /// verbundenem Tracker und laufendem Satz. `aktiv` wird eigens geprueft --
    /// das Ausschalten setzt die Automatik zwar neu auf, die Zeile soll aber
    /// auch dann nicht stehen, wenn sie noch einen alten Stand traegt (Review
    /// Focus 2). Ebenso `verbunden`: ein Abriss setzt die Automatik nicht
    /// zurueck, `speichernIn` stuende sonst eingefroren beim letzten Messwert.
    static func ruheText(_ automatik: SatzAutomatik, aktiv: Bool, verbunden: Bool) -> String? {
        guard aktiv, verbunden, automatik.zustand == .laeuft, let rest = automatik.speichernIn else { return nil }
        return "Sichern nach Ruhe · \(Int(rest.rounded(.up))) s"
    }

    /// Fuer `ruheText`: nur ein gemerkter und gerade verbundener Tracker
    /// zaehlt. Nach "Tracker vergessen" steht im Training nichts mehr.
    static func ruheVerbunden(_ zustand: SensorZustand, hatGemerktenSensor: Bool) -> Bool {
        hatGemerktenSensor && zustand.istVerbunden
    }

    /// Was der Knopf in der Einrichtung im Profil tut (Paket 3, F4). Die
    /// Auswahl bei mehreren Funden gibt es nur hier, nie im Training
    /// (Review Focus 4). Laeuft eine Suche oder Verbindung, bleibt nur das
    /// Abbrechen; ist der gemerkte Tracker nur gerade weg, gibt es nichts
    /// zu tippen.
    enum Aktion: Equatable {
        case verbinden
        case auswaehlen([SensorFund])
        case einstellungenOeffnen
        case abbrechen
        case keine
    }

    static func einrichtungsAktion(_ zustand: SensorZustand, hatGemerktenSensor: Bool) -> Aktion {
        switch zustand {
        case let .mehrereGefunden(funde): return .auswaehlen(funde)
        case .bluetoothNichtBereit(.verweigert): return .einstellungenOeffnen
        case .sucht, .verbindet: return .abbrechen
        case .bluetoothNichtBereit, .verbunden: return .keine
        case .aus, .getrennt(wirdNeuVerbunden: false): return .verbinden
        case .getrennt(wirdNeuVerbunden: true): return hatGemerktenSensor ? .keine : .verbinden
        }
    }
}
#endif
