import SwiftUI

/// Der Plan im Abschluss-Screen (Entwurf 2.3): was von der Einheit
/// erledigt ist, welche als naechste dran ist, und -- einmal je Plan -- das
/// Anfaengerangebot.
///
/// Liest den eben beendeten Ablauf (`zuletztBeendeterLauf`), denn
/// `beenden()` hat den laufenden schon geleert, bevor dieser Screen
/// erscheint. Ohne Plan in dieser Einheit (Freies Training, kein Plan,
/// kein Satz) steht hier nichts.
struct PlanAbschlussBereich: View {
    let sessionId: UUID
    let apiClient: APIClient

    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf

    /// Gesetzt, sobald die Karte erscheint, und dann sofort gemerkt:
    /// "erscheint einmal" (Entwurf 2.3), auch wenn das Mitglied nur "Fertig"
    /// tippt. "Später" blendet sie aus; gemerkt ist sie dann schon.
    @State private var angebotPlan: Trainingsplan?
    @State private var neuerPlanOffen = false

    var body: some View {
        // Ohne Planablauf gar keine View: ein leerer Stapel bekaeme im
        // Abschluss trotzdem seinen Abstand.
        if let lauf = planAblauf.zuletztBeendeterLauf, lauf.gebundeneSessionId == sessionId {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                einheitKarte(lauf)
                if let angebotPlan {
                    angebotKarte(angebotPlan)
                }
            }
            .onAppear { angebotPruefen(lauf) }
            // Der Abschluss laedt nach completeSession den Bootstrap neu;
            // erst der kennt die achte Einheit und setzt anfaengerUebergang.
            .onChange(of: katalog.bootstrapStand) { angebotPruefen(lauf) }
            .sheet(isPresented: $neuerPlanOffen) {
                // 1.4 mit neuem Vorschlag: der Flow erzeugt ihn, uebernimmt ihn
                // auf Wunsch und laedt danach selbst den Bootstrap (F14: nie
                // still umgeschrieben).
                OnboardingFlow(apiClient: apiClient, alsSheet: true, umfang: .nurVorschau) {
                    neuerPlanOffen = false
                    angebotPlan = nil
                }
            }
        }
    }

    /// Das Angebot gilt dem Plan dieser Einheit.
    private func angebotPruefen(_ lauf: PlanLauf) {
        guard angebotPlan == nil else { return }
        let plan = katalog.bootstrap?.member.plans.first { $0.planId == lauf.planId }
        guard let neu = PlanAnzeige.anfaengerAngebotNachPruefung(
            bisher: nil, plan: plan, gesehen: PlanAnzeige.gesehneAnfaengerAngebote()) else { return }
        angebotPlan = neu
        PlanAnzeige.anfaengerAngebotGesehen(planId: neu.planId)
    }

    private func einheitKarte(_ lauf: PlanLauf) -> some View {
        let abschluss = PlanAnzeige.abschluss(einheitKey: lauf.einheitKey, zustand: lauf.zustand,
                                              naechsteEinheitKey: planAblauf.naechsteEinheitKey)
        return Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(abschluss.titel)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(abschluss.zeile)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                if let naechstes = abschluss.naechstes {
                    Text(naechstes)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.s16)
        }
        .accessibilityElement(children: .combine)
    }

    private func angebotKarte(_ plan: Trainingsplan) -> some View {
        let texte = PlanAnzeige.anfaengerTexte(plan)
        return Card {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                Text(texte.label)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text("Zeit, den Plan anzupassen?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .accessibilityAddTraits(.isHeader)
                Text(texte.text)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                // Umriss, keine Flaeche: die Akzentflaeche des Screens ist
                // "Fertig".
                SecondaryButton(title: "Neuen Plan ansehen") { neuerPlanOffen = true }
                    .accessibilityHint("Zeigt einen neuen Planvorschlag. Du entscheidest, ob du ihn übernimmst.")
                Button { angebotPlan = nil } label: {
                    Text("Später")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressButtonStyle())
            }
            .padding(DesignSystem.Spacing.s16)
        }
    }
}
