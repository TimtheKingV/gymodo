#if DEBUG
import SwiftUI

/// Eine Zeile ueber den Raedern, nur im Debug-Build (Spec 7.1). Kostet 44 pt,
/// die der Satzpfad auf einem 667-pt-iPhone nicht uebrig hat -- im
/// Debug-Build scrollt die Seite dort deshalb. Das ist hingenommen: die
/// Zeile ist Werkzeug, kein Produkt.
struct SensorZeile: View {
    let machineId: String

    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @State private var diagnoseOffen = false

    var body: some View {
        let zustand = koordinator.quelle.zustand
        Button(action: tippen) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                if koordinator.aufnahmeLaeuft {
                    Circle().fill(DesignSystem.Color.danger).frame(width: 8, height: 8)
                        .accessibilityLabel("Aufnahme läuft")
                }
                Text(koordinator.fehler ?? Self.text(zustand: zustand, rateHz: koordinator.anzeigeRateHz))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(koordinator.fehler == nil
                        ? DesignSystem.Color.textMuted : DesignSystem.Color.danger)
                    .lineLimit(1)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $diagnoseOffen) { SensorDiagnoseBlatt(machineId: machineId) }
        .sheet(isPresented: .constant(auswahl != nil)) { auswahlBlatt }
    }

    private var auswahl: [SensorFund]? {
        if case .mehrereGefunden(let funde) = koordinator.quelle.zustand { return funde }
        return nil
    }

    private var auswahlBlatt: some View {
        NavigationStack {
            List(auswahl ?? []) { fund in
                Button("\(fund.name) · \(fund.rssi) dBm") { koordinator.quelle.waehlen(fund) }
            }
            .navigationTitle("Sensor wählen")
            .toolbar { Button("Abbrechen") { koordinator.quelle.trennen() } }
        }
        .presentationDetents([.medium])
    }

    private func tippen() {
        switch koordinator.quelle.zustand {
        case .aus: koordinator.quelle.verbinden()
        case .sucht, .verbindet: koordinator.quelle.trennen()
        case .bluetoothNichtBereit(.verweigert):
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .bluetoothNichtBereit: koordinator.quelle.verbinden()
        case .verbunden, .getrennt: diagnoseOffen = true
        case .mehrereGefunden: break
        }
    }

    nonisolated static func text(zustand: SensorZustand, rateHz: Double) -> String {
        switch zustand {
        case .aus: "Sensor verbinden"
        case .sucht, .verbindet, .mehrereGefunden: "Sensor wird gesucht …"
        case .verbunden(let name, let akku):
            // Komma wie ueberall in der App; Zahlformat.gewicht laesst ganze
            // Zahlen ohne Nachkommastelle, hier soll die Breite stillstehen.
            [name, String(format: "%.1f Hz", locale: Locale(identifier: "de_DE"), rateHz),
             akku.map { "\($0) %" }].compactMap { $0 }.joined(separator: " · ")
        case .getrennt: "Sensor getrennt, wird neu verbunden …"
        case .bluetoothNichtBereit(.ausgeschaltet): "Bluetooth ist ausgeschaltet"
        case .bluetoothNichtBereit(.verweigert): "Bluetooth ist für Gymtavo nicht erlaubt"
        case .bluetoothNichtBereit(.nichtUnterstuetzt): "Dieses Gerät hat kein Bluetooth"
        }
    }
}
#endif
