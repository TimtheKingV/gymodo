import SwiftUI

/// ± Stepper fuer die Kalibrierung.
///
/// Kein Rad: die Wertebereiche sind einstellig, dort waere ein Rad mehr
/// Mechanik als Nutzen (designsystem.md SS8).
struct Stepper44: View {
    let definition: TagContextResponse.SettingDefinition
    @Binding var wert: Double

    private var schritt: Double { definition.stepValue ?? 1 }
    private var untergrenze: Double { definition.minValue ?? 0 }
    private var obergrenze: Double { definition.maxValue ?? 99 }
    private var minusAktiv: Bool { wert > untergrenze }
    private var plusAktiv: Bool { wert < obergrenze }

    var body: some View {
        // Mirror von PrimaryButton.disabledHint: Zeile plus optionaler
        // Hinweis darunter, statt eines dritten Musters fuer "deaktiviert
        // ist nie stumm" (designsystem.md SS5).
        VStack(spacing: 6) {
            HStack(spacing: DesignSystem.Spacing.s16) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(definition.label)
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(bereichstext)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                Spacer()
                taste("minus", aktiv: minusAktiv) { wert = max(untergrenze, wert - schritt) }
                Text(anzeige)
                    .font(DesignSystem.Typography.wertSekundaer)
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(minWidth: 48)
                taste("plus", aktiv: plusAktiv) { wert = min(obergrenze, wert + schritt) }
            }
            .padding(DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(definition.label)
            .accessibilityValue(grenzhinweis.map { "\(anzeige), \($0)" } ?? anzeige)
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: wert = min(obergrenze, wert + schritt)
                case .decrement: wert = max(untergrenze, wert - schritt)
                @unknown default: break
                }
            }

            if let grenzhinweis {
                Text(grenzhinweis)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Wortlaut deckungsgleich mit GeraetModel.anschlagText fuers Gewichtsrad
    /// -- dieselbe Grenze verdient denselben Satz, gleich welches Steuerelement
    /// sie meldet (Rastwerte.maximumErreicht ist die eine Quelle dafuer).
    private var grenzhinweis: String? {
        if !minusAktiv { "Minimum erreicht" }
        else if !plusAktiv { Rastwerte.maximumErreicht }
        else { nil }
    }

    private var anzeige: String {
        let zahl = wert == wert.rounded() ? String(Int(wert)) : Zahlformat.gewicht(wert)
        return definition.unit.map { "\(zahl)\($0)" } ?? zahl
    }

    private var bereichstext: String {
        let von = untergrenze == untergrenze.rounded() ? String(Int(untergrenze)) : Zahlformat.gewicht(untergrenze)
        let bis = obergrenze == obergrenze.rounded() ? String(Int(obergrenze)) : Zahlformat.gewicht(obergrenze)
        let einheit = definition.unit ?? ""
        let s = schritt == schritt.rounded() ? String(Int(schritt)) : Zahlformat.gewicht(schritt)
        return "\(von) – \(bis)\(einheit) · Schritt \(s)"
    }

    /// Deaktiviert traegt surface-raised auf text-faint (designsystem.md SS5)
    /// -- das Artboard nutzt hier faelschlich surface.
    private func taste(_ symbol: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44)
                .background(DesignSystem.Color.surfaceRaised)
                .foregroundStyle(aktiv ? DesignSystem.Color.text : DesignSystem.Color.textFaint)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!aktiv)
        .accessibilityHidden(true)
    }
}
