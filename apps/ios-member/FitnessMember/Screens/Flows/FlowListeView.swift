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

/// Welcher Text die Liste ersetzt, solange es keine Flows gibt.
enum FlowListeInhalt: Equatable {
    case flows, laedt, fehler, leer

    static func von(flowsLeer: Bool, ladeZustand: FlowLadeZustand) -> FlowListeInhalt {
        guard flowsLeer else { return .flows }
        switch ladeZustand {
        case .idle, .laedt: return .laedt
        case .fehler: return .fehler
        case .geladen: return .leer
        }
    }
}

/// Die Liste der Follow-along-Flows im Training-Tab. Der FlowStore (Cache,
/// offene Runs) gehoert der App und kommt ueber die Umgebung.
struct FlowListeView: View {
    @Environment(FlowStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                switch FlowListeInhalt.von(flowsLeer: store.flows.isEmpty, ladeZustand: store.ladeZustand) {
                case .laedt:
                    HStack(spacing: DesignSystem.Spacing.s8) {
                        ProgressView().tint(DesignSystem.Color.accent)
                        Text("Lädt …")
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                case .fehler:
                    Text("Flows konnten nicht geladen werden. Bitte Verbindung prüfen.")
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                case .leer:
                    Text("Noch keine Flows verfügbar.")
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                case .flows:
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
            // Alte Runs sendet schon die App (Start, Aktivwerden, Netz); hier
            // genuegt der Katalog.
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
