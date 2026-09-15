import SwiftUI

/// Der Blick zurueck, bevor der erste Satz an diesem Geraet faellt: letzter
/// eigener Satz und Vorschlag, als Drawer von unten (Sammelstelle Punkt 11).
///
/// Ein Sheet statt einer Karte auf dem Satzpfad: beides stand vorher unter
/// dem Rad und in der Kontextzeile -- und machte den Pfad hoeher, als ein
/// 667-pt-iPhone hergibt (Punkt 12). Weggewischt bleibt der Satzpfad
/// zurueck, ohne dass sich dort etwas bewegt. Wann der Drawer kommt,
/// entscheidet GeraetModel.rueckblickFaellig, nicht dieser View.
struct RueckblickSheet: View {
    let uebung: String
    let rueckblick: Rueckblick
    let beiWeiter: () -> Void

    /// Gemessen statt geschaetzt: zwei oder drei Zeilen, die mit Dynamic
    /// Type wachsen -- ein fester Detent liesse "Weiter" bei grossen Stufen
    /// unter der Kante verschwinden. 220 ist nur der Startwert, bis die
    /// erste Messung da ist, damit das Sheet nicht aus dem Nichts waechst.
    @State private var hoehe: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                // Mit Uebung, nicht "an diesem Geraet": der letzte Satz
                // gehoert zur Uebung, und ein Geraet kann zwei haben.
                Text("ZULETZT · \(uebung.uppercased())")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(rueckblick.zuletzt)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.text)
                if let vorschlag = rueckblick.vorschlag {
                    // Eine Rechnung, keine Empfehlung (designsystem.md SS10)
                    // -- woertlich der Text, der vorher in der Kontextzeile
                    // stand.
                    Text(vorschlag)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
            // Ein Element fuer VoiceOver: "Zuletzt, Beidbeinig, 77,5 kg
            // mal 11, Vorschlag plus 2,5" -- drei Zeilen, ein Gedanke.
            .accessibilityElement(children: .combine)

            // Nebenaktion, keine Akzentflaeche: die eine des Screens ist
            // "Satz N sichern" dahinter (SS2).
            SecondaryButton(title: "Weiter", action: beiWeiter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s32)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .onGeometryChange(for: CGFloat.self) { proxy in
            // Die untere Safe Area gehoert zum Detent, nicht zum Inhalt:
            // ohne sie sitzt "Weiter" auf dem iPhone 17 Pro hinter dem
            // Home-Indikator, auf dem SE (keine) stimmt es zufaellig.
            proxy.size.height + proxy.safeAreaInsets.bottom
        } action: { hoehe = $0 }
        .presentationDetents([.height(hoehe)])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Color.surface)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RueckblickSheet(uebung: "Beidbeinig",
                            rueckblick: Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: "Vorschlag · +2,5"),
                            beiWeiter: {})
        }
}
