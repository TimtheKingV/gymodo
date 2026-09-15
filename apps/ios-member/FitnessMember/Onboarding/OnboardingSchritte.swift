import SwiftUI

/// Die gemeinsame Huelle aller fuenf Onboarding-Screens (gen.py `onboarding()`):
/// Schrittzeile mit "Später", fuenf Segmente, Titel/Lead, der Inhalt des
/// Screens, danach die Hauptaktion (64 pt) und eine optionale Fussnote.
/// Seitenrand 28 -- die Einstiegskette, noch ohne Tab-Leiste.
///
/// Nimmt nur einfache Werte und Closures entgegen (kein `@Environment`),
/// damit sie sich fuer die Sichtpruefung per `ImageRenderer` losgeloest von
/// `OnboardingFlow` rendern laesst.
struct OnboardingScreen<Inhalt: View>: View {
    let schrittNummer: Int
    let gesamtSchritte: Int
    let titel: String
    let lead: String
    let fussnote: String?
    let primaryTitle: String
    let primaryEnabled: Bool
    let primaryLoading: Bool
    let primaryDisabledHint: String?
    /// Waehrend eines Schreibvorgangs sind beide Aktionen des Screens
    /// gesperrt, nicht nur die Hauptaktion (Brief: "nicht stumm") -- der
    /// Hinweistext unter der Hauptaktion erklaert beide auf einmal.
    var spaeterEnabled: Bool = true
    let beiSpaeter: () -> Void
    let beiWeiter: () async -> Void
    @ViewBuilder var inhalt: () -> Inhalt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                kopfzeile
                segmente
                    .padding(.top, DesignSystem.Spacing.s8)
                titelUndLead
                    .padding(.top, DesignSystem.Spacing.s24)
                inhalt()
                    .padding(.top, DesignSystem.Spacing.s24)
            }
            .padding(.horizontal, 28)
            .padding(.top, DesignSystem.Spacing.s16)
            .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            fussbereich
        }
    }

    private var kopfzeile: some View {
        HStack(alignment: .center) {
            Text("SCHRITT \(schrittNummer) VON \(gesamtSchritte)")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.textMuted)
                // Ein Element statt drei (Eyebrow + fuenf Segmente): die
                // sichtbare Grossschreibung bleibt, VoiceOver hoert die
                // natuerliche Form (Brief, VoiceOver-Abschnitt).
                .accessibilityLabel("Schritt \(schrittNummer) von \(gesamtSchritte)")

            Spacer()

            Button("Später", action: beiSpaeter)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(spaeterEnabled ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint)
                .frame(minHeight: 44)
                .buttonStyle(PressButtonStyle())
                .disabled(!spaeterEnabled)
        }
    }

    /// Fuenf Segmente, i < schrittNummer gefuellt -- wie gen.py `onboarding()`.
    /// Rein dekorativ (Formen sind ohnehin keine Accessibility-Elemente),
    /// trotzdem explizit versteckt, falls Xcode das je aendert.
    private var segmente: some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < schrittNummer ? DesignSystem.Color.text : DesignSystem.Color.line)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private var titelUndLead: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel.uppercased())
                .font(DesignSystem.Typography.screentitel)
                .tracking(-1)
                .foregroundStyle(DesignSystem.Color.text)
            Text(lead)
                .font(.system(size: 15))
                // Nur Schritt 5 traegt eine Ziffer ("Heute 82,5 kg. …"),
                // aber die Zeile ist fuer alle fuenf Screens dieselbe --
                // tabellarisch schadet den ziffernlosen Leads nicht
                // (globale Regel "Alle Ziffern tabellarisch").
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineSpacing(3)
        }
    }

    private var fussbereich: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            PrimaryButton(
                title: primaryTitle,
                isEnabled: primaryEnabled,
                isLoading: primaryLoading,
                disabledHint: primaryDisabledHint
            ) {
                await beiWeiter()
            }
            if let fussnote {
                Text(fussnote)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .padding(.top, DesignSystem.Spacing.s12)
        .background(DesignSystem.Color.bg)
    }
}

// MARK: - Schritt 1: Über dich

