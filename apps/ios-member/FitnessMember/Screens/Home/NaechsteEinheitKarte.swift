import SwiftUI

/// "NÄCHSTE EINHEIT" auf Home (Spec P2 §5): die Einheit, die der Plan als
/// naechste fuehrt (`naechsteEinheitKey`), ohne Tag. Tippen auf die Karte
/// oeffnet die Einheit im Home-Stack (E2); gestartet wird nur ueber den
/// eigenen Knopf darunter. "Training starten" gibt es immer -- die Woche hat
/// keine festen Tage mehr, jede Einheit darf heute dran sein.
struct NaechsteEinheitKarte: View {
    let modell: EinheitKarteModell
    /// Der Ablauf dieser Einheit laeuft schon: "Weiter trainieren".
    var laeuft = false
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
            EinheitKarte(
                modell: modell, geschlecht: geschlecht,
                beiTipp: beiTippen, hinweis: "Zeigt die Übungen der Einheit",
                aktion: (titel: Self.startText(laeuft: laeuft),
                         label: "\(modell.titel) \(laeuft ? "weiter trainieren" : "starten")",
                         hinweis: "Öffnet das Training", ausloesen: beiStart))
        }
        .testnotizElement("home.naechsteEinheit", typ: "Card")
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

    /// Immer "Training starten"; laeuft die Einheit, "Weiter trainieren".
    static func startText(laeuft: Bool) -> String {
        laeuft ? "Weiter trainieren" : "Training starten"
    }
}
