import SwiftUI
import UIKit

extension PlanTausch {
    /// Der Auftrag zur angetippten Zeile aus Bootstrap und Ablaufspeicher --
    /// dieselbe Quelle wie die Karte (`PlanAnzeige.heute`), damit Sheet und
    /// Zeile dieselbe Einheit und denselben Status meinen.
    @MainActor
    static func auftrag(position: TrainingsplanPosition, katalog: CatalogStore,
                        ablauf: TrainingsplanAblaufStore) -> PlanTauschAuftrag? {
        guard let heute = PlanAnzeige.heute(katalog: katalog, ablauf: ablauf) else { return nil }
        return auftrag(position: position, heute: heute, bootstrap: katalog.bootstrap)
    }
}

extension View {
    /// Das Sheet zu einer Planzeile (Entwuerfe 3.1-3.3) an der Wurzel des
    /// Training-Tabs. Nicht an der Karte: die lebt in einer LazyVStack, und
    /// ein Sheet dort kann beim Scrollen mit ihr verschwinden.
    func planPositionSheet(auftrag: Binding<PlanTauschAuftrag?>, apiClient: APIClient,
                           vorschauLader: VorschauLader,
                           beiStarten: @escaping (String) -> Void) -> some View {
        modifier(PlanPositionSheetHuelle(auftrag: auftrag, apiClient: apiClient, vorschauLader: vorschauLader,
                                         beiStarten: beiStarten))
    }
}

/// Baut zur angetippten Zeile die Sitzung mit den echten Stores; die
/// Sitzung selbst kennt nur Protokolle und Closures (Tests).
private struct PlanPositionSheetHuelle: ViewModifier {
    @Binding var auftrag: PlanTauschAuftrag?
    let apiClient: APIClient
    let vorschauLader: VorschauLader
    let beiStarten: (String) -> Void

    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(UebungsVideoVorrat.self) private var videoVorrat

    func body(content: Content) -> some View {
        content.sheet(item: $auftrag) { auftrag in
            PlanPositionSheet(
                sitzung: PlanTauschSitzung(
                    auftrag: auftrag, client: apiClient, ablauf: planAblauf,
                    istOnline: { [netz] in netz.istOnline },
                    aktuellePlanId: { [katalog] in
                        PlanAnzeige.plan(bootstrap: katalog.bootstrap)?.planId
                    },
                    neuLaden: { [katalog, planAblauf] in
                        await katalog.load()
                        // Wie RootView nach jedem Bootstrap; hier sofort, damit
                        // die Karte beim Schliessen schon die neue Version zeigt.
                        // Ohne Bootstrap nichts (sonst ginge ein Tausch nur
                        // heute verloren, siehe RootView).
                        guard let bootstrap = katalog.bootstrap else { return }
                        planAblauf.vorbereiten(bootstrap: bootstrap)
                    }),
                fotoLader: apiClient, vorschauLader: vorschauLader,
                beiFertig: { self.auftrag = nil },
                beiStarten: { uebungId in
                    self.auftrag = nil
                    beiStarten(uebungId)
                })
            .environment(videoVorrat)
        }
    }
}

/// Das Sheet zu einer Planzeile: erst die Vorgabe (3.1), auf Wunsch die
/// Kandidaten (3.2) und mit Schalter die Bestaetigung (3.3) -- ein Sheet,
/// das seinen Inhalt wechselt, statt drei gestapelter.
///
/// 3.1 hat bewusst keine Akzentflaeche: trainiert wird ueber Scan oder
/// Geraeteliste wie sonst.
struct PlanPositionSheet: View {
    @State private var sitzung: PlanTauschSitzung
    let fotoLader: any GeraetefotosLoading
    let vorschauLader: VorschauLader
    let beiFertig: () -> Void
    /// "Gerät wählen": die Uebung der Position starten, an welchem Geraet
    /// auch immer (Spec 5). Schliesst das Sheet; die Wurzel oeffnet die Auswahl.
    var beiStarten: ((String) -> Void)?

    /// Gemessene Hoehe fuer 3.1/3.3: so hoch wie der Inhalt, wie der Drawer.
    @State private var hoehe: CGFloat = 340
    @State private var bilder: [String: UIImage] = [:]

    init(sitzung: PlanTauschSitzung, fotoLader: any GeraetefotosLoading, vorschauLader: VorschauLader,
         beiFertig: @escaping () -> Void, beiStarten: ((String) -> Void)? = nil) {
        self.beiStarten = beiStarten
        _sitzung = State(initialValue: sitzung)
        self.fotoLader = fotoLader
        self.vorschauLader = vorschauLader
        self.beiFertig = beiFertig
    }