/// Geschlecht (drei Chips) und Altersspanne (sieben Chips, vier Spalten) --
/// beides optional, ein zweiter Tipp waehlt wieder ab.
struct UeberDichSchritt: View {
    @Binding var geschlecht: Geschlecht?
    @Binding var altersspanne: Altersspanne?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            OnboardingAbschnitt(label: "Geschlecht") {
                ChipGitter(werte: Geschlecht.alle, text: \.wort, auswahl: $geschlecht, spalten: 3)
            }
            OnboardingAbschnitt(
                label: "Alter",
                hinweis: "Als Spanne, damit die App nichts rechnen muss, was sie nicht wissen soll."
            ) {
                ChipGitter(werte: Altersspanne.alle, text: \.wort, auswahl: $altersspanne, spalten: 4)
            }
            // Wortlaut aus dem Artboard (gen.py, Onboarding1) -- eigene Zeile
            // unter beiden Abschnitten, kein Teil von "Alter" allein.
            Text("Wofür: später als Grundlage für Startgewichte am Gerät und für Trainingspläne. Heute noch für nichts.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .lineSpacing(2)
        }
    }
}

/// Label + Inhalt + optionaler Hinweis darunter -- gen.py `abschnitt()`.
private struct OnboardingAbschnitt<Inhalt: View>: View {
    let label: String
    var hinweis: String? = nil
    @ViewBuilder var inhalt: () -> Inhalt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            inhalt()
            if let hinweis {
                Text(hinweis)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .lineSpacing(2)
            }
        }
    }
}

/// Ein Gitter aus `Chip`s, genau eine Auswahl. Ein zweiter Tipp auf die
/// gewaehlte Chip waehlt ab (Brief Step 2) -- "nichts gewaehlt" ist ein
/// gueltiger Endzustand, kein Zwischenzustand.
///
/// Nicht `private`: `AuswahlSheet` (Aufgabe 10) zeigt Geschlecht, Alter
/// und Richtung im Profil mit demselben Chip-Gitter statt es ein zweites
/// Mal zu zeichnen (Aufgabe-10-Brief: "wie im Onboarding").
struct ChipGitter<Wert: Hashable>: View {
    let werte: [Wert]
    let text: (Wert) -> String
    @Binding var auswahl: Wert?
    let spalten: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.s8), count: spalten),
            spacing: DesignSystem.Spacing.s8
        ) {
            ForEach(werte, id: \.self) { wert in
                let istAktiv = auswahl == wert
                Button {
                    auswahl = istAktiv ? nil : wert
                } label: {
                    Chip(text: text(wert), isActive: istAktiv)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityAddTraits(istAktiv ? [.isSelected] : [])
            }
        }
    }
}

// MARK: - Schritt 2: Dein Körper

/// Groesse als Stepper-Zeile, Gewicht per `RastRad` -- beides leer, bis
/// angetippt (Brief Step 2).
struct KoerperSchritt: View {
    @Binding var groesseCm: Int?
    @Binding var gewichtKg: Double?

    private static let gewichtswerte = Array(stride(from: 20.0, through: 400.0, by: 0.5))

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            OnboardingAbschnitt(label: "Größe") {
                GroesseStepperZeile(groesseCm: $groesseCm)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                Text("GEWICHT HEUTE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                GewichtsRadOderPlatzhalter(gewichtKg: $gewichtKg, werte: Self.gewichtswerte, startwert: 75.0)
            }
        }
    }
}

/// Minus 58×58, Wert, Plus -- kein `Stepper44` (das haengt an
/// `SettingDefinition`, siehe Kommentar dort). 100–250, Schritt 1, leer bis
/// zum ersten Tipp; der startet bei 170 -- ein Stepper braucht einen
/// Startwert, und 170 ist die Mitte des moeglichen Bereichs, unabhaengig
/// davon, ob der erste Tipp Minus oder Plus war (wie beim Gewichtsrad).
///
/// Nicht `private`: `GroesseSheet` (Aufgabe 10) reicht dieselbe Zeile
/// unveraendert durch, statt sie im Profil ein zweites Mal zu bauen.
struct GroesseStepperZeile: View {
    @Binding var groesseCm: Int?
    private let bereich = 100...250

