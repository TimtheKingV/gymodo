import Koerperbild
import SwiftUI
import UIKit

/// Einmal vor dem Start eines Flows mit Kamera-Schritt: Handy aufstellen, bis die Person stehend sicher
/// im Bild ist (`ganzkoerper_stehend`). "Ohne Kamera starten" ist immer da. Reine Ansicht: der Stand
/// kommt aus `FlowKameraModell`, der Lauf startet beim Aufrufer, sobald `.bereit` oder `.ohneKamera` gilt.
struct FlowAufstellView: View {
    let start: FlowKameraModell.Start
    let ziel: Livebildziel
    let skelett: Skelett?
    let beiOhneKamera: () -> Void
    let beiAbbrechen: () -> Void

    static let ohneKameraTitel = "Ohne Kamera starten"
    static let aufstelltext = "Stell das Handy so auf, dass du stehend und am Boden liegend ganz im Bild bist."

    var body: some View {
        Group {
            switch start {
            case .erlaubnisFehlt:
                ErlaubnisFehltSchritt(beiEinstellungen: Self.einstellungenOeffnen, beiOhneKamera: beiOhneKamera,
                                      ohneKameraTitel: Self.ohneKameraTitel)
                    .overlay(alignment: .topTrailing) { schliessenKnopf.padding(.trailing, DesignSystem.Spacing.s8) }
            case .kameraFehlt:
                KameraFehltSchritt(beiOhneKamera: beiOhneKamera, ohneKameraTitel: Self.ohneKameraTitel)
                    .overlay(alignment: .topTrailing) { schliessenKnopf.padding(.trailing, DesignSystem.Spacing.s8) }
            case .aufstellen, .bereit, .ohneKamera:
                aufstellen
            }
        }
    }

    private var aufstellen: some View {
        ZStack {
            KameraBildflaeche(ziel: ziel, skelett: skelett, profil: FlowKameraModell.aufstellVorgabe.profil,
                              bestanden: start == .bereit)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                    HStack {
                        Text("AUFSTELLEN")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        Spacer()
                        schliessenKnopf
                    }
                    Text(Self.aufstelltext)
                        .font(.system(size: 19, weight: .heavy))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .padding(.bottom, DesignSystem.Spacing.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .kameraLeiste(.top)
                Spacer(minLength: 0)
                OhneKameraKnopf(titel: Self.ohneKameraTitel, aktion: beiOhneKamera)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.s12)
                    .kameraLeiste(.bottom)
            }
        }
        .foregroundStyle(DesignSystem.Color.text)
    }

    private var schliessenKnopf: some View {
        Button(action: beiAbbrechen) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Abbrechen")
    }

    private static func einstellungenOeffnen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#if DEBUG
#Preview("Aufstellen") {
    FlowAufstellView(start: .aufstellen, ziel: .leer, skelett: KameraVorschau.skelett(),
                     beiOhneKamera: {}, beiAbbrechen: {})
}

#Preview("Aufstellen bestanden") {
    FlowAufstellView(start: .bereit, ziel: .leer, skelett: KameraVorschau.skelett(),
                     beiOhneKamera: {}, beiAbbrechen: {})
}

#Preview("Erlaubnis fehlt") {
    FlowAufstellView(start: .erlaubnisFehlt, ziel: .leer, skelett: nil, beiOhneKamera: {}, beiAbbrechen: {})
}

#Preview("Kamera fehlt") {
    FlowAufstellView(start: .kameraFehlt, ziel: .leer, skelett: nil, beiOhneKamera: {}, beiAbbrechen: {})
}
#endif
