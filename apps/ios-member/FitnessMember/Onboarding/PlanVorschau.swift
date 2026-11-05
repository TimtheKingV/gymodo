import SwiftUI
import UIKit

/// Schritt 1.4 "Dein Plan" mit den Sonderfaellen 4.1 (Plan nicht moeglich)
/// und 4.2 (Angaben fehlen).
///
/// Der Server erzeugt den Vorschlag beim Betreten (`createPlan`), "Plan
/// übernehmen" ruft `acceptPlan`. Kein Plan erscheint als gespeichert,
/// bevor er uebernommen ist: wer zurueckgeht, verwirft nichts -- der
/// naechste Vorschlag ersetzt diesen auf dem Server (Entwurf 1.4).
///
/// Ein eigener View statt eines Zweigs in `OnboardingFlow`: der Schritt hat
/// einen eigenen Ladezustand, der mit jedem Betreten neu beginnt -- jeder
/// Push ist eine neue Identitaet und damit ein neuer Vorschlag.
struct PlanVorschauSchritt: View {
    let apiClient: APIClient
    let studioId: String?
    let schrittNummer: Int
    let gesamtSchritte: Int
    /// Die Bereiche aus diesem Flow, nur fuer den Satz in 4.1.
    let beschwerden: [String: String]
    /// Nach gelungener Uebernahme; der Flow laedt den Bootstrap neu und
    /// schliesst.
    let beiUebernommen: () async -> Void
    let beiSpaeter: () async -> Void
    let beiZeitOderSchwerpunkt: () -> Void
    let beiSonderfall: (PlanSonderfall.Aktion) -> Void
    /// Nur Vorschau und Sichtpruefung: ein fester Zustand statt des
    /// Vorschlags vom Server (kein Netzaufruf).
    var start: Zustand? = nil

    @Environment(CatalogStore.self) private var katalog
    @Environment(UebungsVideoVorrat.self) private var videos

    enum Zustand: Equatable {
        case laedt
        case vorschlag(Trainingsplan)
        /// Banner mit "Erneut versuchen". Mit Plan: die Uebernahme scheiterte,
        /// der Vorschlag bleibt sichtbar; ohne: schon der Vorschlag.
        case fehler(text: String, plan: Trainingsplan?)
        case sonderfall(PlanSonderfall)
    }

    @State private var zustand: Zustand = .laedt
    @State private var einheitKey: String?
    @State private var uebernimmt = false
    @State private var fotos: [String: URL] = [:]
    @State private var bilder: [String: UIImage] = [:]
    /// Je Schritt ein eigener Lader: der Vorschlag zeigt eine Handvoll
    /// Zeilen; die Fotoablage auf der Platte teilt er mit der Geraeteliste.
    @State private var vorschauLader = VorschauLader(ablage: .fotos)

    var body: some View {
        // ZStack statt Group: Modifier an einer Group landen an jedem Kind
        // einzeln -- der Wechsel in den Sonderfall startete sonst `.task`
        // neu und holte einen neuen Vorschlag, endlos.
        ZStack {
            if case .sonderfall(let fall) = zustand {
                PlanSonderfallAnsicht(fall: fall, beiAktion: beiSonderfall) {
                    Task { await beiSpaeter() }
                }
            } else {
                vorschauScreen
            }
        }
        .task {
            if let start {
                zustand = start
                if case .vorschlag(let plan) = start { einheitKey = plan.einheiten.first?.key }
                return
            }
            await vorschlagHolen()
        }
        .task {
            // Nebeneinander wie in der Geraeteliste; ein fehlendes Foto ist
            // kein Zustand, den das Mitglied erklaert bekommen muss.
            async let geladeneFotos = GeraeteFotos.laden(von: apiClient)
            await videos.laden(von: apiClient)
            fotos = await geladeneFotos
        }
    }

