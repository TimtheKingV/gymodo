import SwiftUI

// Die Schritte 1.1-1.3 des Blocks "Dein Trainingsplan" (freigegebene
// Entwuerfe, Etappe 3). Die Huelle (Kopfzeile, Titel, Weiter, Später) ist
// `OnboardingScreen`; hier steht nur der Inhalt. Die Vorschau 1.4 mit den
// Sonderfaellen 4.1/4.2 steht in PlanVorschau.swift.

// MARK: - 1.1 Zeit und Erfahrung

struct PlanZeitSchritt: View {
    @Binding var minuten: Int?
    @Binding var erfahrung: String?
    /// "Muskeln aufbauen · 3 Tage pro Woche" -- Ziel und Tage kommen aus den
    /// Bestandsangaben und werden hier nur gezeigt (Entwurf: "keine Fragen").
    let angaben: String?
    let beiAendern: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            angabenZeile
            OnboardingAbschnitt(
                label: "Minuten pro Training",
                hinweis: "Wir planen so viele Übungen, wie in die Zeit passen. Die Pausen bleiben, wie sie sind."
            ) {
                HStack(spacing: DesignSystem.Spacing.s8) {
                    ForEach(PlanAuswahl.minuten, id: \.self) { wert in
                        let istAktiv = minuten == wert
                        Button {
                            minuten = istAktiv ? nil : wert
                        } label: {
                            Chip(text: "\(wert)", isActive: istAktiv, gefuellt: true)
                                .monospacedDigit()
                        }
                        .buttonStyle(PressButtonStyle())
                        .accessibilityLabel("\(wert) Minuten")
                        .accessibilityAddTraits(istAktiv ? [.isSelected] : [])
                    }
                }
            }
            OnboardingAbschnitt(label: "Erfahrung") {
                VStack(spacing: DesignSystem.Spacing.s8) {
                    ForEach(PlanAuswahl.erfahrungen, id: \.code) { stufe in
                        let istGewaehlt = erfahrung == stufe.code
                        Erfahrungskachel(titel: stufe.titel, zeile: stufe.zeile, istGewaehlt: istGewaehlt) {
                            erfahrung = istGewaehlt ? nil : stufe.code
                        }
                    }
                }
            }
        }
    }

    /// Entwurf 1.1: eine Zeile mit "Ändern", keine Frage. Fehlt beides,
    /// sagt die Zeile das, statt eine leere Karte zu zeigen.
    private var angabenZeile: some View {
        Button(action: beiAendern) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aus deinen Angaben")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                    Text(angaben ?? "Noch ohne Ziel und Trainingstage")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Color.text)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(angaben == nil ? "Ergänzen" : "Ändern")
                    .font(.system(size: 14))
                    .underline()
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, DesignSystem.Spacing.s12)
            .frame(minHeight: 44)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aus deinen Angaben: \(angaben ?? "noch ohne Ziel und Trainingstage")")
        .accessibilityHint(angaben == nil ? "Ziel und Trainingstage ergänzen" : "Ziel und Trainingstage ändern")
        .accessibilityAddTraits(.isButton)
    }
}

/// Eine Erfahrungsstufe (Entwurf `.tile`): gewaehlt = Akzentstrich, keine
/// Flaeche -- dieselbe Regel wie `Zielkachel`, die eine Akzentflaeche bleibt
/// "Weiter".
private struct Erfahrungskachel: View {
    let titel: String
    let zeile: String
    let istGewaehlt: Bool
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titel)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(zeile)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                    .stroke(istGewaehlt ? DesignSystem.Color.accent : DesignSystem.Color.line,
                            lineWidth: istGewaehlt ? 1.5 : 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel), \(zeile)")
        .accessibilityAddTraits(istGewaehlt ? [.isSelected] : [])
    }
}

// MARK: - 1.2 Schwerpunkt

