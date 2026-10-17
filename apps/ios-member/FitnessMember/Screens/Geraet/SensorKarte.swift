#if DEBUG
import SwiftUI
import Sensorik

/// Der Sensor als Karte (Testnotiz 15.10., #5): Name, Akku, verbunden oder
/// nicht. Dieselbe Karte steht ueber der Geraeteauswahl und an jeder
/// Uebung, damit man den Sensor schon vor dem ersten Satz verbindet. Die
/// Hz-Zahl gehoert nicht in die Karte, sie steht im Diagnoseblatt.
///
/// Der Tipp bleibt wie bei der Zeile davor (SensorZeile.tippen):
/// verbinden, abbrechen, Auswahl, Diagnose, Einstellungen.
struct SensorKarte: View {
    /// An einer Uebung: das Geraet, fuer das das Diagnoseblatt die
    /// Befestigung speichert. Auf der Auswahl nil -- dort gibt es kein Geraet,
    /// und ein verbundener Sensor oeffnet nichts.
    let station: String?

    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @State private var diagnoseOffen = false
    /// Kurz nach dem Tipp zeigt die Karte "Wird gesucht" (Testnotiz 17.10.,
    /// #1); sonst steht dort dauerhaft "Nicht verbunden", obwohl im
    /// Hintergrund weiter gesucht und automatisch verbunden wird.
    @State private var suchtKurz = false
    nonisolated static let suchAnzeigeDauer: Duration = .seconds(3)

    /// Was die Karte sagt, ohne Hz. Pur, damit pruefbar.
    struct Anzeige: Equatable {
        enum Ton { case verbunden, ruhig, warnung }
        var titel: String
        var untertitel: String
        var akku: Int?
        var ton: Ton
    }

    nonisolated static func anzeige(zustand: SensorZustand, fehler: String? = nil, suchtKurz: Bool = false) -> Anzeige {
        if let fehler { return Anzeige(titel: "Sensor", untertitel: fehler, akku: nil, ton: .warnung) }
        switch zustand {
        case .aus:
            return Anzeige(titel: "Sensor", untertitel: "Nicht verbunden · Tippen zum Verbinden", akku: nil, ton: .ruhig)
        case .sucht where !suchtKurz:
            return Anzeige(titel: "Sensor", untertitel: "Nicht verbunden", akku: nil, ton: .ruhig)
        case .sucht, .verbindet, .mehrereGefunden:
            return Anzeige(titel: "Sensor", untertitel: "Wird gesucht …", akku: nil, ton: .ruhig)
        case .verbunden(let name, let akku):
            return Anzeige(titel: name, untertitel: "Verbunden", akku: akku, ton: .verbunden)
        case .getrennt:
            return Anzeige(titel: "Sensor", untertitel: "Getrennt · wird neu verbunden …", akku: nil, ton: .warnung)
        case .bluetoothNichtBereit(.ausgeschaltet):
            return Anzeige(titel: "Sensor", untertitel: "Bluetooth ist ausgeschaltet", akku: nil, ton: .warnung)
        case .bluetoothNichtBereit(.verweigert):
            return Anzeige(titel: "Sensor", untertitel: "Bluetooth nicht erlaubt · Tippen für Einstellungen", akku: nil, ton: .warnung)
        case .bluetoothNichtBereit(.nichtUnterstuetzt):
            return Anzeige(titel: "Sensor", untertitel: "Dieses Gerät hat kein Bluetooth", akku: nil, ton: .warnung)
        }
    }

    var body: some View {
        let zustand = koordinator.quelle.zustand
        let a = Self.anzeige(zustand: zustand, fehler: koordinator.fehler, suchtKurz: suchtKurz)
        Button(action: tippen) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(a.ton == .verbunden ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(a.titel)
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                        .lineLimit(1)
                    Text(a.untertitel)
                        .font(.system(size: 13))
                        .foregroundStyle(a.ton == .warnung ? DesignSystem.Color.danger : DesignSystem.Color.textMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let akku = a.akku {
                    Label("\(akku) %", systemImage: akkuSymbol(akku))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(akku <= 15 ? DesignSystem.Color.danger : DesignSystem.Color.textMuted)
                }
            }
            .padding(DesignSystem.Spacing.s12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(DesignSystem.Color.surface,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(a.titel): \(a.untertitel)\(a.akku.map { ", Akku \($0) Prozent" } ?? "")")
        .testnotizElement("sensor.karte", typ: "Button")
        .sheet(isPresented: $diagnoseOffen) { SensorDiagnoseBlatt(station: station ?? "") }
        .sheet(isPresented: .constant(auswahl != nil)) { auswahlBlatt }
    }

    private func akkuSymbol(_ prozent: Int) -> String {
        switch prozent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
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
        case .sucht:
            // Nur die Anzeige wechselt kurz; die Suche laeuft weiter.
            suchtKurz = true
            Task {
                try? await Task.sleep(for: Self.suchAnzeigeDauer)
                suchtKurz = false
            }
        case .verbindet: koordinator.quelle.trennen()
        case .bluetoothNichtBereit(.verweigert):
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .bluetoothNichtBereit: koordinator.quelle.verbinden()
        case .verbunden, .getrennt: if station != nil { diagnoseOffen = true }
        case .mehrereGefunden: break
        }
    }
}
#endif
