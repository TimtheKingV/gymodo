import SwiftUI

/// Titel, Eckdaten und die Schrittliste eines Flows; "Starten" oeffnet den
/// Lauf als Vollbild (kein versehentliches Zurueckwischen mitten im Training).
struct FlowDetailView: View {
    let flow: Flow
    let store: FlowStore

    @Environment(CatalogStore.self) private var katalog
    @Environment(UebungsVideoVorrat.self) private var videos
    @State private var laeuft = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(flow.titel)
                        .font(DesignSystem.Typography.detailScreentitel)
                        .foregroundStyle(DesignSystem.Color.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(FlowAnzeige.meta(flow))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                if let beschreibung = flow.beschreibung, !beschreibung.isEmpty {
                    Text(beschreibung)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(flow.schritte.enumerated()), id: \.element.id) { index, schritt in
                            if index > 0 { Divider().overlay(DesignSystem.Color.line) }
                            zeile(schritt)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.s12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s16)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Starten") { laeuft = true }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s8)
                .background(DesignSystem.Color.bg)
        }
        .fullScreenCover(isPresented: $laeuft) {
            FlowLaufView(flow: flow, store: store, uebungen: uebungen, videos: videos)
        }
    }

    private var uebungen: FlowUebungen {
        #if DEBUG
        FlowUebungen(bootstrap: katalog.bootstrap, testprofile: KameraTestprofile.aktiv)
        #else
        FlowUebungen(bootstrap: katalog.bootstrap, testprofile: false)
        #endif
    }

    private func zeile(_ schritt: FlowSchritt) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Text("\(schritt.position)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(schritt.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(zeiten(schritt))
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func zeiten(_ schritt: FlowSchritt) -> String {
        var teile = ["\(schritt.workS) s Arbeit"]
        if schritt.restS > 0 { teile.append("\(schritt.restS) s Pause") }
        if schritt.istWarmup { teile.append("Aufwärmen") }
        return teile.joined(separator: " · ")
    }
}
