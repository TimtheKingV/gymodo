import SwiftUI

/// Der modale Erstkontakt. fullScreenCover verdeckt die Tab-Leiste -- genau
/// das verlangt designsystem.md SS8 ("ohne Tab-Leiste"). Er laeuft genau
/// einmal je Geraet UND Uebung.
///
/// Seit der Testnotiz 06.10. endet er mit der Einstellung (#18): der erste
/// Satz laeuft auf der Satzseite, mit Sensor und denselben Knoepfen wie
/// jeder weitere (#8). Laeuft noch kein Training, folgt "Training starten"
/// -- die Uhr laeuft erst ab dort, nicht schon waehrend der Einweisung
/// (#5). Welche Schritte ein Geraet zeigt, entscheidet
/// GeraetEinstiegRechner.erstkontaktSchritte.
struct ErstkontaktFlow: View {
    @Bindable var modell: GeraetModel
    let beiAbschluss: () -> Void
    /// Verlaesst den Erstkontakt vorzeitig -- ein fullScreenCover kennt kein
    /// Swipe-to-dismiss, ohne diesen Ausgang stuende ein Mitglied, das sich
    /// vertippt oder umentscheidet, mit einer Hand am Geraet fest (Review
    /// Aufgabe 13, Fund 3). Nie zusammen mit erstkontaktAbschliessen(),
    /// sonst zeigte istErstkontakt faelschlich "erledigt".
    let beiAbbruch: () -> Void

    /// Einmal beim Oeffnen bestimmt, nicht bei jedem Rendern: die
    /// Definitionen koennen mit dem spaeter eintreffenden tagContext
    /// wechseln, und ein Flow, der mittendrin seine Stationen umbaut,
    /// zeigte dem Mitglied unter derselben Position ploetzlich einen
    /// anderen Schritt -- oder griff hinter das Ende der Liste. Dasselbe
    /// gilt fuer "laeuft ein Training": "Training starten" selbst aendert
    /// es, der Schritt darf dabei nicht verschwinden.
    @State private var schritte: [ErstkontaktSchritt]
    @State private var position = 0
    /// Wohin "Zurueck" nach "Kenne ich schon" fuehrt: an den Schritt, von
    /// dem aus uebersprungen wurde, nicht in die uebersprungene Einstellung.
    @State private var ruecksprung: Int?

    init(modell: GeraetModel, beiAbschluss: @escaping () -> Void, beiAbbruch: @escaping () -> Void) {
        self.modell = modell
        self.beiAbschluss = beiAbschluss
        self.beiAbbruch = beiAbbruch
        _schritte = State(initialValue: GeraetEinstiegRechner.erstkontaktSchritte(
            hatEinstellparameter: modell.hatEinstellparameter,
            trainingLaeuft: modell.trainingLaeuft))
    }

    var body: some View {
        Group {
            switch schritte[position] {
            case .einweisung:
                EinweisungSchritt(
                    modell: modell, titel: titel("Einweisung"),
                    hauptaktion: schritte.contains(.einstellung) ? "Einstellungen erfassen" : "Weiter",
                    beiAbbruch: beiAbbruch,
                    beiWeiter: { weiter() },
                    // Ohne Einstellung waere "Kenne ich schon" dasselbe wie
                    // "Weiter" -- genau die Doppelung aus #16.
                    beiUeberspringen: schritte.contains(.einstellung) ? { ueberspringen() } : nil)
            case .einstellung:
                KalibrierungSchritt(modell: modell, titel: titel("Deine Einstellung"),
                                    beiZurueck: { zurueck() }) { weiter() }
            case .trainingStarten:
                TrainingStartView(modell: modell, titel: titel("Training starten"),
                                  beiZurueck: { zurueck() }) {
                    modell.trainingStarten()
                    beiAbschluss()
                }
            }
        }
        .background(DesignSystem.Color.bg)
    }

    /// "Schritt 2 von 3 · Deine Einstellung" -- die Zahl folgt der
    /// tatsaechlichen Liste, nicht dem Regelfall.
    private func titel(_ name: String) -> String {
        "Schritt \(position + 1) von \(schritte.count) · \(name)"
    }

    private func weiter() {
        if position + 1 < schritte.count {
            position += 1
        } else {
            beiAbschluss()
        }
    }

    private func zurueck() {
        if let ziel = ruecksprung {
            ruecksprung = nil
            position = ziel
        } else {
            position = max(position - 1, 0)
        }
    }

    private func ueberspringen() {
        if let ziel = GeraetEinstiegRechner.positionNachUeberspringen(in: schritte) {
            ruecksprung = position
            position = ziel
        } else {
            beiAbschluss()
        }
    }
}
