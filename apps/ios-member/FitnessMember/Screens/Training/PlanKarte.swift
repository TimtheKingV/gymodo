import SwiftUI
import UIKit

extension PlanAnzeige {
    /// Der Stand von heute aus Bootstrap, Ort und Ablaufspeicher -- eine
    /// Stelle fuer Training-Tab und Home, damit beide dieselbe Einheit zeigen.
    @MainActor
    static func heute(katalog: CatalogStore, ablauf: TrainingsplanAblaufStore) -> Heute? {
        heute(bootstrap: katalog.bootstrap,
              ablaufPlanId: ablauf.planId, ablaufEinheitKey: ablauf.einheitKey,
              ablaufZustand: ablauf.zustand, naechsteEinheitKey: ablauf.naechsteEinheitKey,
              ablaufGebunden: ablauf.gebundeneSessionId != nil)
    }
}

/// Der Plan im Training-Tab ueber "Gerät wählen" (Entwuerfe 2.1 vor dem
/// Start, 2.2 mitten im Training), im Studio wie im Freien Training. Ohne
/// Plan und ohne Bootstrap steht hier nichts -- der Tab sieht aus wie
/// vor dem Plan.
///
/// Trainiert wird wie bisher ueber Scan oder Geraeteliste; die Karte zeigt
/// nur, was dran ist, und hakt ab. Keine Akzentflaeche: die des Screens
/// bleibt "Gerät scannen".
struct PlanKarteBereich: View {
    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf

    /// Die laufende Einheit; nil vor dem Start (2.1).
    let session: LokaleSession?
    let fotoLader: any GeraetefotosLoading
    let vorschauLader: VorschauLader
    /// Tipp auf eine Planzeile (Task 12: Vorgaben- und Tausch-Sheet). nil =
    /// die Zeilen sind still.
    var beiPosition: ((TrainingsplanPosition) -> Void)? = nil

    var body: some View {
        if let heute = PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf) {
            PlanKarte(heute: heute, bloecke: session?.bloecke ?? [], laeuft: session != nil,
                      bootstrap: katalog.bootstrap, fotoLader: fotoLader, vorschauLader: vorschauLader,
                      beiPosition: beiPosition)
                // Nach "Training beenden" ist der Ablauf leer, bis jemand
                // vorbereitet (TrainingsplanAblaufStore.einheitBeendet); die
                // Wurzel tut das nur bei Bootstrap, Ortswechsel und
                // Vordergrund. Zurueck vom Abschluss erscheint die Karte neu
                // und baut hier die naechste Einheit. Idempotent.
                .onAppear {
                    guard let bootstrap = katalog.bootstrap else { return }
                    planAblauf.vorbereiten(bootstrap: bootstrap)
                }
        }
    }
}

/// Die Karte selbst, ohne Speicher -- damit Vorschau und Sichtpruefung sie
/// mit festen Werten zeigen koennen.
struct PlanKarte: View {
    let heute: PlanAnzeige.Heute
    let bloecke: [LokalerBlock]
    let laeuft: Bool
    let bootstrap: BootstrapResponse?
    let fotoLader: any GeraetefotosLoading
    let vorschauLader: VorschauLader
    var beiPosition: ((TrainingsplanPosition) -> Void)? = nil

    /// Modell -> signierte URL, wie in der Geraeteliste je Erscheinen geladen.
    @State private var fotos: [String: URL] = [:]
    @State private var bilder: [String: UIImage] = [:]
    @State private var warumOffen = false

    private var plan: Trainingsplan { heute.plan }

