import SwiftUI
import UIKit

/// Wozu die Auswahl offen ist (P4, Testnotiz 10.11. #5): eine Position
/// tauschen (mit Vorschlaegen fuer die Stelle) oder eine Uebung anhaengen.
enum PlanUebungAuswahlZweck: Equatable {
    case tauschen(alt: UebungskarteModell, kandidaten: [TauschKandidat])
    case hinzufuegen
}

/// Uebung fuer den Plan waehlen, frei oder als Vorschlag (P4, Testnotiz
/// 10.11. #5, Tafel 5). Oben beim Tauschen "Du ersetzt" und die Vorschlaege
/// des Bausteins, darunter die normale Geraeteliste mit Suche, Bullets und
/// Favoriten. Was der Server nicht annimmt, steht ausgegraut mit Grund
/// (`PlanUebungWahl`). Das Schreiben macht der Aufrufer.
struct PlanUebungAuswahlSheet: View {
    let zweck: PlanUebungAuswahlZweck
    let merkmale: [String: PlanUebungsMerkmal]
    /// Uebungen, die schon in der Einheit stehen.
    let belegt: Set<String>
    let fotoLader: any GeraetefotosLoading & UebungsvideosLoading
    let vorschauLader: VorschauLader
    let beiWahl: (_ exerciseId: String, _ modelId: String, _ name: String) -> Void
    let beiAbbrechen: () -> Void

    init(zweck: PlanUebungAuswahlZweck, merkmale: [String: PlanUebungsMerkmal], belegt: Set<String>,
         fotoLader: any GeraetefotosLoading & UebungsvideosLoading, vorschauLader: VorschauLader,
         beiWahl: @escaping (_ exerciseId: String, _ modelId: String, _ name: String) -> Void,
         beiAbbrechen: @escaping () -> Void) {
        self.zweck = zweck
        self.merkmale = merkmale
        self.belegt = belegt
        self.fotoLader = fotoLader
        self.vorschauLader = vorschauLader
        self.beiWahl = beiWahl
        self.beiAbbrechen = beiAbbrechen
    }

    @Environment(UebungsVideoVorrat.self) private var videoVorrat
    /// Eigener Pfad: Kategorieseiten und "Welche Übung?" liegen im Stack
    /// dieses Blatts, wie bei `zirkelAuswahl` im Training-Tab.
    @State private var pfad = NavigationPath()
    @State private var bilder: [String: UIImage] = [:]

