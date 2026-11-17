import SwiftUI
import UIKit

/// "Bearbeiten" einer Planeinheit (P4, Testnotiz 10.11. #3 #4 #6, Tafel 3): die ganze
/// Seite scrollt, Uebungen als Karten. Ziehen am Griff ordnet, Wischen nach links
/// entfernt (eine bleibt), Tipp auf eine Karte oeffnet "Übung anpassen", unten
/// "Übung hinzufügen". Alles sammelt sich in `PlanEinheitEntwurf` und geht mit
/// "Fertig" in einem Aufruf an den Server (`ersetzePlanEinheit`).
/// Akzent nur als Text auf "Fertig".
struct PlanEinheitBearbeitenView: View {
    let einheitKey: String
    let apiClient: APIClient
    let beiSchliessen: () -> Void

    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @Environment(UebungsVideoVorrat.self) private var videoVorrat
    @Environment(WorkoutSessionStore.self) private var sessions

    @State private var entwurf: PlanEinheitEntwurf
    /// Schluessel -> Uebung der Ausgangsposition, fuer "statt X" nur bei echtem Tausch.
    @State private var ausgangUebungen: [String: String]
    @State private var schreibt = false
    @State private var fehler: APIError?
    @State private var verwerfenFragen = false
    @State private var anpassen: Ziel?
    @State private var auswahl: AuswahlZiel?
    /// "Übung tauschen" im Anpassen-Blatt: erst schliessen, dann die Auswahl oeffnen.
    @State private var nachAnpassen: AuswahlZiel?
    @State private var vorschauLader = VorschauLader(ablage: .fotos)
    @State private var fotos: [String: URL] = [:]
    @State private var bilder: [String: UIImage] = [:]

    /// Hoechstens so viele Positionen je Einheit (wie der Server).
    static let hoechstePositionen = 20
    private static let kopfId = "kopf"

    private struct Ziel: Identifiable {
        let id: UUID
    }

    private enum AuswahlZiel: Identifiable {
        case tauschen(UUID)
        case hinzufuegen

        var id: String {
            switch self {
            case .tauschen(let id): "t-\(id.uuidString)"
            case .hinzufuegen: "neu"
            }
        }
    }

    init(plan: Trainingsplan, einheit: TrainingsplanEinheit, apiClient: APIClient,
         beiSchliessen: @escaping () -> Void) {
        self.einheitKey = einheit.key
        self.apiClient = apiClient
        self.beiSchliessen = beiSchliessen
        _entwurf = State(initialValue: PlanEinheitEntwurf(
            einheit: einheit, vorgaben: plan.vorgaben, merkmale: plan.planUebungen))
        _ausgangUebungen = State(initialValue: Self.ausgang(einheit))
    }

    private static func ausgang(_ einheit: TrainingsplanEinheit) -> [String: String] {
        Dictionary(einheit.positionen.map { ($0.key, $0.exerciseId) }, uniquingKeysWith: { erste, _ in erste })
    }

    private var plan: Trainingsplan? { PlanAnzeige.plan(bootstrap: katalog.bootstrap) }
    private var einheit: TrainingsplanEinheit? { plan?.einheiten.first { $0.key == einheitKey } }

    var body: some View {
        NavigationStack {
            inhalt
                .background(DesignSystem.Color.bg)
                .navigationTitle("Bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Der Titel selbst gezeichnet: mit eigener Leistenfarbe
                    // fiel er auf die dunkle Systemschrift zurueck (Final-Review 4).
                    ToolbarItem(placement: .principal) {
                        Text("Bearbeiten")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { abbrechen() }
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
                        // Nach einem 409 kann die Einheit weg sein: dann gibt es nichts zu speichern.
                        .disabled(schreibt || einheit == nil)
                        .testnotizElement("einheit.bearbeiten.fertig", typ: "Button")
                    }
                }
        }
        .interactiveDismissDisabled(schreibt || entwurf.geaendert)
        .confirmationDialog("Änderungen verwerfen?", isPresented: $verwerfenFragen, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { beiSchliessen() }
            Button("Weiter bearbeiten", role: .cancel) {}
        }
        .sheet(item: $anpassen, onDismiss: {
            if let ziel = nachAnpassen {
                nachAnpassen = nil
                auswahl = ziel
            }
        }) { ziel in
            anpassenSheet(id: ziel.id)
        }
        .sheet(item: $auswahl) { ziel in
            auswahlSheet(ziel)
        }
        .task {
            // Ein fehlendes Foto ist kein Zustand: die Karte bleibt mit dem Platzhalter.
            fotos = await GeraeteFotos.laden(von: apiClient)
        }
        .testnotizScreen()
    }

