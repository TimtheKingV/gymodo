import SwiftUI

/// Belastung und Umfang, nackt auf der Flaeche -- kein Kasten, kein Rahmen,
/// kein Eingabefeld (designsystem.md SS7).
///
/// Beide Raeder sind immer aktiv (Sammelstelle Punkt 11): gescrollt wird
/// sofort, ohne Tap, ohne Tastatur, mit dem Daumen der Hand, die das Handy
/// haelt.
///
/// Was die Zahlen bedeuten, liest die Zeile vom Modell: Einheit der
/// Belastung, Umfangsart, und ob es eine Nebenbelastung gibt. An einer
/// Beinpresse sind das kg, Wiederholungen und keine -- dann ist die Zeile
/// die von vor dem Umbau.
struct WertZeile: View {
    @Bindable var modell: GeraetModel

    /// Die Umfangsspalte bekommt feste Breite, die Belastung den Rest.
    ///
    /// Nicht Geschmack, sondern Struktur: eine Wiederholungszahl ist
    /// hoechstens zweistellig (Rastwerte.umfang(.reps) = 1...40),
    /// Belastungen gehen bis "1005,0". Zwei gleich breite Spalten gaben dem
    /// kurzen Wert genau so viel Platz wie dem langen -- und schnitten
    /// deshalb die Belastung ab. 104 pt: "40" bei 44 pt Black monospaced
    /// misst rund 53 pt, "Wdh." bei 17 pt Semibold rund 38 pt, dazu 4 pt
    /// Abstand -- knapp 95 pt mit etwas Luft. Jeder Punkt mehr fehlt der
    /// Belastung, und auf einem iPhone mini ist deren Spalte ohnehin die
    /// knappe.
    @ScaledMetric(relativeTo: .body) private var umfangsspalteSchmal: CGFloat = 104

    /// Zeit und Strecke sind laenger: "20:00" und "2.000" haben fuenf
    /// Zeichen und messen bei 44 pt Black rund 120 pt, dazu "min" (rund
    /// 30 pt) und 4 pt Abstand. Was darueber hinausgeht ("20.000"),
    /// schrumpft das Rad selbst (RastRad.minimumScaleFactor).
    @ScaledMetric(relativeTo: .body) private var umfangsspalteBreit: CGFloat = 152

    /// Die Breite folgt der Laenge dessen, was auf dem Rad steht -- nicht
    /// der Umfangsart. Die Listen steigen an, der letzte Wert ist der
    /// laengste.
    private var umfangsspalte: CGFloat {
        let laengster = modell.umfangsWerte.last.map { Zahlformat.umfang($0, modell.volumeKind) } ?? ""
        return laengster.count > 2 ? umfangsspalteBreit : umfangsspalteSchmal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            kopf
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s24) {
                belastungsrad
                    .frame(maxWidth: .infinity, alignment: .leading)
                umfangsrad
                    .frame(width: umfangsspalte, alignment: .leading)
            }
            nebenbelastung
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

    private var belastungsrad: some View {
        // Einmal gelesen: die Closures unten laufen beim Scrollen fuer jede
        // Zeile des Rads.
        let einheit = modell.loadUnit
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: modell.belastungsWerte,
                    // Ueber belastungGewaehlt, nicht $modell.belastung: nur
                    // so weiss das Modell, dass der Wert vom Mitglied kommt
                    // und ein spaeter Vorschlag ihn nicht mehr ersetzen darf.
                    auswahl: Binding(
                        get: { modell.belastung },
                        set: { modell.belastungGewaehlt($0) }
                    ),
                    unterstrich: .held,
                    voLabel: "Belastung",
                    voWert: { Zahlformat.belastungGesprochen($0, einheit) },
                    anschlagText: modell.anschlagText,
                    text: { Zahlformat.belastung($0, einheit) },
                    sichtbareZeilen: 3
                )
                Text(einheit.kurz)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            kontextzeileBelastung
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
    private var kontextzeileBelastung: some View {
        Text(modell.kontextzeileBelastung)
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .accessibilityHidden(true)
    }