    private var auftrag: PlanTauschAuftrag { sitzung.auftrag }

    var body: some View {
        Group {
            switch sitzung.schritt {
            case .vorgabe:
                gemessen(vorgabe)
            case .kandidaten:
                PlanTauschListe(sitzung: sitzung, bilder: bilder, beiFertig: beiFertig)
            case .bestaetigen(let kandidat):
                gemessen(PlanTauschBestaetigung(sitzung: sitzung, kandidat: kandidat, beiFertig: beiFertig))
            }
        }
        .presentationDetents(sitzung.schritt == .kandidaten ? [.medium, .large] : [.height(hoehe)])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Color.surface)
        // Waehrend "Übernehmen" schreibt, nicht wegwischen: sonst bliebe
        // offen, ob die neue Version steht.
        .interactiveDismissDisabled(sitzung.schreibtGerade)
        .task {
            // Fotos nur, wenn es eine Liste gibt; fehlen sie, bleibt der
            // Platzhalter (GeraeteFotos.laden).
            guard auftrag.zeigtAndereUebung else { return }
            let fotos = await GeraeteFotos.laden(von: fotoLader)
            for kandidat in auftrag.kandidaten {
                guard let modell = kandidat.vorschaubildModell, bilder[modell] == nil,
                      let url = fotos[modell] else { continue }
                bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
            }
        }
    }

    /// Misst den Inhalt fuer den Detent; die untere Safe Area gehoert dazu,
    /// sonst saesse "Schließen" hinter dem Home-Indikator (wie
    /// UebungsstartSheet).
    private func gemessen(_ inhalt: some View) -> some View {
        inhalt
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height + proxy.safeAreaInsets.bottom
            } action: { hoehe = $0 }
            .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 3.1

    private var vorgabe: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(auftrag.name.uppercased())
                .font(.system(size: 22, weight: .black))
                .tracking(-0.5)
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            let tags = PlanTausch.vorgabeTags(auftrag.position)
            if !tags.isEmpty {
                Fliesslayout(abstand: DesignSystem.Spacing.s8) {
                    ForEach(tags, id: \.self) { PlanVorgabeTag(text: $0) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Vorgabe: " + tags.joined(separator: ", "))
            }
            if let ersatz = auftrag.ersatzName {
                absatz("Heute machst du stattdessen \(ersatz).")
            }
            if let vorgesehen = auftrag.vorgesehen {
                absatz(vorgesehen)
            }
            // Die Position meint die Uebung, nicht ein Geraet: die Auswahl
            // zeigt nur Geraete, die sie anbieten. Erledigte Positionen
            // starten nichts mehr.
            if let beiStarten, auftrag.status != .erledigt {
                SecondaryButton(title: "Gerät wählen") { beiStarten(auftrag.uebungId) }
                    .accessibilityHint("Zeigt Geräte, an denen du \(auftrag.ersatzName ?? auftrag.name) machen kannst")
            }
            // Ohne Kandidaten gar kein Knopf -- nie eine leere Liste
            // (Review Focus 3); erledigt, optional und Cardio tauschen nicht.
            if auftrag.zeigtAndereUebung {
                SecondaryButton(title: "Andere Übung wählen") { sitzung.andereUebung() }
                    .padding(.top, DesignSystem.Spacing.s4)
                    .accessibilityHint("Zeigt Übungen, die hier auch passen")
            }
            PlanLeiserKnopf(titel: "Schließen", aktion: beiFertig)
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, DesignSystem.Spacing.s8)
    }

    private func absatz(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Ein Vorgabe-Tag (Entwurf `.tag`): Umriss, klein und gesperrt, nie Flaeche.
struct PlanVorgabeTag: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .heavy))
            // Enger als das Label-Tracking: die vier Tags von 3.1 passen so
            // auf eine Zeile wie im Entwurf.
            .tracking(0.5)
            .monospacedDigit()
            .foregroundStyle(DesignSystem.Color.textFaint)
            .padding(.horizontal, DesignSystem.Spacing.s8)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(DesignSystem.Color.line, lineWidth: 1))
    }
}

/// "Schließen"/"Abbrechen" (Entwurf `.btn.quiet`): nur Text, volle Breite,
/// 44 pt Tippflaeche.
struct PlanLeiserKnopf: View {
    let titel: String
    var aktiv = true
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Text(titel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!aktiv)
        .opacity(aktiv ? 1 : 0.5)
    }
}