    // MARK: - Seite

    @ViewBuilder
    private var inhalt: some View {
        if let plan, einheit != nil {
            ScrollViewReader { proxy in
                List {
                    kopf(plan: plan)
                        .id(Self.kopfId)
                        .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.s12, leading: 20, bottom: 10, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    ForEach(entwurf.positionen) { position in
                        karte(position)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .moveDisabled(schreibt)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if entwurf.darfEntfernen {
                                    Button("Entfernen", role: .destructive) {
                                        withAnimation { _ = entwurf.entfernen(id: position.id) }
                                    }
                                    .disabled(schreibt)
                                }
                            }
                    }
                    .onMove { von, nach in entwurf.verschieben(von: von, nach: nach) }
                    fuss
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: DesignSystem.Spacing.s24, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .disabled(schreibt)
                // Der Fehlerbanner steht im Kopf: nach "Fertig" von weiter unten dorthin
                // scrollen, sonst sieht ein Fehlschlag aus wie nichts (P4, Testnotiz 10.11. #3).
                .onChange(of: fehler) { _, neu in
                    guard neu != nil else { return }
                    withAnimation { proxy.scrollTo(Self.kopfId, anchor: .top) }
                }
            }
        } else {
            Text("Diese Einheit gibt es in deinem Plan nicht mehr.")
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func kopf(plan: Trainingsplan) -> some View {
        let namen = EinheitNamen(plan: plan, muskeln: HomeZeilen.muskelnJeUebung(katalog.bootstrap))
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(namen.name(einheitKey))
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Tippe auf eine Übung, um Sätze, Wiederholungen und Pause anzupassen.")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let minuten = minuten(plan: plan) {
                Text("ca. \(minuten) min")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.top, 2)
            }
            if let fehler {
                InlineBanner(tone: .danger, message: PlanTausch.fehlerText(fehler))
                    .padding(.top, DesignSystem.Spacing.s8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .moveDisabled(true)
    }

    /// Lokal mitgerechnet; ohne Vorgaben (alter Server) nur der Stand des Servers,
    /// solange nichts geaendert ist.
    private func minuten(plan: Trainingsplan) -> Int? {
        if plan.vorgaben != nil { return Int(entwurf.geschaetzteMinuten.rounded()) }
        guard !entwurf.geaendert, let m = einheit?.geschaetzteMinuten else { return nil }
        return Int(m.rounded())
    }

    private func karte(_ position: EntwurfsPosition) -> some View {
        let modell = kartenModell(position)
        return Uebungskarte(
            modell: modell, foto: modell.vorschaubildModell.flatMap { bilder[$0] },
            beiTippen: { if !schreibt { anpassen = Ziel(id: position.id) } },
            testnotizKennung: "einheit.bearbeiten.karte"
        ) {
            griff(position: position, name: modell.name)
        }
        .task(id: modell.vorschaubildModell.flatMap { fotos[$0] }) {
            await fotoLaden(modell: modell.vorschaubildModell)
        }
    }

    /// Zieh-Hinweis; gezogen wird die ganze Zeile (`onMove`). Fuer VoiceOver ein eigenes
    /// Element mit Aktionen nach oben/unten (P4, Testnotiz 10.11. #3).
    private func griff(position: EntwurfsPosition, name: String) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel("\(name) verschieben")
            .accessibilityAction(named: "Nach oben") { verschieben(position.id, um: -1) }
            .accessibilityAction(named: "Nach unten") { verschieben(position.id, um: 1) }
    }

    private func verschieben(_ id: UUID, um schritt: Int) {
        guard !schreibt, let i = entwurf.positionen.firstIndex(where: { $0.id == id }) else { return }
        let ziel = i + schritt
        guard entwurf.positionen.indices.contains(ziel) else { return }
        // move(fromOffsets:toOffset:): nach unten zaehlt der Platz hinter dem Ziel.
        entwurf.verschieben(von: IndexSet(integer: i), nach: schritt > 0 ? ziel + 1 : ziel)
    }

    private var fuss: some View {
        let voll = entwurf.positionen.count >= Self.hoechstePositionen
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Button { auswahl = .hinzufuegen } label: {
                Label("Übung hinzufügen", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DesignSystem.Color.line, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
            .disabled(voll || schreibt)
            .opacity(voll ? 0.5 : 1)
            .testnotizElement("einheit.bearbeiten.hinzufuegen", typ: "Button")
            Text(voll
                 ? "Mehr als \(Self.hoechstePositionen) Übungen passen nicht in eine Einheit."
                 : "Nach links wischen zum Entfernen. Eine Übung bleibt immer.")
                .font(.system(size: 12.5))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .moveDisabled(true)
    }

    // MARK: - Karte

    private func name(_ p: EntwurfsPosition) -> String {
        let bootstrap = katalog.bootstrap
        let maschine = bootstrap?.machines.first {
            ($0.equipmentModel.id == p.modelId || $0.equipmentModel.catalogModelId == p.modelId)
                && $0.exercises.contains { $0.id == p.exerciseId }
        }
        return PlanZeilenModell.uebungsname(exerciseId: p.exerciseId, maschine: maschine, bootstrap: bootstrap)
    }

    private func kartenModell(_ p: EntwurfsPosition) -> UebungskarteModell {
        UebungskarteModell.aus(
            p, name: name(p),
            bild: PlanAnzeige.bildmodell(exerciseId: p.exerciseId, modelId: p.modelId, bootstrap: katalog.bootstrap),
            geaendert: entwurf.geaenderteWerte(id: p.id),
            ausgangExerciseId: p.key.flatMap { ausgangUebungen[$0] })
    }

    private func fotoLaden(modell: String?) async {
        guard let modell, let url = fotos[modell], bilder[modell] == nil else { return }
        // 56 pt bei 3x, wie die Geraeteliste.
        bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
    }

    // MARK: - Blaetter

    @ViewBuilder
    private func anpassenSheet(id: UUID) -> some View {
        if let position = entwurf.positionen.first(where: { $0.id == id }) {
            let modell = kartenModell(position)
            PlanPositionAnpassenSheet(
                modell: modell, foto: modell.vorschaubildModell.flatMap { bilder[$0] }, position: position,
                darfEntfernen: entwurf.darfEntfernen,
                beiUebernehmen: { saetze, wdhVon, wdhBis, pauseSek, dauerMin in
                    entwurf.werteSetzen(id: id, saetze: saetze, wdhVon: wdhVon, wdhBis: wdhBis,
                                        pauseSek: pauseSek, dauerMin: dauerMin)
                },
                beiTauschen: {
                    nachAnpassen = .tauschen(id)
                    anpassen = nil
                },
                beiEntfernen: {
                    anpassen = nil
                    withAnimation { _ = entwurf.entfernen(id: id) }
                })
        }
    }

    @ViewBuilder
    private func auswahlSheet(_ ziel: AuswahlZiel) -> some View {
        if let plan {
            let belegt = Set(entwurf.positionen.map(\.exerciseId))
            switch ziel {
            case .hinzufuegen:
                auswahlBlatt(zweck: .hinzufuegen, plan: plan, belegt: belegt) { exerciseId, modelId, _ in
                    entwurf.hinzufuegen(exerciseId: exerciseId, modelId: modelId)
                }
            case .tauschen(let id):
                if let position = entwurf.positionen.first(where: { $0.id == id }) {
                    let kandidaten = PlanTausch.kandidaten(
                        position: stelle(position), plan: plan,
                        ort: PlanTausch.ort(aktivesStudio: katalog.activeStudioId, bootstrap: katalog.bootstrap),
                        belegt: belegt, uebungen: katalog.bootstrap)
                    let alt = kartenModell(position)
                    auswahlBlatt(zweck: .tauschen(alt: alt, kandidaten: kandidaten), plan: plan, belegt: belegt) {
                        exerciseId, modelId, _ in
                        entwurf.tauschen(id: id, exerciseId: exerciseId, modelId: modelId, alterName: alt.name)
                    }
                }
            }
        }
    }

    private func auswahlBlatt(
        zweck: PlanUebungAuswahlZweck, plan: Trainingsplan, belegt: Set<String>,
        beiWahl: @escaping (_ exerciseId: String, _ modelId: String, _ name: String) -> Void
    ) -> some View {
        PlanUebungAuswahlSheet(
            zweck: zweck, merkmale: plan.planUebungen, belegt: belegt,
            fotoLader: apiClient, vorschauLader: vorschauLader,
            beiWahl: { exerciseId, modelId, name in
                beiWahl(exerciseId, modelId, name)
                auswahl = nil
            },
            beiAbbrechen: { auswahl = nil })
        .environment(katalog)
        .environment(videoVorrat)
        .environment(sessions)
    }

    /// Die Stelle fuer "Passt an diese Stelle": der Baustein der Uebung, die jetzt dort
    /// steht, sonst der der Ausgangsposition. `PlanTausch.kandidaten` liest nur
    /// Baustein und Uebung.
    private func stelle(_ p: EntwurfsPosition) -> TrainingsplanPosition {
        let alt = p.key.flatMap { key in einheit?.positionen.first { $0.key == key } }
        let baustein = plan?.planUebungen[p.exerciseId]?.baustein ?? alt?.baustein ?? ""
        return TrainingsplanPosition(
            key: p.key ?? "", baustein: baustein, rolle: alt?.rolle ?? "pflicht", exerciseId: p.exerciseId,
            modelId: p.modelId, typ: alt?.typ ?? "", saetze: p.saetze, wdhVon: p.wdhVon, wdhBis: p.wdhBis,
            reserveVon: alt?.reserveVon ?? 0, reserveBis: alt?.reserveBis ?? 0, pauseSek: p.pauseSek,
            aufwaermsatz: p.aufwaermsatz, dauerMin: p.dauerMin, hauptmuskeln: alt?.hauptmuskeln ?? [])
    }

    // MARK: - Fertig / Abbrechen

    private func abbrechen() {
        if entwurf.geaendert {
            verwerfenFragen = true
        } else {
            beiSchliessen()
        }
    }

    /// Unveraendert nur schliessen; sonst die ganze Einheit in einem Aufruf. Bei einem
    /// Fehler bleibt der Entwurf, wie er ist.
    private func fertig() async {
        guard !schreibt else { return }
        guard entwurf.geaendert else {
            beiSchliessen()
            return
        }
        guard let planId = plan?.planId else {
            fehler = .conflict(message: "Kein Plan geladen")
            return
        }
        schreibt = true
        defer { schreibt = false }
        // Erst leeren: derselbe Fehler noch einmal soll wieder nach oben scrollen.
        fehler = nil
        do throws(APIError) {
            _ = try await apiClient.ersetzePlanEinheit(
                planId: planId, einheitKey: einheitKey, positionen: entwurf.rumpf)
        } catch {
            fehler = error
            // 409: eine andere Version ist aktiv. Neu laden und den Entwurf auf sie
            // setzen, damit ein Wiederholen die richtige trifft.
            if case .conflict = error {
                await neuLaden()
                if let einheit {
                    entwurf.nachKonflikt(neueEinheit: einheit)
                    ausgangUebungen = Self.ausgang(einheit)
                }
            }
            return
        }
        fehler = nil
        await neuLaden()
        beiSchliessen()
    }

    /// Wie `PlanPositionSheet`: Bootstrap neu, dann den Ablauf darauf setzen.
    private func neuLaden() async {
        await katalog.load()
        guard let bootstrap = katalog.bootstrap else { return }
        planAblauf.vorbereiten(bootstrap: bootstrap)
    }
}