    private var plan: Trainingsplan? {
        switch zustand {
        case .vorschlag(let plan): plan
        case .fehler(_, let plan): plan
        case .laedt, .sonderfall: nil
        }
    }

    private var vorschauScreen: some View {
        OnboardingScreen(
            schrittNummer: schrittNummer,
            gesamtSchritte: gesamtSchritte,
            titel: "Dein Plan",
            lead: plan.map { PlanStrukturText.text($0.struktur) }
                ?? "Wir stellen deinen Plan aus den Geräten deines Studios zusammen.",
            fussnote: nil,
            primaryTitle: primaryTitel,
            primaryEnabled: primaryAktiv,
            primaryLoading: zustand == .laedt || uebernimmt,
            primaryDisabledHint: nil,
            spaeterEnabled: !uebernimmt,
            bereich: "Dein Trainingsplan",
            nebenaktion: (titel: "Zeit oder Schwerpunkt ändern", aktion: beiZeitOderSchwerpunkt),
            beiSpaeter: { Task { await beiSpaeter() } },
            beiWeiter: { await primaryAktion() }
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                if case .fehler(let text, _) = zustand {
                    InlineBanner(tone: .danger, message: text)
                }
                if let plan {
                    planInhalt(plan)
                } else if zustand == .laedt {
                    ProgressView()
                        .tint(DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .accessibilityLabel("Plan wird erstellt")
                }
            }
        }
    }

    private var primaryTitel: String {
        if case .fehler = zustand { return "Erneut versuchen" }
        return "Plan übernehmen"
    }

    /// Waehrend des Ladens zeigt der Knopf den Lauf (isLoading), danach ist
    /// er immer ausloesbar -- es gibt keinen stummen deaktivierten Zustand.
    private var primaryAktiv: Bool { zustand != .laedt && !uebernimmt }