    /// Zweiter Wert, kleiner als die Belastung (Main.dc.html: 44 gegen 64)
    /// -- die Belastung ist der Held der Zeile, der Umfang der zweite Wert.
    /// `RastRad.basisGroesse` traegt genau diesen Unterschied.
    ///
    /// Minuten und Meter liest das Mitglied von der Anzeige des Geraets ab --
    /// der Sensor zaehlt nur Wiederholungen -- und stellt sie hier ein, wie das Gewicht
    /// vom Stapel (Cardio-Spec Abschnitt 10, kein laufender Timer).
    private var umfangsrad: some View {
        let art = modell.volumeKind
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: modell.umfangsWerte.map(Double.init),
                    auswahl: Binding(
                        get: { Double(modell.umfang) },
                        set: { modell.umfang = Int($0) }
                    ),
                    // Dieselbe accent-Linie wie bei der Belastung, nur
                    // duenner (siehe UnterstrichStil): die Linie sagt "hier
                    // rastet der Wert ein" -- dieselbe Aussage gehoert in
                    // beiden Spalten in dieselbe Farbe. Vorher war sie in
                    // `line` kaum von der Flaeche zu unterscheiden.
                    unterstrich: .zweitwert,
                    voLabel: art.radname,
                    voWert: { Zahlformat.umfangGesprochen(Int($0), art) },
                    anschlagText: nil,
                    // "20:00" statt 1200, "2.000" statt 2000: Anzeige, nicht
                    // Wert -- gespeichert bleibt die ganze Zahl.
                    text: { Zahlformat.umfang(Int($0), art) },
                    basisGroesse: 44,
                    sichtbareZeilen: 3
                )
                Text(art.kurz)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            Text(modell.kontextzeileUmfang)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .accessibilityHidden(true)
        }
    }

    /// Der zweite Intensitaetsregler, nur wo das Modell einen hat.
    ///
    /// Eine Zeile mit ± statt eines dritten Rads: die Neigung ist vom
    /// letzten Satz vorbelegt und bleibt im Normalfall stehen (Cardio-Spec
    /// 3.1b) -- wer sie nicht anfasst, bestaetigt den Vorwert, und die
    /// Interaktionszahl steigt nicht. Ein drittes Rad naehme dem
    /// Belastungsrad auf einem iPhone mini die Breite fuer einen Wert, der
    /// sich selten aendert. Die Zeile ist 44 pt hoch und damit so hoch wie
    /// die Einstellwerte-Zeile ueber den Raedern.
    ///
    /// An einem Geraet ohne Nebenbelastung gibt es die Zeile nicht, und der
    /// Screen ist der eines Kraftgeraets.
    @ViewBuilder
    private var nebenbelastung: some View {
        if let einheit = modell.secondaryUnit,
           let bereich = modell.nebenbelastungBereich,
           let wert = modell.nebenbelastung {
            Stepper44(
                label: einheit.reglername,
                bereichstext: "\(Zahlformat.belastung(bereich.lowerBound, einheit)) – \(Zahlformat.belastung(bereich.upperBound, einheit))",
                schritt: modell.nebenbelastungSchritt,
                bereich: bereich,
                // Ueber nebenbelastungGewaehlt: dieselbe Regel wie bei der
                // Belastung -- ein spaeter Vorschlag ersetzt nur, was das
                // Mitglied nicht selbst gesetzt hat.
                wert: Binding(
                    get: { wert },
                    set: { modell.nebenbelastungGewaehlt($0) }
                ),
                anzeige: { Zahlformat.belastungMitEinheit($0, einheit) },
                gesprochen: { Zahlformat.belastungGesprochen($0, einheit) }
            )
            .testnotizElement("geraet.nebenbelastung", typ: "Stepper44")
        }
    }
}