/// Bis zu zwei Chips, gewaehlt = gefuellt. Ein drittes Tippen tut nichts
/// (Entwurf: "gesperrt, kein Fehlerton"); "Bis zu zwei." steht als Lead
/// darueber und erklaert es, VoiceOver bekommt denselben Satz als Hinweis.
struct PlanSchwerpunktSchritt: View {
    @Binding var plan: PlanAntworten

    var body: some View {
        Fliesslayout(abstand: DesignSystem.Spacing.s8) {
            ForEach(PlanAuswahl.schwerpunkte, id: \.code) { bereich in
                let istAktiv = plan.schwerpunkt.contains(bereich.code)
                let voll = plan.schwerpunkt.count >= 2
                Button {
                    plan.schwerpunktUmschalten(bereich.code)
                } label: {
                    Chip(text: bereich.text, isActive: istAktiv, innenabstand: DesignSystem.Spacing.s16, gefuellt: true)
                        .fixedSize()
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityAddTraits(istAktiv ? [.isSelected] : [])
                .accessibilityHint(voll && !istAktiv ? "Bis zu zwei. Erst einen anderen abwählen." : "")
            }
        }
    }
}

/// Zeilen, die umbrechen, sobald die Breite voll ist (Entwurf `.chips`,
/// flex-wrap) -- ein festes Raster liesse kurze Woerter wie "Po" in einer
/// zu breiten Spalte stehen.
struct Fliesslayout: Layout {
    var abstand: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let breite = proposal.width ?? .infinity
        let zeilen = zeilen(subviews: subviews, breite: breite)
        let hoehe = zeilen.map(\.hoehe).reduce(0, +) + abstand * CGFloat(max(zeilen.count - 1, 0))
        let genutzt = zeilen.map(\.breite).max() ?? 0
        return CGSize(width: proposal.width ?? genutzt, height: hoehe)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for zeile in zeilen(subviews: subviews, breite: bounds.width) {
            var x = bounds.minX
            for index in zeile.indizes {
                let groesse = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(groesse))
                x += groesse.width + abstand
            }
            y += zeile.hoehe + abstand
        }
    }

    private struct Zeile {
        var indizes: [Int] = []
        var breite: CGFloat = 0
        var hoehe: CGFloat = 0
    }

    private func zeilen(subviews: Subviews, breite: CGFloat) -> [Zeile] {
        var zeilen: [Zeile] = []
        var aktuell = Zeile()
        for index in subviews.indices {
            let groesse = subviews[index].sizeThatFits(.unspecified)
            let neueBreite = aktuell.indizes.isEmpty ? groesse.width : aktuell.breite + abstand + groesse.width
            if neueBreite > breite, !aktuell.indizes.isEmpty {
                zeilen.append(aktuell)
                aktuell = Zeile(indizes: [index], breite: groesse.width, hoehe: groesse.height)
            } else {
                aktuell.indizes.append(index)
                aktuell.breite = neueBreite
                aktuell.hoehe = max(aktuell.hoehe, groesse.height)
            }
        }
        if !aktuell.indizes.isEmpty { zeilen.append(aktuell) }
        return zeilen
    }
}

// MARK: - 1.3 Beschwerden

