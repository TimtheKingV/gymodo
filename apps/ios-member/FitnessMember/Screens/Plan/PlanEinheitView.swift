import SwiftUI

/// Vorschau einer Planeinheit aus dem Plan-Tab (Leinwand 2e): die Uebungen
/// aus `Trainingsplan.einheiten`, "Warum so?" und "Im Training öffnen".
///
/// Trainiert wird weiter im Training-Tab (E8): "Im Training öffnen" wechselt
/// dorthin, wo die Plankarte die Einheit fuehrt und die Stationen ueber
/// `PlanStart` die Uebung anbieten. Die Folge haengt nicht am Kalender (F5):
/// ist diese Einheit nicht die naechste, sagt der Screen das, statt eine
/// andere Einheit zu starten, als er zeigt.
struct PlanEinheitView: View {
    let einheitKey: String
    let beiTrainingStarten: () -> Void

    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @State private var warumOffen = false

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
        .testnotizScreen()
    }

    @Environment(VerlaufStore.self) private var verlauf
    @Environment(KurseStore.self) private var kurse

    /// Wie der Plan-Tab: Zeitzone der Kurswoche, sonst die des ersten Studios.
    private var kalender: Calendar {
        PlanKalenderKontext.kalender(zeitzone: PlanKalenderKontext.zeitzone(
            bootstrap: katalog.bootstrap, aktivesStudioId: katalog.activeStudioId, wochenZone: kurse.woche?.timezone))
    }

    /// Der Tag, auf dem die Folge diese Einheit als naechste liegt (heute oder
    /// spaeter); nil, wenn sie im Fenster nicht drankommt. Dieselbe Rechnung wie
    /// der Plan-Tab (`PlanKalenderKontext.termine`), ohne Kurse und Cardio.
    private func geplanterTag(
        plan: Trainingsplan, einheitKey: String, naechsteEinheitKey: String?, kalender: Calendar
    ) -> Date? {
        let jetzt = Date()
        let termine = PlanKalenderKontext.termine(
            plan: plan, tage: PlanKalenderKontext.fenster(heute: jetzt, kalender: kalender), kalender: kalender,
            profil: katalog.bootstrap?.member.trainingProfile, heuteEinheitKey: naechsteEinheitKey,
            sessions: verlauf.sessions, gesamt: verlauf.summary?.totalCount, verlaufGeladen: verlauf.stand != nil,
            heute: jetzt, kurse: [], cardioErledigt: [], filter: .einheiten)
        return PlanKalenderKontext.geplanterTag(
            einheitKey: einheitKey, termine: termine, heute: jetzt, kalender: kalender)
    }

    private func inhalt(plan: Trainingsplan, einheit: TrainingsplanEinheit) -> some View {
        let zeilen = PlanAnzeige.zeilen(plan: plan, einheitKey: einheit.key, zustand: nil,
                                        bloecke: [], bootstrap: katalog.bootstrap)
        let muskeln = HomeZeilen.muskelnJeUebung(katalog.bootstrap)
        let namen = EinheitNamen(plan: plan, muskeln: muskeln)
        let kalender = kalender
        let naechste = PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf)?.einheitKey
        let geplanterTag = geplanterTag(
            plan: plan, einheitKey: einheit.key, naechsteEinheitKey: naechste, kalender: kalender)
        let istGeplanterTag = PlanKalenderKontext.istGeplanterTag(
            geplanterTag, heute: Date(), kalender: kalender)
        let istNaechste = naechste == nil || naechste == einheit.key

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    ProfilKopf(
                        ueberzeile: geplanterTag.map {
                            ProfilKopf.ueberzeile(geplantAm: $0, kalender: kalender)
                        } ?? "EINHEIT",
                        modell: .einheit(
                            einheit, namen: namen, muskeln: muskeln, tag: nil, zustand: .geplant),
                        geschlecht: katalog.bootstrap?.member.sex.flatMap(Geschlecht.init(rawValue:)))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                        Text("\(zeilen.count) \(zeilen.count == 1 ? "ÜBUNG" : "ÜBUNGEN") · REIHENFOLGE EGAL")
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
                            message: "Dran ist gerade \(namen.name(naechste)). Der Plan folgt der Reihenfolge, nicht dem Wochentag.")
                    }
                }
                .padding(20)
            }

            VStack {
                if istNaechste {
                    PrimaryButton(title: ProfilKopf.startKnopfText(istGeplanterTag: istGeplanterTag)) {
                        beiTrainingStarten()
                    }
                        .accessibilityLabel(ProfilKopf.startKnopfText(istGeplanterTag: istGeplanterTag))
                        .accessibilityHint("Wechselt in den Tab Training, dort startet die Einheit")
                } else {
                    SecondaryButton(title: "Zum Training") { beiTrainingStarten() }
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
