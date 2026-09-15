import SwiftUI

/// Die beiden Werte, nackt auf der Flaeche -- kein Kasten, kein Rahmen,
/// kein Eingabefeld (designsystem.md SS7).
///
/// Beide Raeder sind immer aktiv (Sammelstelle Punkt 11): gescrollt wird
/// sofort, ohne Tap, ohne Tastatur, mit dem Daumen der Hand, die das Handy
/// haelt.
struct WertZeile: View {
    @Bindable var modell: GeraetModel

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
        }
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
            Text("SATZ \(modell.satzNummer)")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("scrollen, dann sichern")
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
                    // Ueber gewichtGewaehlt, nicht $modell.gewicht: nur so
                    // weiss das Modell, dass der Wert vom Mitglied kommt und
                    // ein spaeter Vorschlag ihn nicht mehr ersetzen darf.
                    auswahl: Binding(
                        get: { modell.gewicht },
                        set: { modell.gewichtGewaehlt($0) }
                    ),
                    unterstrich: .held,
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
    ///
    /// Der Vorschlag stand hier im geschlossenen Zustand; seit Schnitt 3
    /// steht er im Drawer beim Oeffnen des Geraets (RueckblickSheet), damit
    /// die Zeile immer dasselbe sagt.
    private var kontextzeileGewicht: some View {
        Text(modell.kontextzeileGewicht)
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
                    // Dieselbe accent-Linie wie beim Gewicht, nur duenner
                    // (siehe UnterstrichStil): die Linie sagt "hier rastet
                    // der Wert ein" -- dieselbe Aussage gehoert in beiden
                    // Spalten in dieselbe Farbe. Vorher war sie in `line`
                    // kaum von der Flaeche zu unterscheiden.
                    unterstrich: .zweitwert,
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
