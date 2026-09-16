import SwiftUI

/// Der modale Dreischritt. fullScreenCover verdeckt die Tab-Leiste -- genau
/// das verlangt designsystem.md SS8 ("ohne Tab-Leiste"). Er laeuft genau
/// einmal je Geraet UND Uebung.
///
/// "Drei" ist der Regelfall: an einem Modell ohne Einstellparameter faellt
/// die Einstellung weg, und auf die Einweisung folgt direkt der erste Satz
/// (GeraetEinstiegRechner.erstkontaktSchritte).
struct ErstkontaktFlow: View {
    @Bindable var modell: GeraetModel
    let beiAbschluss: () -> Void
    /// Verlaesst den Dreischritt vorzeitig -- ein fullScreenCover kennt kein
    /// Swipe-to-dismiss, ohne diesen Ausgang stuende ein Mitglied, das sich
    /// vertippt oder umentscheidet, mit einer Hand am Geraet fest (Review
    /// Aufgabe 13, Fund 3). Eine spaetere Aufgabe verdrahtet ihn gegen die
    /// Navigation; hier wird er nur durchgereicht und aufgerufen -- nie
    /// zusammen mit erstkontaktAbschliessen(), sonst zeigte istErstkontakt
    /// faelschlich "erledigt".
    let beiAbbruch: () -> Void

    /// Einmal beim Oeffnen bestimmt, nicht bei jedem Rendern: die
    /// Definitionen koennen mit dem spaeter eintreffenden tagContext
    /// wechseln, und ein Flow, der mittendrin seine Stationen umbaut,
    /// zeigte dem Mitglied unter derselben Position ploetzlich einen
    /// anderen Schritt -- oder griff hinter das Ende der Liste.
    @State private var schritte: [ErstkontaktSchritt]
    @State private var position = 0

    init(modell: GeraetModel, beiAbschluss: @escaping () -> Void, beiAbbruch: @escaping () -> Void) {
        self.modell = modell
        self.beiAbschluss = beiAbschluss
        self.beiAbbruch = beiAbbruch
        _schritte = State(initialValue: GeraetEinstiegRechner.erstkontaktSchritte(
            hatEinstellparameter: modell.hatEinstellparameter))
    }

    var body: some View {
        Group {
            switch schritte[position] {
            case .einweisung:
                EinweisungSchritt(modell: modell, beiAbbruch: beiAbbruch) { weiter() }
            case .einstellung:
                // Der Titel darf "von 3" sagen: die Einstellung steht nur in
                // der dreiteiligen Liste.
                KalibrierungSchritt(modell: modell,
                                    titel: "Schritt 2 von 3 · Deine Einstellung",
                                    beiZurueck: { zurueck() }) { weiter() }
            case .ersteWerte:
                ErsteWerteSchritt(modell: modell, beiZurueck: { zurueck() }, beiSichern: beiAbschluss)
            }
        }
        .background(DesignSystem.Color.bg)
    }

    private func weiter() { position = min(position + 1, schritte.count - 1) }
    private func zurueck() { position = max(position - 1, 0) }
}
