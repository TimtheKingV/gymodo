import SwiftUI
import UIKit

/// Der Kopf der Auswahl "Andere Übung wählen" (Entwurf 3): "STATT <NAME>",
/// "PASSEND ZUM PLAN" mit den Kandidaten des Bausteins und die ruhige Zeile
/// "Ohne Ersatz auslassen". Steht im Kopfinhalt von `GeraeteAuswahlView`; die
/// normalen Kacheln und die Suche darunter waehlen jede andere Uebung.
///
/// Keine Akzentflaeche: die Zeilen sind Text und Umriss.
struct PlanErsatzKopf: View {
    let auftrag: PlanTauschAuftrag
    let fotoLader: any GeraetefotosLoading
    let vorschauLader: VorschauLader
    let beiKandidat: (TauschKandidat) -> Void
    let beiOhneErsatz: () -> Void

    @State private var bilder: [String: UIImage] = [:]

    /// Was heute dran war: der Ersatz eines frueheren Tauschs, sonst die Planuebung.
    private var alt: String { auftrag.ersatzName ?? auftrag.name }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("Statt \(alt)".uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.2)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !auftrag.kandidaten.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PASSEND ZUM PLAN")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.2)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .padding(.bottom, DesignSystem.Spacing.s4)
                    ForEach(Array(auftrag.kandidaten.enumerated()), id: \.element.id) { index, kandidat in
                        if index > 0 {
                            Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                        }
                        zeile(kandidat)
                    }
                }
            }
            Button(action: beiOhneErsatz) {
                Text("Ohne Ersatz auslassen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("\(alt) heute nicht machen")
        }
        .task {
            guard !auftrag.kandidaten.isEmpty else { return }
            let fotos = await GeraeteFotos.laden(von: fotoLader)
            for kandidat in auftrag.kandidaten {
                guard let modell = kandidat.vorschaubildModell, bilder[modell] == nil,
                      let url = fotos[modell] else { continue }
                bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
            }
        }
    }

    private func zeile(_ kandidat: TauschKandidat) -> some View {
        Button { beiKandidat(kandidat) } label: {
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
        .accessibilityHint("Wählen")
        .accessibilityAddTraits(.isButton)
    }
}
