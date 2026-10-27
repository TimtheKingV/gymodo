import SwiftUI
import UIKit

extension PlanAnzeige {
    /// Der Stand von heute aus Bootstrap, Ort und Ablaufspeicher -- eine
    /// Stelle fuer Training-Tab und Home, damit beide dieselbe Einheit zeigen.
    @MainActor
    static func heute(katalog: CatalogStore, ablauf: TrainingsplanAblaufStore) -> Heute? {
        heute(bootstrap: katalog.bootstrap, studioId: katalog.activeStudioId,
              ablaufPlanId: ablauf.planId, ablaufEinheitKey: ablauf.einheitKey,
              ablaufZustand: ablauf.zustand, naechsteEinheitKey: ablauf.naechsteEinheitKey,
              ablaufGebunden: ablauf.gebundeneSessionId != nil, ablaufStudioId: ablauf.studioId)
    }
}

/// Der Plan im Training-Tab ueber "Gerät wählen" (Entwuerfe 2.1 vor dem
/// Start, 2.2 mitten im Training). Ohne Plan im aktiven Studio, im Freien
/// Training und ohne Bootstrap steht hier nichts -- der Tab sieht aus wie
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
                    planAblauf.vorbereiten(bootstrap: bootstrap, studioId: katalog.activeStudioId)
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
            PlanWarumView(gruende: plan.gruende)
        }
    }

    // MARK: - Kopf

    /// 2.1: "HEUTE DRAN" ueber gross "EINHEIT A", rechts Uebungen und Dauer.
    /// 2.2: nur "EINHEIT A", rechts Fortschritt und Restzeit -- die Uhr
    /// steht schon im Kopf "TRAINING LÄUFT" darueber.
    @ViewBuilder
    private var kopf: some View {
        let einheit = EinheitName.text(heute.einheitKey).uppercased()
        if laeuft {
            let fortschritt = PlanAnzeige.fortschritt(plan: plan, einheitKey: heute.einheitKey, zustand: heute.zustand)
            let rest = PlanAnzeige.restminutenText(plan: plan, einheitKey: heute.einheitKey, zustand: heute.zustand)
            HStack(alignment: .firstTextBaseline) {
                Text(einheit)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Spacer()
                Text([fortschritt, rest].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(EinheitName.text(heute.einheitKey)), \(fortschritt) Übungen\(rest.map { ", \($0)" } ?? "")")
            .accessibilityAddTraits(.isHeader)
        } else {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("HEUTE DRAN")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                    Text(einheit)
                        .font(.system(size: 34, weight: .black))
                        .tracking(-1)
                        .foregroundStyle(DesignSystem.Color.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(PlanAnzeige.uebungenText(heute.einheit.positionen.count))
                    if let minuten = heute.einheit.geschaetzteMinuten {
                        Text("ca. \(Int(minuten.rounded())) Min")
                    }
                }
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Heute dran: \(EinheitName.text(heute.einheitKey)), \(PlanAnzeige.metaText(heute.einheit))")
            .accessibilityAddTraits(.isHeader)
        }
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