    var body: some View {
        let zeilen = PlanAnzeige.zeilen(plan: plan, einheitKey: heute.einheitKey, zustand: heute.zustand,
                                        bloecke: bloecke, bootstrap: bootstrap)
        let zusatz = laeuft
            ? PlanAnzeige.zusaetzlichGemacht(plan: plan, einheitKey: heute.einheitKey, zustand: heute.zustand,
                                             bloecke: bloecke, bootstrap: bootstrap)
            : []
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Card {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                    kopf
                    zeilenListe(zeilen)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, DesignSystem.Spacing.s4)
            }
            fuss
            if !zusatz.isEmpty {
                Text("ZUSÄTZLICH GEMACHT")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.top, DesignSystem.Spacing.s4)
                    .accessibilityAddTraits(.isHeader)
                Card {
                    zeilenListe(zusatz, tippbar: false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, DesignSystem.Spacing.s4)
                }
            }
        }
        .task {
            // Ein fehlendes Foto ist kein Zustand (GeraeteFotos.laden): die
            // Zeile bleibt mit dem Platzhalter stehen.
            fotos = await GeraeteFotos.laden(von: fotoLader)
        }
        .sheet(isPresented: $warumOffen) {
            PlanWarumView(struktur: plan.struktur, gruende: plan.gruende)
        }
    }

    // MARK: - Kopf

    /// Vor dem Start wie mitten im Training nur "EINHEIT A" als Marke, rechts
    /// Uebungen und Dauer (vorher) bzw. Fortschritt und Restzeit (laufend).
    /// Die grosse Ueberschrift "Heute dran" steht auf Home (Leinwand 2d, E8);
    /// hier bleibt die Uebungsliste, an der trainiert wird. Die Uhr steht im
    /// Kopf "TRAINING LÄUFT" darueber.
    private var kopf: some View {
        let einheit = EinheitName.text(heute.einheitKey)
        let rechts: String
        let gesprochen: String
        if laeuft {
            let fortschritt = PlanAnzeige.fortschritt(plan: plan, einheitKey: heute.einheitKey, zustand: heute.zustand)
            let rest = PlanAnzeige.restminutenText(plan: plan, einheitKey: heute.einheitKey, zustand: heute.zustand)
            rechts = [fortschritt, rest].compactMap { $0 }.joined(separator: " · ")
            gesprochen = "\(einheit), \(fortschritt) Übungen\(rest.map { ", \($0)" } ?? "")"
        } else {
            rechts = PlanAnzeige.metaText(heute.einheit)
            gesprochen = "\(einheit), \(rechts)"
        }
        return HStack(alignment: .firstTextBaseline) {
            Text(einheit.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer()
            Text(rechts)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gesprochen)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Zeilen

    private func zeilenListe(_ zeilen: [PlanZeilenModell], tippbar: Bool = true) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { index, zeile in
                if index > 0 {
                    Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                }
                let position = heute.einheit.positionen.first { $0.key == zeile.id }
                Group {
                    if tippbar, let beiPosition, let position {
                        Button { beiPosition(position) } label: { planZeile(zeile) }
                            .buttonStyle(PressButtonStyle())
                    } else {
                        planZeile(zeile)
                    }
                }
            }
        }
    }

    private func planZeile(_ zeile: PlanZeilenModell) -> some View {
        PlanZeile(modell: zeile, foto: zeile.vorschaubildModell.flatMap { bilder[$0] })
            .contentShape(Rectangle())
            .task(id: zeile.vorschaubildModell.flatMap { fotos[$0] }) {
                await fotoLaden(modell: zeile.vorschaubildModell)
            }
    }

    private func fotoLaden(modell: String?) async {
        guard let modell, let url = fotos[modell], bilder[modell] == nil else { return }
        // 56 pt bei 3x, wie die Geraeteliste.
        bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
    }

    // MARK: - Fuss

    /// "Danach: Einheit B" und "Warum so?" (Entwurf 2.1). Der Link fuehrt
    /// vorerst auf eine Platzhalterseite; die Erklaertexte kommen mit Etappe 5.
    private var fuss: some View {
        HStack {
            if let danach = PlanAnzeige.danachText(plan: plan, einheitKey: heute.einheitKey) {
                Text(danach)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            Button { warumOffen = true } label: {
                Text("Warum so?")
                    .font(.system(size: 14))
                    .underline()
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("Zeigt, warum dein Plan so aussieht")
        }
        .padding(.horizontal, DesignSystem.Spacing.s4)
    }
}