/// Je Bereich "Nichts · Vorsichtig · Meiden", darunter die getrennte
/// Einwilligung und der Hinweis in `warn` als Umriss (nie Flaeche).
/// Gesundheitsdaten (DSGVO Art. 9): nichts davon wird geloggt; ob es
/// gesendet wird, entscheidet `PlanAntworten.beschwerdenAktion`.
struct PlanBeschwerdenSchritt: View {
    @Binding var plan: PlanAntworten

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            ForEach(PlanAuswahl.bereiche, id: \.code) { bereich in
                bereichsZeile(code: bereich.code, name: bereich.text)
            }
            einwilligung
                .padding(.top, DesignSystem.Spacing.s8)
            Text("Akute oder unklare Schmerzen bitte ärztlich abklären lassen.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignSystem.Spacing.s12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                        .stroke(DesignSystem.Color.warn, lineWidth: 1)
                )
        }
    }

    private func bereichsZeile(code: String, name: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                ForEach(Array(PlanAuswahl.stufen.enumerated()), id: \.element.code) { index, stufe in
                    let istAktiv = plan.stufe(fuer: code) == stufe.code
                    if index > 0 {
                        Rectangle().fill(DesignSystem.Color.line).frame(width: 1)
                    }
                    Button {
                        plan.setzeStufe(stufe.code, fuer: code)
                    } label: {
                        Text(stufe.text)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(istAktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.textFaint)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(istAktiv ? DesignSystem.Color.text : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel("\(name): \(stufe.text)")
                    .accessibilityAddTraits(istAktiv ? [.isSelected] : [])
                }
            }
            .fixedSize()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }

    /// Haken in Akzent als Strich (nie Flaeche). Getrennt von jeder anderen
    /// Aktion: erst mit Haken gehen Beschwerden raus.
    private var einwilligung: some View {
        Button {
            plan.einwilligung.toggle()
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(plan.einwilligung ? DesignSystem.Color.accent : DesignSystem.Color.textFaint, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if plan.einwilligung {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(DesignSystem.Color.accent)
                        }
                    }
                Text(Self.einwilligungsText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.einwilligungsText)
        .accessibilityValue(plan.einwilligung ? "eingewilligt" : "nicht eingewilligt")
        .accessibilityAddTraits(.isToggle)
    }

    static let einwilligungsText = "Ich willige ausdrücklich ein, dass meine Angaben zu Beschwerden gespeichert werden, um meinen Plan anzupassen. Widerruf jederzeit im Profil."
}

#Preview("1.1 Zeit und Erfahrung") {
    @Previewable @State var minuten: Int? = 60
    @Previewable @State var erfahrung: String? = "regelmaessig"
    OnboardingScreen(
        schrittNummer: 1, gesamtSchritte: 4, titel: "Zeit und Erfahrung", lead: nil, fussnote: nil,
        primaryTitle: "Weiter", primaryEnabled: true, primaryLoading: false, primaryDisabledHint: nil,
        bereich: "Dein Trainingsplan", beiSpaeter: {}, beiWeiter: {}
    ) {
        PlanZeitSchritt(minuten: $minuten, erfahrung: $erfahrung, angaben: "Muskeln aufbauen · 3 Tage pro Woche") {}
    }
}

#Preview("1.2 Schwerpunkt") {
    @Previewable @State var plan: PlanAntworten = {
        var plan = PlanAntworten(profil: nil)
        plan.schwerpunktUmschalten("po")
        return plan
    }()
    OnboardingScreen(
        schrittNummer: 2, gesamtSchritte: 4, titel: "Wo soll mehr passieren?", lead: "Bis zu zwei.", fussnote: nil,
        primaryTitle: "Weiter", primaryEnabled: true, primaryLoading: false, primaryDisabledHint: nil,
        bereich: "Dein Trainingsplan", beiSpaeter: {}, beiWeiter: {}
    ) {
        PlanSchwerpunktSchritt(plan: $plan)
    }
}

#Preview("1.3 Beschwerden") {
    @Previewable @State var plan: PlanAntworten = {
        var plan = PlanAntworten(profil: nil)
        plan.setzeStufe("vorsichtig", fuer: "knie")
        plan.einwilligung = true
        return plan
    }()
    OnboardingScreen(
        schrittNummer: 3, gesamtSchritte: 4, titel: "Was sollen wir schonen?",
        lead: "Freiwillig. Wir lassen dann Übungen weg, die den Bereich stark belasten, oder wählen schonendere.",
        fussnote: nil, primaryTitle: "Weiter", primaryEnabled: plan.kannWeiter(.planBeschwerden),
        primaryLoading: false, primaryDisabledHint: "Erst die Einwilligung bestätigen — oder überspringen.",
        bereich: "Dein Trainingsplan", spaeterTitel: "Überspringen", beiSpaeter: {}, beiWeiter: {}
    ) {
        PlanBeschwerdenSchritt(plan: $plan)
    }
}
