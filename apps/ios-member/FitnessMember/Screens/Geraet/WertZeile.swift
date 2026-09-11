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
    /// Die Wiederholungsspalte bekommt feste Breite, das Gewicht den Rest.
    ///
    /// Nicht Geschmack, sondern Struktur: Wiederholungen sind hoechstens
    /// zweistellig (Rastwerte.wiederholungen = 1...40), Gewichte gehen bis
    /// "1005,0". Zwei gleich breite Spalten gaben dem kurzen Wert genau so
    /// viel Platz wie dem langen -- und schnitten deshalb das Gewicht ab.
    /// 104 pt: "40" bei 44 pt Black monospaced misst rund 53 pt, "Wdh."
    /// bei 17 pt Semibold rund 38 pt, dazu 4 pt Abstand -- knapp 95 pt mit
    /// etwas Luft. Jeder Punkt mehr fehlt dem Gewicht, und auf einem
    /// iPhone mini ist dessen Spalte ohnehin die knappe.
    @ScaledMetric(relativeTo: .body) private var wiederholungsspalte: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            kopf
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s24) {
                gewichtsrad
                    .frame(maxWidth: .infinity, alignment: .leading)
                wiederholungsrad
                    .frame(width: wiederholungsspalte, alignment: .leading)
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
                modell.radOeffnen()
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

    /// Schritt und Bereich, immer dieselbe Zeile.
    ///
    /// Sie hat frueher am Anschlag "Maximum des Geraets erreicht" gezeigt
    /// und dafuer Schritt und Bereich verdraengt. Der Satz stand damit
    /// haeufiger da, als die Grenze eine Rolle spielte, und nahm der Zeile
    /// genau die Zahlen, die man beim Scrollen braucht. Der Anschlag bleibt
    /// hoerbar (RastRad.voWertMitAnschlag) und spuerbar (anschlagStoss);
    /// sichtbar traegt ihn jetzt die Bereichsangabe in dieser Zeile, deren
    /// Ende man erreicht hat.
    private var kontextzeileGewicht: some View {
        Text(modell.radOffen
             ? modell.kontextzeileGewicht
             : (modell.vorschlagText ?? modell.kontextzeileGewicht))
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
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
