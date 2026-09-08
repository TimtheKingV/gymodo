import SwiftUI

/// Der modale Dreischritt. fullScreenCover verdeckt die Tab-Leiste -- genau
/// das verlangt designsystem.md SS8 ("ohne Tab-Leiste"). Er laeuft genau
/// einmal je Geraet UND Uebung.
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

    @State private var schritt = 1

    var body: some View {
        Group {
            switch schritt {
            case 1: EinweisungSchritt(modell: modell, beiAbbruch: beiAbbruch) { schritt = 2 }
            case 2: KalibrierungSchritt(modell: modell,
                                        titel: "Schritt 2 von 3 · Deine Einstellung",
                                        beiZurueck: { schritt = 1 }) { schritt = 3 }
            default: ErsteWerteSchritt(modell: modell, beiZurueck: { schritt = 2 }, beiSichern: beiAbschluss)
            }
        }
        .background(DesignSystem.Color.bg)
    }
}
