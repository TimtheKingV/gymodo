import SwiftUI

/// Texte rund um einen Flow, gemeinsam fuer Liste, Detail und Lauf.
enum FlowAnzeige {
    /// "20 min"; mindestens eine Minute.
    static func minuten(_ dauerS: Int) -> String {
        "\(max(1, Int((Double(dauerS) / 60).rounded()))) min"
    }

    static func level(_ level: String?) -> String? {
        switch level {
        case "einsteiger": "Einsteiger"
        case "mittel": "Mittel"
        case "fortgeschritten": "Fortgeschritten"
        default: nil
        }
    }

    /// "20 min · 12 Schritte · Einsteiger"
    static func meta(_ flow: Flow) -> String {
        let schritte = flow.schritte.count == 1 ? "1 Schritt" : "\(flow.schritte.count) Schritte"
        return [minuten(flow.dauerS), schritte, level(flow.level)].compactMap { $0 }.joined(separator: " · ")
    }

    /// "m:ss"
    static func uhr(_ sekunden: Int) -> String {
        String(format: "%d:%02d", sekunden / 60, sekunden % 60)
    }
}

/// Die Liste der Follow-along-Flows im Training-Tab. Besitzt den FlowStore
/// (Cache, offene Runs) fuer Liste, Detail und Lauf.
struct FlowListeView: View {
    @State private var store: FlowStore

    init(apiClient: APIClient) {
        _store = State(initialValue: FlowStore(loader: apiClient, dateiStore: FlowFileStore()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                if store.flows.isEmpty {
                    Text("Noch keine Flows verfügbar.")
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                } else {
                    ForEach(store.flows) { flow in
                        NavigationLink {
                            FlowDetailView(flow: flow, store: store)
                        } label: {
                            zeile(flow)
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s16)
        }
        .background(DesignSystem.Color.bg)
        .navigationTitle("Flows")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Zuerst alte Runs nachsenden, dann den Katalog auffrischen.
            await store.offeneRunsSenden()
            await store.laden()
        }
    }

    private func zeile(_ flow: Flow) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(flow.titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(FlowAnzeige.meta(flow))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.line, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
