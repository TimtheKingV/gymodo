import SwiftUI

/// Der modale Dreischritt. fullScreenCover verdeckt die Tab-Leiste -- genau
/// das verlangt designsystem.md SS8 ("ohne Tab-Leiste"). Er laeuft genau
/// einmal je Geraet UND Uebung.
struct ErstkontaktFlow: View {
    @Bindable var modell: GeraetModel
    let beiAbschluss: () -> Void

    @State private var schritt = 1

    var body: some View {
        Group {
            switch schritt {
            case 1: EinweisungSchritt(modell: modell) { schritt = 2 }
            case 2: KalibrierungSchritt(modell: modell,
                                        titel: "Schritt 2 von 3 · Deine Einstellung") { schritt = 3 }
            default: ErsteWerteSchritt(modell: modell, beiSichern: beiAbschluss)
            }
        }
        .background(DesignSystem.Color.bg)
    }
}