    @ViewBuilder
    private func planInhalt(_ plan: Trainingsplan) -> some View {
        let einheit = plan.einheiten.first { $0.key == einheitKey } ?? plan.einheiten.first
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            // Das Raster dieses Vorschlags, wie der Server es legt (nach einem
            // Tausch in "Deine Woche" mit dessen Krafttagen). Fehlt es (alte
            // Server-Antwort), fehlt die Zeile.
            if !plan.wochenraster.isEmpty {
                OnboardingAbschnitt(label: "Deine Woche") {
                    PlanWochenZeile(raster: plan.wochenraster)
                }
                .padding(.bottom, DesignSystem.Spacing.s4)
            }
            if plan.einheiten.count > 1 {
                einheitenTabs(plan)
            }
            if let einheit {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(einheit.positionen.enumerated()), id: \.element.key) { index, position in
                            let zeile = PlanZeilenModell.aus(position, bootstrap: katalog.bootstrap)
                            if index > 0 {
                                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                            }
                            PlanZeile(modell: zeile, foto: zeile.vorschaubildModell.flatMap { bilder[$0] })
                                .task(id: zeile.vorschaubildModell.flatMap { fotos[$0] }) {
                                    await fotoLaden(modell: zeile.vorschaubildModell)
                                }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, DesignSystem.Spacing.s4)
                }
                Text(PlanAnzeige.metaText(einheit))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }

    /// Entwurf 1.4 `.tabs`: gewaehlt = gefuellt. Scrollt, weil Ober-/
    /// Unterkoerper vier lange Namen hat.
    private func einheitenTabs(_ plan: Trainingsplan) -> some View {
        let gewaehlt = einheitKey ?? plan.einheiten.first?.key
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(plan.einheiten, id: \.key) { einheit in
                    let istAktiv = einheit.key == gewaehlt
                    Button {
                        einheitKey = einheit.key
                    } label: {
                        Chip(text: EinheitName.text(einheit.key), isActive: istAktiv,
                             innenabstand: DesignSystem.Spacing.s16, gefuellt: true)
                            .fixedSize()
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityAddTraits(istAktiv ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Ablauf

    private func vorschlagHolen() async {
        // Ohne aktives Studio (Freies Training) entsteht der Plan trotzdem.
        zustand = .laedt
        do throws(APIError) {
            let plan = try await apiClient.createPlan(studioId: studioId)
            einheitKey = plan.einheiten.first?.key
            zustand = .vorschlag(plan)
        } catch {
            if let fall = OnboardingHinweis.planSonderfall(error, beschwerden: beschwerden) {
                zustand = .sonderfall(fall)
            } else {
                zustand = .fehler(text: OnboardingHinweis.planFehler(error, beimUebernehmen: false), plan: nil)
            }
        }
    }

    private func primaryAktion() async {
        switch zustand {
        case .vorschlag(let plan), .fehler(_, .some(let plan)):
            await uebernehmen(plan)
        case .fehler(_, nil):
            await vorschlagHolen()
        case .laedt, .sonderfall:
            break
        }
    }

    private func uebernehmen(_ plan: Trainingsplan) async {
        uebernimmt = true
        defer { uebernimmt = false }
        do throws(APIError) {
            _ = try await apiClient.acceptPlan(id: plan.planId)
            await beiUebernommen()
        } catch {
            if case .conflict = error {
                // Der Vorschlag ist auf dem Server verworfen (ein neuerer kam
                // dazwischen, oder das Studio wurde verlassen) -- ein neuer
                // Vorschlag statt eines Knopfs, der nie mehr gelingt.
                zustand = .fehler(text: error.servertext, plan: nil)
            } else {
                zustand = .fehler(text: OnboardingHinweis.planFehler(error, beimUebernehmen: true), plan: plan)
            }
        }
    }

    private func fotoLaden(modell: String?) async {
        guard let modell, let url = fotos[modell], bilder[modell] == nil else { return }
        // Kantenlaenge wie in der Geraeteliste (56 pt bei 3x).
        bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
    }
}

/// 4.1 "Das geht noch nicht" und 4.2 "Angaben fehlen": Titel, ein Satz, die
/// eine passende Aktion als Umriss und "Später". Bewusst ohne Akzentflaeche:
/// hier gibt es nichts zu bestaetigen.
struct PlanSonderfallAnsicht: View {
    let fall: PlanSonderfall
    let beiAktion: (PlanSonderfall.Aktion) -> Void
    let beiSpaeter: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("DEIN TRAININGSPLAN")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(minHeight: 44)
                Text(fall.titel.uppercased())
                    .font(DesignSystem.Typography.screentitel)
                    .tracking(-1)
                    .foregroundStyle(DesignSystem.Color.text)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, DesignSystem.Spacing.s8)
                Text(fall.text)
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, DesignSystem.Spacing.s16)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignSystem.Spacing.s4) {
                if let aktion = fall.aktion {
                    SecondaryButton(title: aktionsTitel(aktion)) { beiAktion(aktion) }
                }
                Button("Später", action: beiSpaeter)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.vertical, DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.bg)
        }
    }

    private func aktionsTitel(_ aktion: PlanSonderfall.Aktion) -> String {
        switch aktion {
        case .beschwerdenAendern: "Beschwerden ändern"
        case .ergaenzen: "Ergänzen"
        }
    }
}

#Preview("4.1 Plan nicht möglich") {
    PlanSonderfallAnsicht(
        fall: OnboardingHinweis.planSonderfall(
            .planNichtMoeglich(message: "", baustein: "beine_knie", grund: "beschwerden"),
            beschwerden: ["knie": "meiden"])!,
        beiAktion: { _ in }, beiSpaeter: {})
}

#Preview("4.2 Angaben fehlen") {
    PlanSonderfallAnsicht(
        fall: OnboardingHinweis.planSonderfall(.profilUnvollstaendig(message: "", fehlt: ["ziel", "tage"]), beschwerden: [:])!,
        beiAktion: { _ in }, beiSpaeter: {})
}
