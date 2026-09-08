import SwiftUI

/// Die beiden Werte, nackt auf der Flaeche -- kein Kasten, kein Rahmen,
/// kein Eingabefeld (designsystem.md SS7).
///
/// Ein Tap auf EINE der beiden Zahlen oeffnet BEIDE Raeder. Danach wird nur
/// noch gescrollt: ohne weiteren Tap und ohne Tastatur, mit dem Daumen der
/// Hand, die das Handy haelt.
struct WertZeile: View {
    @Bindable var modell: GeraetModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            kopf
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s24) {
                gewichtsrad
                wiederholungsrad
            }
            if !modell.radOffen, let zuletzt = modell.zuletztText {
                Text(zuletzt)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !modell.radOffen else { return }
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.oeffnen) {
                modell.radOffen = true
            }
        }
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
            Text("SATZ \(modell.satzNummer)")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text(modell.radOffen ? "scrollen, dann sichern" : "antippen und scrollen")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .accessibilityHidden(true)
    }

    private var gewichtsrad: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: modell.gewichtsWerte,
                    auswahl: $modell.gewicht,
                    offen: modell.radOffen,
                    unterstrich: .akzent,
                    voLabel: "Gewicht",
                    voWert: Zahlformat.gewichtGesprochen,
                    anschlagText: modell.anschlagText,
                    text: Zahlformat.gewicht
                )
                Text("kg")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            kontextzeileGewicht
        }
    }

    /// Am Anschlag tritt die Grenze an die Stelle des Kontexts -- sichtbares
    /// Anschlagsfeedback, nicht nur eine VoiceOver-Ansage (SS6: Haptik nie
    /// als einzige Rueckmeldung).
    private var kontextzeileGewicht: some View {
        let amAnschlag = modell.anschlagText != nil
            && (modell.gewicht == modell.gewichtsWerte.first
                || modell.gewicht == modell.gewichtsWerte.last)
        let text = amAnschlag
            ? (modell.anschlagText ?? "")
            : (modell.radOffen ? modell.kontextzeileGewicht : (modell.vorschlagText ?? modell.kontextzeileGewicht))
        return Text(text)
            .font(.system(size: 12))
            .foregroundStyle(amAnschlag ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint)
            .accessibilityHidden(true)
    }

    /// Zweiter Wert, kleiner als das Gewicht (Main.dc.html: 44 gegen 64) --
    /// das Gewicht ist der Held der Zeile, die Wiederholungen der zweite
    /// Wert. `RastRad.basisGroesse` traegt genau diesen Unterschied.
    private var wiederholungsrad: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: Rastwerte.wiederholungen.map(Double.init),
                    auswahl: Binding(
                        get: { Double(modell.wiederholungen) },
                        set: { modell.wiederholungen = Int($0) }
                    ),
                    offen: modell.radOffen,
                    unterstrich: .linie,
                    voLabel: "Wiederholungen",
                    voWert: { Zahlformat.wiederholungenGesprochen(Int($0)) },
                    anschlagText: nil,
                    text: { String(Int($0)) },
                    basisGroesse: 44
                )
                Text("Wdh.")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            Text(modell.kontextzeileWiederholungen)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .accessibilityHidden(true)
        }
    }
}
