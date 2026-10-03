import SwiftUI

/// ± Stepper fuer die Kalibrierung und fuer die Nebenbelastung.
///
/// Kein Rad: die Wertebereiche der Kalibrierung sind einstellig, dort waere
/// ein Rad mehr Mechanik als Nutzen (designsystem.md SS8). Die
/// Nebenbelastung (Neigung am Laufband) aendert sich selten und ist vom
/// letzten Satz vorbelegt -- ein drittes Rad kostete dort Breite, die das
/// Belastungsrad auf einem schmalen iPhone braucht, fuer einen Wert, den
/// das Mitglied im Normalfall gar nicht anfasst.
struct Stepper44: View {
    /// Zwei Gestalten desselben Steuerelements.
    enum Gestalt {
        /// Auf einer surface-Karte, mit Grenzhinweis darunter -- der
        /// Kalibrierungsschritt, der die ganze Seite fuer sich hat.
        case karte
        /// Nackt und genau 44 pt hoch -- die Zeile unter den Raedern des
        /// Satzpfads, der auf ein 667-pt-iPhone passen muss und deshalb
        /// weder Kartenrand noch eine Hinweiszeile traegt.
        case zeile
    }

    let label: String
    let bereichstext: String
    let schritt: Double
    let untergrenze: Double
    let obergrenze: Double
    let gestalt: Gestalt
    /// Der Wert, wie er zwischen den Tasten steht.
    let anzeige: (Double) -> String
    /// Der Wert fuer VoiceOver -- eine Zeichenkette mit ausgeschriebener
    /// Einheit (designsystem.md SS12).
    let gesprochen: (Double) -> String
    @Binding var wert: Double

    private var minusAktiv: Bool { wert > untergrenze }
    private var plusAktiv: Bool { wert < obergrenze }

    /// Die Kalibrierung: alles kommt aus der Definition des Studios.
    init(definition: TagContextResponse.SettingDefinition, wert: Binding<Double>) {
        let schritt = definition.stepValue ?? 1
        let untergrenze = definition.minValue ?? 0
        let obergrenze = definition.maxValue ?? 99
        let einheit = definition.unit ?? ""
        label = definition.label
        bereichstext = "\(Self.zahl(untergrenze)) – \(Self.zahl(obergrenze))\(einheit) · Schritt \(Self.zahl(schritt))"
        self.schritt = schritt
        self.untergrenze = untergrenze
        self.obergrenze = obergrenze
        gestalt = .karte
        anzeige = { "\(Self.zahl($0))\(einheit)" }
        gesprochen = { "\(Self.zahl($0))\(einheit)" }
        _wert = wert
    }

    /// Die Zeile unter den Raedern. Wer sie baut, kennt die Einheit und
    /// bringt die Formatierung mit -- der Stepper selbst kennt keine.
    init(
        label: String, bereichstext: String,
        schritt: Double, bereich: ClosedRange<Double>,
        wert: Binding<Double>,
        anzeige: @escaping (Double) -> String,
        gesprochen: @escaping (Double) -> String
    ) {
        self.label = label
        self.bereichstext = bereichstext
        self.schritt = schritt
        untergrenze = bereich.lowerBound
        obergrenze = bereich.upperBound
        gestalt = .zeile
        self.anzeige = anzeige
        self.gesprochen = gesprochen
        _wert = wert
    }

    var body: some View {
        switch gestalt {
        case .karte:
            // Mirror von PrimaryButton.disabledHint: Zeile plus optionaler
            // Hinweis darunter, statt eines dritten Musters fuer "deaktiviert
            // ist nie stumm" (designsystem.md SS5).
            VStack(spacing: 6) {
                zeile
                    .padding(DesignSystem.Spacing.s16)
                    .background(DesignSystem.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                    .bedienbar(self)

                if let grenzhinweis {
                    Text(grenzhinweis)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .zeile:
            // Ohne Hinweiszeile: die kostete am Minimum -- dem Normalfall
            // einer Neigung von 0 -- genau die Hoehe, die der Satzpfad
            // nicht hat. Stumm ist die deaktivierte Taste trotzdem nicht:
            // der Bereich steht unter dem Label, und wer an seinem Ende
            // steht, sieht es dort -- dieselbe Loesung wie die Kontextzeile
            // unter dem Belastungsrad. VoiceOver bekommt den Satz weiter.
            zeile
                .frame(minHeight: 44)
                .bedienbar(self)
        }
    }

    private var zeile: some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            VStack(alignment: .leading, spacing: gestalt == .karte ? DesignSystem.Spacing.s4 : 2) {
                Text(label)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(bereichstext)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            // Nur in der Zeile: dort gibt es genau 44 pt. Auf der Karte
            // darf ein langes Label des Studios weiter umbrechen.
            .lineLimit(gestalt == .zeile ? 1 : nil)
            Spacer()
            taste("minus", aktiv: minusAktiv) { verringern() }
            Text(anzeige(wert))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
                .frame(minWidth: 48)
                // "85 U/min" ist breiter als jeder Einstellwert; in der
                // Zeile gibt das Label nach, nicht die Zahl.
                .fixedSize(horizontal: gestalt == .zeile, vertical: false)
            taste("plus", aktiv: plusAktiv) { erhoehen() }
        }
    }

    fileprivate func erhoehen() { wert = min(obergrenze, wert + schritt) }
    fileprivate func verringern() { wert = max(untergrenze, wert - schritt) }

    fileprivate var voWert: String {
        grenzhinweis.map { "\(gesprochen(wert)), \($0)" } ?? gesprochen(wert)
    }

    /// Wortlaut deckungsgleich mit GeraetModel.anschlagText fuers
    /// Belastungsrad -- dieselbe Grenze verdient denselben Satz, gleich
    /// welches Steuerelement sie meldet (Rastwerte.maximumErreicht ist die
    /// eine Quelle dafuer).
    private var grenzhinweis: String? {
        if !minusAktiv { "Minimum erreicht" }
        else if !plusAktiv { Rastwerte.maximumErreicht }
        else { nil }
    }

    /// Einstellwerte sind Rasten ("Sitz 4"), keine Messwerte: ganz, wo sie
    /// ganz sind, sonst mit einer Nachkommastelle und Dezimalkomma.
    private static func zahl(_ wert: Double) -> String {
        wert == wert.rounded() ? String(Int(wert)) : Zahlformat.gewicht(wert)
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

private extension View {
    /// Ein Element fuer VoiceOver, verstellbar per Wischgeste -- in beiden
    /// Gestalten dasselbe, deshalb an einer Stelle.
    func bedienbar(_ stepper: Stepper44) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(stepper.label)
            .accessibilityValue(stepper.voWert)
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: stepper.erhoehen()
                case .decrement: stepper.verringern()
                @unknown default: break
                }
            }
    }
}
