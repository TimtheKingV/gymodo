import SwiftUI

/// "NÄCHSTE EINHEIT" auf Home (Spec 1.1): der naechste Termin des Plans mit
/// Name und Tag. Ersetzt "Heute dran" und "Als nächstes". Eine Einheit steht
/// als `EinheitKarte`, ein Kurs oder Cardio als die kurze Zeile des Plan-Tabs
/// (`PlanTerminZeile`). Tippen auf die Einheit oeffnet sie im Home-Stack (E2),
/// Kurs und Cardio fuehren in den Plan-Tab; "Training starten" gibt es nur am
/// geplanten Tag -- Vorziehen geht ueber die Einheit oder den Training-Tab.
struct NaechsteEinheitKarte: View {
    let termin: (tag: Date, termin: PlanTermin)
    /// Fuer eine Einheit; nil bei Kurs und Cardio.
    let modell: EinheitKarteModell?
    let istHeute: Bool
    /// Der Ablauf dieser Einheit laeuft schon: "Weiter trainieren".
    var laeuft = false
    let kalender: Calendar
    let geschlecht: Geschlecht?
    let beiTippen: () -> Void
    let beiStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("NÄCHSTE EINHEIT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            inhalt
        }
        .testnotizElement("home.naechsteEinheit", typ: "Card")
    }

    @ViewBuilder
    private var inhalt: some View {
        let tag = istHeute ? "Heute" : PlanRootView.tagKurz(termin.tag, kalender: kalender)
        switch termin.termin {
        case .einheit:
            if let modell {
                EinheitKarte(
                    modell: modell, geschlecht: geschlecht, kalender: kalender,
                    beiTipp: beiTippen, hinweis: "Zeigt die Übungen der Einheit",
                    aktion: istHeute
                        ? (titel: laeuft ? "Weiter trainieren" : "Training starten",
                           label: "\(modell.titel) \(laeuft ? "weiter trainieren" : "starten")",
                           hinweis: "Öffnet das Training", ausloesen: beiStart)
                        : nil)
            }
        case .kurs(let titel, _, _, _):
            Button(action: beiTippen) {
                PlanTerminZeile(kaestchen: AnyView(PlanKursKaestchen()), titel: titel, tag: tag)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("Öffnet den Tag im Plan")
        case .cardio:
            Button(action: beiTippen) {
                PlanTerminZeile(kaestchen: AnyView(PlanCardioKaestchen()), titel: "Cardio-Einheit", tag: tag)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("Öffnet den Tag im Plan")
        }
    }

    // MARK: - Ableitungen

    /// Laeuft die Einheit von heute wirklich? Nur ein an eine Session
    /// gebundener Ablauf zaehlt: `TrainingsplanAblaufStore.vorbereiten` legt
    /// fuer jeden Plan einen ungebundenen Ablauf an, dessen Zustand schon vor
    /// dem ersten Satz gesetzt ist -- der allein ist kein laufendes Training.
    static func laufend(_ heute: PlanAnzeige.Heute?, gebunden: Bool) -> PlanAnzeige.Heute? {
        guard gebunden, let heute, heute.zustand != nil else { return nil }
        return heute
    }

    /// Laeuft eine Einheit, ist sie die naechste -- heute, auch an einem Tag
    /// ohne Slot. Sonst der erste geplante Termin ab heute (`PlanKalender.naechster`).
    static func auswahl(
        termine: [Date: [PlanTermin]], laufendeEinheitKey: String?, jetzt: Date, kalender: Calendar
    ) -> (tag: Date, termin: PlanTermin)? {
        if let laufendeEinheitKey {
            return (tag: kalender.startOfDay(for: jetzt), termin: .einheit(key: laufendeEinheitKey, zustand: .geplant))
        }
        return PlanKalender.naechster(termine, ab: jetzt, kalender: kalender)
    }

    /// "Heute" oder "Freitag, 6. Nov" -- wie "Als nächstes" im Plan-Tab.
    static func tagText(_ tag: Date, jetzt: Date, kalender: Calendar) -> String {
        kalender.isDate(tag, inSameDayAs: jetzt) ? "Heute" : PlanRootView.tagKurz(tag, kalender: kalender)
    }
}

/// Statt der naechsten Einheit, solange der Plan keine Trainingstage hat
/// (Bestandsplan von vor 1.3.0, I3). Fuehrt in den Plan-Tab, wo "Einplanen"
/// sie festlegt.
struct TrainingstageFestlegenZeile: View {
    let beiTippen: () -> Void

    var body: some View {
        Button(action: beiTippen) {
            Card {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DIESE WOCHE")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        Text("Trainingstage festlegen")
                            .font(DesignSystem.Typography.uebungsname)
                            .foregroundStyle(DesignSystem.Color.text)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trainingstage festlegen")
        .accessibilityHint("Öffnet den Plan")
        .accessibilityAddTraits(.isButton)
        .testnotizElement("home.trainingstage", typ: "Button")
    }
}
