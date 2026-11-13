import SwiftUI
import UIKit

/// "Ersetzen" beim Bearbeiten einer Einheit (Entwurf 2b, E5): nur die
/// Kandidaten des Bausteins (`PlanTausch.kandidaten`), denn der Server tauscht
/// nur innerhalb desselben Bausteins. Die Wahl schreibt sofort eine neue
/// Planversion; das Schreiben selbst macht der Aufrufer.
///
/// Keine Akzentflaeche: die Zeilen sind Text, wie in `PlanErsatzKopf`.
struct PlanEinheitErsatzSheet: View {
    /// Name der Uebung, die ersetzt wird.
    let alt: String
    let kandidaten: [TauschKandidat]
    let fotoLader: any GeraetefotosLoading
    let vorschauLader: VorschauLader
    /// `nil` = geschrieben, der Aufrufer schliesst das Blatt; sonst der Fehler.
    let beiKandidat: (TauschKandidat) async -> APIError?
    let beiAbbrechen: () -> Void

    @State private var bilder: [String: UIImage] = [:]
    @State private var schreibt = false
    @State private var fehler: APIError?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                Text("Statt \(alt)".uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.2)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let fehler {
                    InlineBanner(tone: .danger, message: PlanTausch.fehlerText(fehler))
                }
                if kandidaten.isEmpty {
                    Text("Für diese Stelle gibt es gerade keine passende Übung.")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("PASST AN DIESE STELLE")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.2)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(kandidaten.enumerated()), id: \.element.id) { nummer, kandidat in
                            if nummer > 0 { Rectangle().fill(DesignSystem.Color.line).frame(height: 1) }
                            zeile(kandidat)
                        }
                    }
                }
                PlanLeiserKnopf(titel: "Abbrechen", aktiv: !schreibt, aktion: beiAbbrechen)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, DesignSystem.Spacing.s8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Color.surface)
        .interactiveDismissDisabled(schreibt)
        .task {
            guard !kandidaten.isEmpty else { return }
            let fotos = await GeraeteFotos.laden(von: fotoLader)
            for kandidat in kandidaten {
                guard let modell = kandidat.vorschaubildModell, bilder[modell] == nil,
                      let url = fotos[modell] else { continue }
                bilder[modell] = await vorschauLader.bild(modellId: modell, url: url, kantePixel: 168)
            }
        }
    }

    private func zeile(_ kandidat: TauschKandidat) -> some View {
        Button {
            guard !schreibt else { return }
            schreibt = true
            Task {
                let ergebnis = await beiKandidat(kandidat)
                fehler = ergebnis
                schreibt = false
            }
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
        .disabled(schreibt)
        .opacity(schreibt ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([kandidat.name, kandidat.untertitel].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint("Ersetzt \(alt) dauerhaft in dieser Einheit")
        .accessibilityAddTraits(.isButton)
    }
}