    private var minusAktiv: Bool { groesseCm.map { $0 > bereich.lowerBound } ?? true }
    private var plusAktiv: Bool { groesseCm.map { $0 < bereich.upperBound } ?? true }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                knopf(systemName: "minus", aktiv: minusAktiv) { schieben(um: -1) }
                wert
                knopf(systemName: "plus", aktiv: plusAktiv) { schieben(um: 1) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Größe")
            .accessibilityValue(groesseCm.map { "\($0) Zentimeter" } ?? "keine Angabe")
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: schieben(um: 1)
                case .decrement: schieben(um: -1)
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

    private var grenzhinweis: String? {
        guard let groesseCm else { return nil }
        if groesseCm <= bereich.lowerBound { return "Minimum erreicht" }
        if groesseCm >= bereich.upperBound { return "Maximum erreicht" }
        return nil
    }

    private func schieben(um delta: Int) {
        guard let bisher = groesseCm else {
            groesseCm = 170
            return
        }
        groesseCm = min(bereich.upperBound, max(bereich.lowerBound, bisher + delta))
    }

    private var wert: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(groesseCm.map(String.init) ?? "—")
                .font(.system(size: 22, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
            Text("cm")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }

    private func knopf(systemName: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(aktiv ? DesignSystem.Color.text : DesignSystem.Color.textFaint)
                .frame(width: 58, height: 58)
                .background(DesignSystem.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!aktiv)
        .accessibilityHidden(true)
    }
}

/// Leer bis zum ersten Tipp, danach das `RastRad` bei `startwert` --
/// dieselbe Rolle wie WertZeile am Geraet, nur ohne Geraete-Obergrenze
/// (`anschlagText: nil`, Werte aus `stride(from: 20, through: 400, by: 0.5)`
/// statt aus einem Geraetemodell).
private struct GewichtsRadOderPlatzhalter: View {
    @Binding var gewichtKg: Double?
    let werte: [Double]
    let startwert: Double

    var body: some View {
        if let gewichtKg {
            VStack(spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: werte,
                    auswahl: Binding(get: { gewichtKg }, set: { self.gewichtKg = $0 }),
                    offen: true,
                    unterstrich: .held,
                    voLabel: "Gewicht",
                    voWert: Zahlformat.gewichtGesprochen,
                    anschlagText: nil,
                    text: Zahlformat.gewicht
                )
                Text("Schritt 0,5 kg · scrollen")
                    .font(DesignSystem.Typography.label)
                    .tracking(1)
                    .textCase(.uppercase)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        } else {
            Button {
                gewichtKg = startwert
            } label: {
                HStack {
                    Text("Gewicht eintragen")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                .padding(.vertical, DesignSystem.Spacing.s16)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .frame(height: 58)
                .background(DesignSystem.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                        .stroke(DesignSystem.Color.line, lineWidth: 1)
                )
            }
            .buttonStyle(PressButtonStyle())
        }
    }
}

// MARK: - Schritt 3: Dein Ziel

/// 2×2 `Zielkachel`, ein zweiter Tipp waehlt ab.
struct ZielSchritt: View {
    @Binding var richtung: Trainingsrichtung?

    /// SF Symbols, wie im Brief benannt: arrow.down.right, dumbbell,
    /// waveform.path.ecg, arrow.up.right -- dieselbe Bildsprache wie
    /// gen.pys ICON_AB/ICON_MUSKEL/ICON_FIT/ICON_STARK.
    private func symbol(fuer richtung: Trainingsrichtung) -> String {
        switch richtung {
        case .abnehmen: "arrow.down.right"
        case .muskelnAufbauen: "dumbbell"
        case .fitBleiben: "waveform.path.ecg"
        case .staerkerWerden: "arrow.up.right"
        }
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: DesignSystem.Spacing.s8), GridItem(.flexible(), spacing: DesignSystem.Spacing.s8)],
            spacing: DesignSystem.Spacing.s8
        ) {
            ForEach(Trainingsrichtung.alle, id: \.self) { wert in
                let istGewaehlt = richtung == wert
                Zielkachel(symbol: symbol(fuer: wert), titel: wert.wort, zeile: wert.zeile, istGewaehlt: istGewaehlt) {
                    richtung = istGewaehlt ? nil : wert
                }
            }
        }
    }
}

// MARK: - Schritt 4: Wie oft?

