import AVFoundation
import SwiftUI

/// Titel, Eckdaten und die Schrittliste eines Flows; "Starten" oeffnet den
/// Lauf als Vollbild (kein versehentliches Zurueckwischen mitten im Training).
struct FlowDetailView: View {
    let flow: Flow
    let store: FlowStore

    @Environment(CatalogStore.self) private var katalog
    @Environment(UebungsVideoVorrat.self) private var videos
    @State private var laeuft = false
    /// Einmal gebaut (der Katalog wird dabei durchlaufen), nicht je Auswertung der View.
    @State private var uebungen: FlowUebungen?
    /// Videos der ersten Schritte, schon vor dem Start vorbereitet.
    @State private var vorgeladen: [String: AVAsset] = [:]

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
            PrimaryButton(title: "Starten") { _ = bereit(); laeuft = true }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s8)
                .background(DesignSystem.Color.bg)
        }
        .fullScreenCover(isPresented: $laeuft) {
            FlowLaufView(flow: flow, store: store, uebungen: bereit(), videos: videos, vorgeladen: vorgeladen)
        }
        .task { await vorladen() }
    }

    private func bereit() -> FlowUebungen {
        if let uebungen { return uebungen }
        #if DEBUG
        let neu = FlowUebungen(bootstrap: katalog.bootstrap, testprofile: KameraTestprofile.aktiv)
        #else
        let neu = FlowUebungen(bootstrap: katalog.bootstrap, testprofile: false)
        #endif
        uebungen = neu
        return neu
    }

    /// Bereitet die Videos von Countdown und erstem Schritt vor, solange das
    /// Mitglied noch die Liste ansieht; der Lauf zeigt sie dann von Anfang an.
    private func vorladen() async {
        let uebungen = bereit()
        for i in FlowVideoPlan.benoetigteSchritte(phase: .countdown, anzahl: flow.schritte.count) {
            let schritt = flow.schritte[i]
            guard let id = schritt.exerciseId, vorgeladen[id] == nil,
                  uebungen.ansicht(schritt, mitKamera: true) != .ring else { continue }
            if Task.isCancelled { return }
            if let asset = await FlowVideoStand.laden(exerciseId: id, videos: videos) { vorgeladen[id] = asset }
        }
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
