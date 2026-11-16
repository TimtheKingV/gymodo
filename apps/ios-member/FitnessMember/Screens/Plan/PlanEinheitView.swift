import SwiftUI
import UIKit

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
    @State private var vorschauLader = VorschauLader(ablage: .fotos)
    @State private var fotos: [String: URL] = [:]
    @State private var bilder: [String: UIImage] = [:]

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
        .task { fotos = await GeraeteFotos.laden(von: apiClient) }
        .testnotizScreen()
    }

    private func fotoLaden(modell: String?) async {
        guard let modell, let url = fotos[modell], bilder[modell] == nil else { return }
        // 56 pt bei 3x, wie die Geraeteliste (P4, Testnotiz 10.11. #7).
        bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
    }

    /// Fuer das Bearbeiten-Cover (Videos der Ersatz-Kandidaten).
    @Environment(UebungsVideoVorrat.self) private var videoVorrat

    private func inhalt(plan: Trainingsplan, einheit: TrainingsplanEinheit) -> some View {
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
                        Text("\(einheit.positionen.count) \(einheit.positionen.count == 1 ? "ÜBUNG" : "ÜBUNGEN") · IN DIESER REIHENFOLGE")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        VStack(spacing: 10) {
                            ForEach(einheit.positionen, id: \.key) { position in
                                let modell = UebungskarteModell.aus(position, bootstrap: katalog.bootstrap)
                                Uebungskarte(modell: modell, foto: modell.vorschaubildModell.flatMap { bilder[$0] })
                                    .task(id: modell.vorschaubildModell.flatMap { fotos[$0] }) {
                                        await fotoLaden(modell: modell.vorschaubildModell)
                                    }
                            }
                        }
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
