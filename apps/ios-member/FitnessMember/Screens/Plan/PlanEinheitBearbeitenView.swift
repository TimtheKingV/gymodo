import SwiftUI
import UIKit

/// "Einheit bearbeiten" (Entwurf 2b): Positionen ziehen, entfernen und
/// ersetzen -- alles dauerhaft als neue Planversion (E3). Ziehen und Entfernen
/// sammeln sich in `PlanEinheitBearbeitung` und gehen mit "Fertig" in einem
/// Aufruf an den Server (E6); Ersetzen schreibt sofort (E5).
///
/// Ohne Umschalter "Nur dieses Mal", ohne "Übung hinzufügen" und ohne
/// "Plan-Vorschlag wiederherstellen" (E3, E4). Akzent nur als Text auf "Fertig".
struct PlanEinheitBearbeitenView: View {
    let einheitKey: String
    let apiClient: APIClient
    let beiSchliessen: () -> Void

    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf

    @State private var bearbeitung: PlanEinheitBearbeitung
    @State private var schreibt = false
    @State private var fehler: APIError?
    @State private var verwerfenFragen = false
    /// Ein Tausch ist schon geschrieben (E5) -- "Abbrechen" nimmt ihn nicht
    /// zurueck, deshalb heisst der Knopf danach "Schließen" (Final-Review 3).
    @State private var hatGetauscht = false
    @State private var ersetzen: ErsatzZiel?
    @State private var vorschauLader = VorschauLader(ablage: .fotos)
    @State private var fotos: [String: URL] = [:]
    @State private var bilder: [String: UIImage] = [:]

    private struct ErsatzZiel: Identifiable {
        let id: String
    }

    init(einheit: TrainingsplanEinheit, apiClient: APIClient, beiSchliessen: @escaping () -> Void) {
        self.einheitKey = einheit.key
        self.apiClient = apiClient
        self.beiSchliessen = beiSchliessen
        _bearbeitung = State(initialValue: PlanEinheitBearbeitung(einheit: einheit))
    }

    private var plan: Trainingsplan? { PlanAnzeige.plan(bootstrap: katalog.bootstrap) }
    private var einheit: TrainingsplanEinheit? { plan?.einheiten.first { $0.key == einheitKey } }

