import Foundation

/// EIN Ort fuer Einheiten, Umfangsarten und Kategorie -- der Swift-Spiegel
/// von packages/domain/src/belastung.ts.
///
/// Cardio-Spec (2026-09-21) Abschnitt 5.3: die Regel und der Satzpfad
/// rechnen nur mit Zahlen; was die Zahlen bedeuten, sagen `loadUnit` am
/// Geraetemodell und `volumeKind` an der Uebung. Alles, was eine Einheit
/// KENNEN muss, steht hier und in den Formatierern von Zahlformat
/// (belastung..., umfang..., korridor). Eine neue Einheit kostet dort je
/// Funktion eine Zeile und hier einen Fall -- die erschoepfenden `switch`
/// machen jede vergessene Stelle zum Uebersetzungsfehler statt zum
/// falschen "kg" auf einem Laufband.
///
/// Die Rohwerte sind die Servernamen (Check-Constraint aus Migration
/// 0046). Dekodiert wird strikt: eine Einheit, die die App nicht kennt, ist
/// ein Dekodierfehler und kein stilles Kilogramm.
///
/// Belastung und Nebenbelastung teilen sich dieselbe Liste: die Neigung
/// (pct) ist am Laufband Nebenbelastung, koennte an einem anderen Geraet
/// aber die Hauptbelastung sein.
enum LoadUnit: String, Codable, Equatable, Sendable, CaseIterable {
    case kg, watt, level, kmh, pct, rpm
}

enum VolumeKind: String, Codable, Equatable, Sendable {
    case reps, seconds, meters
}

/// Nur Anzeige (Spec Abschnitt 3.5): die Geraetesuche gruppiert danach.
/// Satzpfad, Abschluss und Verlauf lesen sie nie -- eine Kategorie, die
/// Logik traegt, waere der `modality`-Schalter, den die Spec verwirft.
enum Kategorie: String, Codable, Equatable, Sendable {
    case kraft, cardio
}

extension LoadUnit {
    /// Das Wort neben dem Rad.
    var kurz: String {
        switch self {
        case .kg: "kg"
        case .watt: "W"
        case .level: "Level"
        case .kmh: "km/h"
        case .pct: "%"
        case .rpm: "U/min"
        }
    }

    /// Wie NACHKOMMASTELLEN in belastung.ts. Kilogramm, km/h und Prozent
    /// rasten auf halbe Schritte und tragen deshalb immer eine Stelle --
    /// ein Wechsel von 8 auf 8,5 wirkte sonst wie ein Formatfehler. Watt,
    /// Level und Umdrehungen rasten ganz.
    var nachkommastellen: Int {
        switch self {
        case .kg, .kmh, .pct: 1
        case .watt, .level, .rpm: 0
        }
    }
}

extension LoadUnit {
    /// Wie der Regler heisst, wenn diese Einheit die NEBENbelastung ist:
    /// neben dem Wert "6,0 %" braucht die Zeile ein Wort, das sagt, was
    /// sich da einstellen laesst. Die Belastung selbst braucht keins --
    /// sie steht als Rad mitten auf dem Screen.
    var reglername: String {
        switch self {
        case .kg: "Gewicht"
        case .watt: "Leistung"
        case .level: "Stufe"
        case .kmh: "Tempo"
        case .pct: "Neigung"
        case .rpm: "Trittfrequenz"
        }
    }
}

extension VolumeKind {
    /// Das Wort neben dem Umfangsrad.
    var kurz: String {
        switch self {
        case .reps: "Wdh."
        case .seconds: "min"
        case .meters: "m"
        }
    }

    /// Wie VoiceOver das Umfangsrad ansagt.
    var radname: String {
        switch self {
        case .reps: "Wiederholungen"
        case .seconds: "Dauer"
        case .meters: "Strecke"
        }
    }
}
