import Foundation

/// Alles, was einen Tag traegt -- `ExerciseProgress.Point.performedOn` und
/// `Messwert.measuredOn` sind dieselbe Sorte Angabe (ein Ortsdatum,
/// "yyyy-MM-dd") unter zwei verschiedenen Namen. Das Protokoll macht
/// `Fortschrittsfenster` fuer beide gleich nutzbar, statt eine zweite
/// Kopie von `punkte(_:jetzt:)` nur fuer Messwerte zu schreiben (Aufgabe 9).
protocol Datiert {
    var tag: String { get }
}

extension ExerciseProgress.Point: Datiert {
    var tag: String { performedOn }
}

extension Messwert: Datiert {
    var tag: String { measuredOn }
}

/// Der Zeitraum-Umschalter des Diagramms -- und der Achsenbereich.
///
/// Gefiltert wird LOKAL aus einem Abruf ohne `since`: drei Umschaltungen
/// waeren sonst drei Netzabrufe, und ohne Netz waeren zwei der drei
/// Knoepfe tot.
enum Fortschrittsfenster: CaseIterable, Identifiable {
    case dreiMonate
    case sechsMonate
    case alles

    var id: Self { self }

    var titel: String {
        switch self {
        case .dreiMonate: "3 Monate"
        case .sechsMonate: "6 Monate"
        case .alles: "Alles"
        }
    }

    private var tage: Int? {
        switch self {
        case .dreiMonate: 92
        case .sechsMonate: 183
        case .alles: nil
        }
    }

    /// Generisch ueber `Datiert` (Brief Step 1): dieselbe Filterung fuer
    /// `ExerciseProgress.Point` (Uebungsfortschritt) und `Messwert`
    /// (Gewichtsverlauf, Aufgabe 9) -- eine Regel statt zweier Kopien.
    func punkte<T: Datiert>(_ alle: [T], jetzt: Date) -> [T] {
        guard let tage else { return alle }
        let grenze = jetzt.addingTimeInterval(-Double(tage) * 24 * 60 * 60)

        return alle.filter { punkt in
            guard let tag = Zeitpunkt.parse("\(punkt.tag)T12:00:00Z") else { return false }
            return tag >= grenze
        }
    }

    /// Die Achse beginnt nicht bei null (designsystem.md SS13):
    /// Trainingsgewichte bewegen sich in einem schmalen Band, und eine
    /// Nullachse machte jeden Fortschritt unsichtbar. Stattdessen ein
    /// Rand von einem Zehntel der Spanne -- mindestens 2,5 kg, damit auch
    /// ein einzelner Punkt eine Achse bekommt.
    ///
    /// Der Rand folgt der Spanne, aber der untere Rand bleibt positiv:
    /// bei einem schmalen Gewicht (Isolationsuebungen, Kabelzug bei
    /// 2,5-5 kg sind Alltagsdaten, kein Sonderfall) zoege der feste
    /// 2,5-kg-Mindestrand die Achse sonst genau auf oder unter null --
    /// exakt das verbietet SS13 ohne Ausnahme.
    ///
    /// Nimmt rohe Gewichte statt Punkte (Brief Step 1): der Gewichtsverlauf
    /// (Aufgabe 9) muss das Zielgewicht MIT in den Bereich einrechnen,
    /// sonst faellt die gestrichelte Ziellinie aus der sichtbaren Achse --
    /// der Aufrufer haengt den Zielwert deshalb einfach an die Werteliste
    /// an, statt dass diese Funktion eine zweite, Ziel-kennende Fassung
    /// braucht.
    static func achsenbereich(_ werte: [Double]) -> ClosedRange<Double> {
        guard let kleinstes = werte.min(), let groesstes = werte.max() else {
            return 0 ... 10
        }

        let rand = max((groesstes - kleinstes) / 10, 2.5)
        let unten = max(kleinstes - rand, kleinstes / 2)
        return unten ... (groesstes + rand)
    }
}