    var body: some View {
        NavigationStack {
            inhalt
                .background(DesignSystem.Color.bg)
                .navigationTitle("Einheit bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Der Titel selbst gezeichnet: mit eigener Leistenfarbe
                    // fiel er auf die dunkle Systemschrift zurueck und war
                    // auf dem dunklen Grund unsichtbar (Final-Review 4).
                    ToolbarItem(placement: .principal) {
                        Text("Einheit bearbeiten")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.text)
                            // Neben "Abbrechen" knapp: lieber etwas kleiner als "bearbeit…".
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(PlanEinheitBearbeitung.schliessenTitel(hatGetauscht: hatGetauscht)) { abbrechen() }
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .disabled(schreibt)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await fertig() } } label: {
                            if schreibt {
                                ProgressView()
                            } else {
                                Text("Fertig")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(DesignSystem.Color.accent)
                            }
                        }
                        .disabled(schreibt)
                        .testnotizElement("einheit.bearbeiten.fertig", typ: "Button")
                    }
                }
        }
        .interactiveDismissDisabled(schreibt)
        .confirmationDialog("Änderungen verwerfen?", isPresented: $verwerfenFragen, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { beiSchliessen() }
            Button("Weiter bearbeiten", role: .cancel) {}
        } message: {
            if let hinweis = PlanEinheitBearbeitung.verwerfenHinweis(hatGetauscht: hatGetauscht) {
                Text(hinweis)
            }
        }
        .sheet(item: $ersetzen) { ziel in
            ersatzSheet(positionKey: ziel.id)
        }
        .task {
            // Ein fehlendes Foto ist kein Zustand: die Zeile bleibt mit dem Platzhalter.
            fotos = await GeraeteFotos.laden(von: apiClient)
        }
        .testnotizScreen()
    }

    @ViewBuilder
    private var inhalt: some View {
        if let plan, let einheit {
            let zeilen = Dictionary(
                PlanAnzeige.zeilen(plan: plan, einheitKey: einheitKey, zustand: nil, bloecke: [],
                                   bootstrap: katalog.bootstrap).map { ($0.id, $0) },
                uniquingKeysWith: { erste, _ in erste })
            let namen = EinheitNamen(plan: plan, muskeln: HomeZeilen.muskelnJeUebung(katalog.bootstrap))
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(namen.name(einheitKey))
                        .font(DesignSystem.Typography.detailScreentitel)
                        .foregroundStyle(DesignSystem.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Der Name passt sich an, wenn du Übungen tauschst")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let fehler {
                        InlineBanner(tone: .danger, message: PlanTausch.fehlerText(fehler))
                            .padding(.top, DesignSystem.Spacing.s8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s12)
                .padding(.bottom, DesignSystem.Spacing.s16)

                List {
                    ForEach(bearbeitung.positionen(in: einheit), id: \.key) { position in
                        zeile(position: position, modell: zeilen[position.key])
                            .deleteDisabled(!bearbeitung.darfEntfernen || schreibt)
                            .moveDisabled(schreibt)
                            .listRowBackground(DesignSystem.Color.surface)
                            .listRowSeparatorTint(DesignSystem.Color.line)
                    }
                    .onMove { von, nach in bearbeitung.verschieben(von: von, nach: nach) }
                    .onDelete { offsets in bearbeitung.entfernen(offsets) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
                .disabled(schreibt)
            }
        } else {
            Text("Diese Einheit gibt es in deinem Plan nicht mehr.")
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func zeile(position: TrainingsplanPosition, modell: PlanZeilenModell?) -> some View {
        let modell = modell ?? PlanZeilenModell.aus(position, bootstrap: katalog.bootstrap)
        return HStack(spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: modell.exerciseId) {
                PlanZeilenFoto(foto: modell.vorschaubildModell.flatMap { bilder[$0] })
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(modell.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(modell.untertitel)
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button { ersetzen = ErsatzZiel(id: position.key) } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(schreibt)
            .accessibilityLabel("\(modell.name) ersetzen")
            .testnotizElement("einheit.bearbeiten.ersetzen", typ: "Button")
        }
        .padding(.vertical, DesignSystem.Spacing.s4)
        .task(id: modell.vorschaubildModell.flatMap { fotos[$0] }) {
            await fotoLaden(modell: modell.vorschaubildModell)
        }
    }

    private func fotoLaden(modell: String?) async {
        guard let modell, let url = fotos[modell], bilder[modell] == nil else { return }
        // 56 pt bei 3x, wie die Geraeteliste.
        bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
    }

    // MARK: - Ersetzen

    @ViewBuilder
    private func ersatzSheet(positionKey: String) -> some View {
        if let plan, let einheit, let position = einheit.positionen.first(where: { $0.key == positionKey }) {
            // Was die Einheit beim Server fuehrt, auch gerade entfernte
            // Positionen: die stehen dort bis "Fertig" noch drin.
            let belegt = Set(einheit.positionen.map(\.exerciseId))
            let kandidaten = PlanTausch.kandidaten(
                position: position, plan: plan,
                ort: PlanTausch.ort(aktivesStudio: katalog.activeStudioId, bootstrap: katalog.bootstrap),
                belegt: belegt, uebungen: katalog.bootstrap)
            PlanEinheitErsatzSheet(
                alt: PlanZeilenModell.aus(position, bootstrap: katalog.bootstrap).name,
                kandidaten: kandidaten, fotoLader: apiClient, vorschauLader: vorschauLader,
                beiKandidat: { kandidat in await tauschen(position: position, kandidat: kandidat) },
                beiAbbrechen: { ersetzen = nil })
        }
    }

    /// Dauerhafter Tausch ohne `grund` (E5). `nil` = geschrieben und neu geladen.
    private func tauschen(position: TrainingsplanPosition, kandidat: TauschKandidat) async -> APIError? {
        guard let planId = plan?.planId else { return .conflict(message: "Kein Plan geladen") }
        schreibt = true
        defer { schreibt = false }
        do throws(APIError) {
            _ = try await apiClient.swapPlanPosition(
                planId: planId, einheitKey: einheitKey, positionKey: position.key,
                exerciseId: kandidat.exerciseId, modelId: kandidat.modelId)
        } catch {
            if case .conflict = error { await neuLadenUndUebernehmen() }
            return error
        }
        await neuLadenUndUebernehmen()
        hatGetauscht = true
        fehler = nil
        ersetzen = nil
        return nil
    }

    // MARK: - Fertig / Abbrechen

    private func abbrechen() {
        if bearbeitung.geaendert {
            verwerfenFragen = true
        } else {
            beiSchliessen()
        }
    }

    /// Unveraendert nur schliessen; sonst Reihenfolge und Entfernen in einem
    /// Aufruf (E6). Bei einem Fehler bleibt die Liste im bearbeiteten Stand.
    private func fertig() async {
        guard !schreibt else { return }
        guard bearbeitung.geaendert else {
            beiSchliessen()
            return
        }
        guard let planId = plan?.planId else {
            fehler = .conflict(message: "Kein Plan geladen")
            return
        }
        schreibt = true
        defer { schreibt = false }
        do throws(APIError) {
            _ = try await apiClient.ordnePlanEinheit(
                planId: planId, einheitKey: einheitKey, positionKeys: bearbeitung.keys)
        } catch {
            fehler = error
            // 409: eine andere Version ist aktiv. Neu laden, damit ein
            // Wiederholen die richtige trifft (wie `PlanTauschSitzung`).
            if case .conflict = error { await neuLadenUndUebernehmen() }
            return
        }
        fehler = nil
        await neuLaden()
        beiSchliessen()
    }

    // MARK: - Neu laden

    /// Wie `PlanPositionSheet`: Bootstrap neu, dann den Ablauf darauf setzen.
    private func neuLaden() async {
        await katalog.load()
        guard let bootstrap = katalog.bootstrap else { return }
        planAblauf.vorbereiten(bootstrap: bootstrap)
    }

    private func neuLadenUndUebernehmen() async {
        await neuLaden()
        if let einheit { bearbeitung.uebernehmen(neueEinheit: einheit) }
    }
}