/// Zahl 96 pt, zwei 58-pt-Knoepfe, 1–7. `tage` traegt bereits den
/// angezeigten Wert (Vorgabe oder Antwort) -- `OnboardingFlow` entscheidet,
/// wann daraus eine echte Antwort wird (R16).
struct WieOftSchritt: View {
    @Binding var tage: Int
    /// `false` im Ziel-Sheet: dort steht "Tage pro Woche" schon als Titel
    /// darueber, ein zweites Mal unter der Zahl waere dieselbe Zeile doppelt.
    var zeigtBeschriftung: Bool = true
    private let bereich = 1...7

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s24) {
            VStack(spacing: DesignSystem.Spacing.s4) {
                Text(String(tage))
                    .font(.system(size: 96, weight: .black).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.text)
                if zeigtBeschriftung {
                    Text("TAGE PRO WOCHE")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tage pro Woche")
            .accessibilityValue(voWert)
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: schieben(um: 1)
                case .decrement: schieben(um: -1)
                @unknown default: break
                }
            }

            HStack(spacing: DesignSystem.Spacing.s8) {
                knopf(systemName: "minus", aktiv: tage > bereich.lowerBound) { schieben(um: -1) }
                knopf(systemName: "plus", aktiv: tage < bereich.upperBound) { schieben(um: 1) }
            }

            // "Deaktiviert ist nie stumm" (designsystem.md SS5): am Anschlag
            // steht sichtbar, warum der Knopf nichts mehr tut.
            if let grenzhinweis {
                Text(grenzhinweis)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
    }

    private var grenzhinweis: String? {
        if tage <= bereich.lowerBound { return "Minimum 1 Tag erreicht" }
        if tage >= bereich.upperBound { return "Maximum 7 Tage erreicht" }
        return nil
    }

    private var voWert: String {
        guard let grenzhinweis else { return "\(tage)" }
        return "\(tage), \(grenzhinweis)"
    }

    private func schieben(um delta: Int) {
        tage = min(bereich.upperBound, max(bereich.lowerBound, tage + delta))
    }

    private func knopf(systemName: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(aktiv ? DesignSystem.Color.text : DesignSystem.Color.textFaint)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(DesignSystem.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!aktiv)
        // Die adjustable Aktion oben deckt VoiceOver bereits ab -- zwei
        // Wege zum selben Wert waeren zwei Ansagen fuer dieselbe Aktion.
        .accessibilityHidden(true)
    }
}

// MARK: - Schritt 5: Zielgewicht

/// `RastRad` startet beim eingegebenen Gewicht (Spec 5.2, letzte Zeile).
/// `gewichtKg` ist hier kein `Binding` mehr: Schritt 5 selbst aendert das
/// Gewicht aus Schritt 2 nie.
///
/// `gewichtKg` ist `Double?`, nicht `Double`: im Onboarding steht immer
/// eines da (Schritt 5 wird ohne Gewicht aus Schritt 2 uebersprungen,
/// Spec 5.2), aber `ZielSheet` (Aufgabe 10) reicht denselben Typ im
/// Profil durch, wo ein Zielgewicht auch OHNE je eingetragenes Gewicht
/// gesetzt werden darf -- die Kontextzeile faellt dann auf den Schritt
/// allein zurueck, statt eine Differenz zu einer Zahl zu erfinden, die
/// niemand eingetragen hat (SS5).
struct ZielgewichtSchritt: View {
    let gewichtKg: Double?
    @Binding var zielgewichtKg: Double

    private static let werte = Array(stride(from: 20.0, through: 400.0, by: 0.5))

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            RastRad(
                werte: Self.werte,
                auswahl: $zielgewichtKg,
                offen: true,
                unterstrich: .held,
                voLabel: "Zielgewicht",
                voWert: Zahlformat.gewichtGesprochen,
                anschlagText: nil,
                text: Zahlformat.gewicht
            )
            Text(kontextzeile)
                .font(DesignSystem.Typography.label)
                .tracking(1)
                .textCase(.uppercase)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }

    /// "noch 4,5 kg · Schritt 0,5 kg" -- eine Differenz eingetragener
    /// Zahlen, keine Bewertung (Spec Abschnitt 6). Ohne
    /// bekanntes aktuelles Gewicht nur der Schritt, statt eine Differenz
    /// zu einer erfundenen Null vorzutaeuschen.
    private var kontextzeile: String {
        guard let gewichtKg else { return "Schritt 0,5 kg" }
        return "noch \(Zahlformat.gewicht(abs(gewichtKg - zielgewichtKg))) kg · Schritt 0,5 kg"
    }
}
