import Foundation

/// Die Stationen des Drawers vor einer Uebung (Testnotiz 11.10., #6, #11).
///
/// Ersetzt den Erstkontakt als Vollbild: die Einweisung liegt jetzt als
/// Drawer ueber der Seite, auf der die Uebung gewaehlt wurde, und jede Wahl
/// endet bei den Startwerten -- auch die einer schon bekannten Uebung
/// (#10). "Training starten" ist kein eigener Schritt mehr: "Übung starten"
/// startet ein noch nicht laufendes Training mit.
enum UebungsstartSchritt: Equatable {
    case einweisung
    case einstellung
    case startwerte
}

/// Was die Satzseite aus dem Drawer uebernimmt.
struct Startwerte: Hashable, Sendable {
    let belastung: Double
    let umfang: Int
    let nebenbelastung: Double?
}

/// Eine gewaehlte Uebung, fuer die der Drawer offen steht.
struct UebungsstartAuftrag: Identifiable, Equatable {
    let station: String
    let exerciseId: String
    let token: String?

    var id: String { "\(station)|\(exerciseId)" }
}

enum Uebungsstart {
    /// Die Einweisung nur beim Erstkontakt je Geraet und Uebung, die
    /// Einstellung nur, wenn das Modell Einstellparameter hat und ein
    /// echtes Geraet ist (GeraetModel.erstkontaktFragtEinstellung).
    static func schritte(erstkontakt: Bool, fragtEinstellung: Bool) -> [UebungsstartSchritt] {
        guard erstkontakt else { return [.startwerte] }
        return fragtEinstellung ? [.einweisung, .einstellung, .startwerte] : [.einweisung, .startwerte]
    }

    /// "Kenne ich schon" fuehrt an Einweisung und Einstellung vorbei
    /// (Testnotiz 06.10., #16) -- seit dem Drawer zu den Startwerten statt
    /// zu "Training starten".
    static func positionNachUeberspringen(in schritte: [UebungsstartSchritt]) -> Int {
        schritte.firstIndex(of: .startwerte) ?? max(schritte.count - 1, 0)
    }
}

/// Der Countdown vor dem ersten Satz (Testnotiz 11.10., #10): fuenf
/// Sekunden, dann eine Sekunde "Los!" in der Mitte des Rings -- erst
/// danach stehen die Raeder.
enum Startcountdown {
    static let dauer: TimeInterval = 6

    /// Die Sekunden mit Ziffern. Ueber sie fuellt sich der Ring, damit er
    /// bei "Los!" voll ist (Testnotiz 12.10. abends, #2) -- vorher lief er
    /// ueber alle sechs und stand beim Wechsel zu den Raedern bei 5/6.
    static let zaehldauer: TimeInterval = 5

    /// Fliessend statt in ganzen Sekunden: `Resttimer.fortschritt` rundet
    /// auf volle Sekunden, und die Animation dazwischen lief dem Wert eine
    /// Sekunde hinterher.
    static func fortschritt(start: Date, jetzt: Date) -> Double {
        min(1, max(0, jetzt.timeIntervalSince(start) / zaehldauer))
    }

    static func anzeige(restsekunden: Int) -> String {
        restsekunden > 1 ? "\(restsekunden - 1)" : "Los!"
    }
}
