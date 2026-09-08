import SwiftUI

/// Schritt 3 von 3. Fuehrt die Rad-Geste zum ersten Mal ein -- deshalb ist
/// die Groesse hier dieselbe wie ueberall (64pt), nicht 58 wie im Artboard.
///
/// gymodo schlaegt beim ersten Mal bewusst nichts vor: es hat keine
/// Historie, und ein Vorschlag ohne Daten waere eine Trainingsempfehlung
/// (designsystem.md SS8). Das Rad startet am Geraetminimum.
struct ErsteWerteSchritt: View {
    @Bindable var modell: GeraetModel
    let beiSichern: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                Text("SCHRITT 3 VON 3 · ERSTE WERTE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)

                Text(modell.maschine.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)

                Text("Womit fängst du an? Stell ein, was sich für dich richtig anfühlt — ab dem nächsten Mal steht dein Wert hier von allein.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(4)

                WertZeile(modell: modell)

                Text("gymodo schlägt beim ersten Mal bewusst nichts vor — es kennt dich noch nicht. Vorschläge entstehen erst aus deiner eigenen Historie.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .lineSpacing(3)

                PrimaryButton(title: "Ersten Satz sichern") {
                    await modell.satzSichern(problemFlag: false, problemReason: nil)
                    beiSichern()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
        .onAppear { modell.radOffen = true }
    }
}
