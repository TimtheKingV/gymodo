import SwiftUI

/// Vorschau einer Planeinheit aus dem Plan-Tab (Leinwand 2e): die Uebungen
/// aus `Trainingsplan.einheiten`, "Warum so?" und "Im Training öffnen".
///
/// Trainiert wird weiter im Training-Tab (E8): "Im Training öffnen" wechselt
/// dorthin, wo die Plankarte die Einheit fuehrt und die Stationen ueber
/// `PlanStart` die Uebung anbieten. Die Folge haengt nicht am Kalender (F5):
/// ist diese Einheit nicht die naechste, sagt der Screen das, statt eine
/// andere Einheit zu starten, als er zeigt. Einen geplanten Tag gibt es
/// nicht mehr (Spec P2): gestartet wird nur die naechste Einheit.
struct PlanEinheitView: View {
    let einheitKey: String
    let apiClient: APIClient
    let beiTrainingStarten: () -> Void
    /// "Zum Training" bei einer Einheit, die nicht dran ist: fuehrt in die
    /// Auswahl statt in den Plan. nil = derselbe Weg wie `beiTrainingStarten`.
    var beiZumTraining: (() -> Void)? = nil

    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @State private var warumOffen = false
    @State private var bearbeitenOffen = false

    /// E7: nicht, solange an genau dieser Einheit eine Session haengt.
    private var darfBearbeiten: Bool {
        PlanEinheitBearbeitung.darfBearbeiten(
            einheitKey: einheitKey, laufEinheitKey: planAblauf.einheitKey,
            gebunden: planAblauf.gebundeneSessionId != nil)
    }

    private var plan: Trainingsplan? { PlanAnzeige.plan(bootstrap: katalog.bootstrap) }

    var body: some View {
        Group {
            if let plan, let einheit = plan.einheiten.first(where: { $0.key == einheitKey }) {
                inhalt(plan: plan, einheit: einheit)
            } else {
                // Der Plan hat sich unter der offenen Ansicht geaendert.
                Text("Diese Einheit gibt es in deinem Plan nicht mehr.")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(DesignSystem.Color.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if darfBearbeiten, plan?.einheiten.contains(where: { $0.key == einheitKey }) == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bearbeiten") { bearbeitenOffen = true }
                        .foregroundStyle(DesignSystem.Color.text)
                        .testnotizElement("einheit.bearbeiten", typ: "Button")
                }
            }
        }
        .fullScreenCover(isPresented: $bearbeitenOffen) {
            if let einheit = plan?.einheiten.first(where: { $0.key == einheitKey }) {
                PlanEinheitBearbeitenView(einheit: einheit, apiClient: apiClient) { bearbeitenOffen = false }
                    .environment(katalog)
                    .environment(planAblauf)
                    .environment(videoVorrat)
            } else {
                // Die Einheit ist weg (neuer Plan): nie ein leeres Cover ohne Ausweg.
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    Text("Diese Einheit gibt es in deinem Plan nicht mehr.")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Schließen") { bearbeitenOffen = false }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.accent)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DesignSystem.Color.bg)
            }
        }
        .testnotizScreen()
    }

    /// Fuer das Bearbeiten-Cover (Videos der Ersatz-Kandidaten).
    @Environment(UebungsVideoVorrat.self) private var videoVorrat

    private func inhalt(plan: Trainingsplan, einheit: TrainingsplanEinheit) -> some View {
        let zeilen = PlanAnzeige.zeilen(plan: plan, einheitKey: einheit.key, zustand: nil,
                                        bloecke: [], bootstrap: katalog.bootstrap)
        let muskeln = HomeZeilen.muskelnJeUebung(katalog.bootstrap)
        let namen = EinheitNamen(plan: plan, muskeln: muskeln)
        let naechste = PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf)?.einheitKey
        let istNaechste = naechste == nil || naechste == einheit.key

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    ProfilKopf(
                        ueberzeile: "EINHEIT",
                        modell: .einheit(
                            einheit, namen: namen, muskeln: muskeln, tag: nil, zustand: .geplant),
                        geschlecht: katalog.bootstrap?.member.sex.flatMap(Geschlecht.init(rawValue:)))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                        Text("\(zeilen.count) \(zeilen.count == 1 ? "ÜBUNG" : "ÜBUNGEN") · IN DIESER REIHENFOLGE")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        VStack(spacing: 0) {
                            ForEach(Array(zeilen.enumerated()), id: \.element.id) { nummer, zeile in
                                if nummer > 0 { Divider().overlay(DesignSystem.Color.line) }
                                HStack(spacing: DesignSystem.Spacing.s12) {
                                    Text("\(nummer + 1)")
                                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                                        .foregroundStyle(DesignSystem.Color.textMuted)
                                        .frame(width: 20, alignment: .leading)
                                    Text(zeile.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DesignSystem.Color.text)
                                    Spacer(minLength: DesignSystem.Spacing.s8)
                                    Text(zeile.untertitel)
                                        .font(.system(size: 13).monospacedDigit())
                                        .foregroundStyle(DesignSystem.Color.textMuted)
                                }
                                .padding(.horizontal, DesignSystem.Spacing.s16)
                                .frame(minHeight: 48)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .background(DesignSystem.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                    }

                    Button { warumOffen = true } label: {
                        HStack {
                            Text("Warum diese Einheit so aussieht")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DesignSystem.Color.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignSystem.Color.textMuted)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .frame(minHeight: 52)
                        .background(DesignSystem.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressButtonStyle())

                    if !istNaechste, let naechste {
                        InlineBanner(
                            tone: .muted,
                            message: "Dran ist gerade \(namen.zitiert(naechste)). Der Plan folgt der Reihenfolge, nicht dem Wochentag.")
                    }
                }
                .padding(20)
            }

            VStack {
                if istNaechste {
                    PrimaryButton(title: "Training starten") {
                        beiTrainingStarten()
                    }
                        .accessibilityLabel("Training starten")
                        .accessibilityHint("Wechselt in den Tab Training und startet die Einheit")
                } else {
                    SecondaryButton(title: "Zum Training") { (beiZumTraining ?? beiTrainingStarten)() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s12)
            .background(DesignSystem.Color.bg)
        }
        .sheet(isPresented: $warumOffen) {
            PlanWarumView(struktur: plan.struktur, gruende: plan.gruende)
        }
    }
}