    var body: some View {
        NavigationStack(path: $pfad) {
            GeraeteAuswahlView(fotoLader: fotoLader, vorschauLader: vorschauLader, titel: titel,
                               gesperrt: sperrgrund) {
                kopf
            } trainingsinhalt: {
                EmptyView()
            } beiAuswahl: { station, uebungId in
                waehle(station, uebungId)
            } beiKachel: { kachel in
                switch GeraeteAuswahl.ziel(kachel) {
                case .station(let station): waehle(station, nil)
                case .liste(let gruppe): pfad.append(GeraetRoute.kategorie(gruppe))
                }
            }
            .navigationDestination(for: GeraetRoute.self) { route in
                if case .kategorie(let gruppe) = route {
                    GeraeteAuswahlView(fotoLader: fotoLader, vorschauLader: vorschauLader, gruppe: gruppe,
                                       gesperrt: sperrgrund) { station, uebungId in
                        waehle(station, uebungId)
                    }
                    .environment(videoVorrat)
                }
            }
            .navigationDestination(for: ZirkelUebungswahl.self) { wahl in
                ZirkelUebungswahlSheet(wahl: wahl, eingebettet: true) { uebung in
                    fertig(wahl.station, uebung.exerciseId)
                }
                .environment(videoVorrat)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: beiAbbrechen)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .environment(videoVorrat)
        .presentationDragIndicator(.visible)
        .task { await bilderLaden() }
    }

    private var titel: String {
        switch zweck {
        case .tauschen: "Übung tauschen"
        case .hinzufuegen: "Übung hinzufügen"
        }
    }

    private func sperrgrund(_ station: Station, _ uebungId: String) -> String? {
        PlanUebungWahl.sperre(station: station, uebungId: uebungId, merkmale: merkmale, belegt: belegt)
            .map(PlanUebungWahl.text)
    }

    // MARK: - Wahl

    /// Ein Suchtreffer ueber eine Uebung meint genau sie; sonst entscheidet
    /// die Station: eine Uebung gleich, mehrere ueber "Welche Übung?" mit
    /// nur den freien. Gesperrtes tut nichts -- die Zeile ist ohnehin nicht
    /// tippbar, nur eine Kachel mit einem Geraet kommt hier vorbei.
    private func waehle(_ station: Station, _ uebungId: String?) {
        if let uebungId {
            guard sperrgrund(station, uebungId) == nil else { return }
            fertig(station, uebungId)
            return
        }
        guard let wahl = PlanUebungWahl.uebungswahl(station: station, merkmale: merkmale, belegt: belegt) else {
            return
        }
        if station.exercises.count == 1, let einzige = wahl.offen.first {
            fertig(station, einzige.exerciseId)
        } else {
            pfad.append(wahl)
        }
    }

    private func fertig(_ station: Station, _ exerciseId: String) {
        guard let modelId = PlanUebungWahl.modellId(station: station) else { return }
        let name = station.exercises.first { $0.id == exerciseId }?.name ?? "Übung"
        beiWahl(exerciseId, modelId, name)
    }

    // MARK: - Kopf beim Tauschen

    @ViewBuilder
    private var kopf: some View {
        if case .tauschen(let alt, let kandidaten) = zweck {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                duErsetzt(alt)
                if !kandidaten.isEmpty {
                    abschnittsTitel("PASST AN DIESE STELLE")
                    VStack(spacing: 0) {
                        ForEach(Array(kandidaten.enumerated()), id: \.element.id) { nummer, kandidat in
                            if nummer > 0 { Rectangle().fill(DesignSystem.Color.line).frame(height: 1) }
                            kandidatZeile(kandidat)
                        }
                    }
                }
                abschnittsTitel("ODER EINE ANDERE ÜBUNG")
                    .padding(.top, DesignSystem.Spacing.s8)
            }
        }
    }

    private func abschnittsTitel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.label)
            .tracking(1.2)
            .foregroundStyle(DesignSystem.Color.textFaint)
            .accessibilityAddTraits(.isHeader)
    }

    private func duErsetzt(_ alt: UebungskarteModell) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("DU ERSETZT")
                .font(DesignSystem.Typography.label)
                .tracking(1.2)
                .foregroundStyle(DesignSystem.Color.accent)
            HStack(spacing: DesignSystem.Spacing.s12) {
                UebungsVideoKachel(exerciseId: alt.exerciseId, kante: 48) {
                    PlanZeilenFoto(foto: alt.vorschaubildModell.flatMap { bilder[$0] }, kante: 48)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(alt.name)
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Sätze · Wdh bleiben")
                        .font(.system(size: 12.5))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.accentMuted)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.accentDim, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func kandidatZeile(_ kandidat: TauschKandidat) -> some View {
        Button {
            beiWahl(kandidat.exerciseId, kandidat.modelId, kandidat.name)
        } label: {
            HStack(spacing: DesignSystem.Spacing.s12) {
                UebungsVideoKachel(exerciseId: kandidat.exerciseId) {
                    PlanZeilenFoto(foto: kandidat.vorschaubildModell.flatMap { bilder[$0] })
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kandidat.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if !kandidat.untertitel.isEmpty {
                        Text(kandidat.untertitel)
                            .font(.system(size: 12.5))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([kandidat.name, kandidat.untertitel].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    /// Vorschaubilder nur fuer den Kopf -- die Geraeteliste laedt ihre selbst.
    private func bilderLaden() async {
        guard case .tauschen(let alt, let kandidaten) = zweck else { return }
        let modelle = ([alt.vorschaubildModell] + kandidaten.map(\.vorschaubildModell)).compactMap { $0 }
        guard !modelle.isEmpty else { return }
        let fotos = await GeraeteFotos.laden(von: fotoLader)
        for modell in modelle {
            guard bilder[modell] == nil, let url = fotos[modell] else { continue }
            bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
        }
    }
}
