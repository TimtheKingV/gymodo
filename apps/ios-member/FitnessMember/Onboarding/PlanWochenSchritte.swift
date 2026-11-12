import SwiftUI

// Die Schritte "Machst du auch Cardio außerhalb?" (Leinwand 2c2) und "Deine
// Woche" (2c3). Die Huelle (Kopfzeile, Titel, Weiter, Ueberspringen) ist wie
// bei 1.1-1.3 `OnboardingScreen`; hier steht nur der Inhalt.
//
// Beide fragen, wie oft -- nicht wann (Spec P2 §4): kein Tag wird gewaehlt, und
// nichts wird getauscht. Kurse fragt der Flow nicht; sie zaehlen nach Buchung.

/// Die Texte des Wochenblocks -- rein, damit sie ohne UI pruefbar bleiben.
enum PlanWochenText {
    static let kurzname = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    static let vollname = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    static func kurz(_ tag: Int) -> String { kurzname[(tag - 1) % 7] }
    static func voll(_ tag: Int) -> String { vollname[(tag - 1) % 7] }

    /// Lead von 2c3: die Woche als Zaehler, nicht als Tage.
    static let wochenLead = "So viel pro Woche nimmst du dir vor. Kurse zählen, sobald du sie buchst."

    /// VoiceOver fuer die Cardio-Arten (Chips als Schalter).
    static func artLabel(_ name: String, ausgewaehlt: Bool) -> String {
        "\(name), \(ausgewaehlt ? "ausgewählt" : "nicht ausgewählt")"
    }
}

// MARK: - 2c2 Cardio

/// Wie oft Cardio, wie lange, was: dieselben Zaehler wie in "Woche anpassen".
/// Minuten und Arten erscheinen erst ab einmal Cardio.
struct PlanCardioSchritt: View {
    @Binding var plan: PlanAntworten

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            WochenZaehler("Cardio", wert: $plan.woche.cardio, grenzen: WochenAuswahl.cardioGrenzen,
                          einheit: { $0 == 0 ? "kein Cardio" : "\($0)× pro Woche" })
            if plan.woche.cardio >= 1 {
                WochenZaehler("Minuten je Cardio", wert: $plan.woche.cardioMinuten,
                              grenzen: WochenAuswahl.minutenGrenzen, schritt: WochenAuswahl.minutenSchritt,
                              einheit: { "\($0) min" })
                OnboardingAbschnitt(label: "Was machst du?") {
                    Fliesslayout(abstand: DesignSystem.Spacing.s8) {
                        ForEach(PlanAuswahl.cardioArten, id: \.code) { art in
                            let istAktiv = plan.woche.cardioArten.contains(art.code)
                            Button {
                                plan.cardioArtUmschalten(art.code)
                            } label: {
                                Chip(text: art.text, isActive: istAktiv, innenabstand: DesignSystem.Spacing.s16, gefuellt: true)
                                    .fixedSize()
                            }
                            .buttonStyle(PressButtonStyle())
                            .accessibilityLabel(PlanWochenText.artLabel(art.text, ausgewaehlt: istAktiv))
                            .accessibilityAddTraits(istAktiv ? [.isToggle, .isSelected] : .isToggle)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 2c3 Deine Woche

/// Kraft pro Woche und die Zusammenfassung der Woche. Es gibt hier keinen
/// Netzaufruf: die Zaehler gehen mit dem Profil raus, sobald es geschrieben
/// wird (vor der Vorschau).
struct PlanWochenSchritt: View {
    @Binding var plan: PlanAntworten

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            WochenZaehler("Kraft", wert: $plan.woche.kraft, grenzen: WochenAuswahl.kraftGrenzen,
                          einheit: { "\($0)× pro Woche" })
            Text(plan.zusammenfassung)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .padding(.vertical, 14)
                .background(DesignSystem.Color.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
                .accessibilityElement(children: .combine)
            Text(WochenAuswahl.hinweis)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Die Woche in einer Zeile fuer die Vorschau 1.4: Tag und Marke, wie der
/// Server das Raster vorschlaegt.
struct PlanWochenZeile: View {
    let raster: [Rasterplatz]
    let namen: EinheitNamen

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(1...7, id: \.self) { tag in
                let platz = raster.first { $0.tag == tag }
                VStack(spacing: DesignSystem.Spacing.s4) {
                    Text(PlanWochenText.kurz(tag))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    marke(platz)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(platz?.art == .kraft ? DesignSystem.Color.onAccent : DesignSystem.Color.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(platz?.art == .kraft ? DesignSystem.Color.accent : DesignSystem.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(PlanWochenText.voll(tag)), \(beschreibung(platz))")
            }
        }
    }

    /// Kraft neutral (Hantel) wie auf Home: die Einheit hat keinen Buchstaben mehr.
    @ViewBuilder
    private func marke(_ platz: Rasterplatz?) -> some View {
        if let platz {
            switch platz.art {
            case .kraft: Image(systemName: "dumbbell.fill")
            case .kurs: Text("Kurs")
            case .cardio: Text("Cardio")
            }
        } else {
            Text("–")
        }
    }

    private func beschreibung(_ platz: Rasterplatz?) -> String {
        guard let platz else { return "frei" }
        switch platz.art {
        case .kraft: return platz.einheitKey.map(namen.name) ?? "Krafttraining"
        case .kurs: return "Kurs"
        case .cardio: return "Cardio"
        }
    }
}
