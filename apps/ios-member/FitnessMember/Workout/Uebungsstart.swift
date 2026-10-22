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
    /// Die Uebung gehoert zu einem Mini-Zirkel (Runde 1): der Drawer beginnt
    /// gleich bei den Startwerten, und die Satzseite startet ohne Countdown.
    var zirkel: Bool = false

    var id: String { "\(station)|\(exerciseId)" }
}

enum Uebungsstart {
    /// Die Einweisung nur beim Erstkontakt je Geraet und Uebung, die
    /// Einstellung nur, wenn das Modell Einstellparameter hat und ein
    /// echtes Geraet ist (GeraetModel.erstkontaktFragtEinstellung).
    ///
    /// Bei Zeit oder Metern (Cardio) keine Startwerte (Testnotiz 14.10.,
    /// 18:45 #6): dort startet man einfach, die Werte kommen am Ende. Eine
    /// bekannte Cardio-Uebung hat damit gar keinen Schritt -- der Aufrufer
    /// startet sie ohne Drawer (`direktStart`).
    ///
    /// - uebersicht: auch eine bekannte Uebung beginnt mit der Einweisung, die
    ///   Muskeln und Beschreibung zeigt (Testnotiz 17.10., #4) -- wer aus der
    ///   Liste oder per Scan kommt, will sie sich manchmal noch einmal ansehen,
    ///   und ein Tipp mehr tut nicht weh. Dann gibt es auch bei Cardio einen
    ///   Schritt, `direktStart` ist nie wahr.
    static func schritte(erstkontakt: Bool, fragtEinstellung: Bool,
                         volumeKind: VolumeKind = .reps,
                         uebersicht: Bool = false) -> [UebungsstartSchritt] {
        var schritte: [UebungsstartSchritt] = []
        if erstkontakt {
            schritte.append(.einweisung)
            if fragtEinstellung { schritte.append(.einstellung) }
        } else if uebersicht {
            schritte.append(.einweisung)
        }
        if volumeKind == .reps { schritte.append(.startwerte) }
        return schritte
    }

    /// Kein Schritt uebrig: die Uebung startet ohne Drawer.
    static func direktStart(erstkontakt: Bool, fragtEinstellung: Bool, volumeKind: VolumeKind,
                            uebersicht: Bool = false) -> Bool {
        schritte(erstkontakt: erstkontakt, fragtEinstellung: fragtEinstellung, volumeKind: volumeKind,
                 uebersicht: uebersicht).isEmpty
    }

    /// "Kenne ich schon" fuehrt an Einweisung und Einstellung vorbei
    /// (Testnotiz 06.10., #16) -- seit dem Drawer zu den Startwerten statt
    /// zu "Training starten". nil: es gibt keine (Cardio), die Uebung
    /// startet sofort.
    static func positionNachUeberspringen(in schritte: [UebungsstartSchritt]) -> Int? {
        schritte.firstIndex(of: .startwerte)
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
