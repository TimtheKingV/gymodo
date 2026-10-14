#if DEBUG
import SwiftUI
import Sensorik

/// Eine Zeile ueber den Raedern, nur im Debug-Build (Spec 7.1). Kostet 44 pt,
/// die der Satzpfad auf einem 667-pt-iPhone nicht uebrig hat -- im
/// Debug-Build scrollt die Seite dort deshalb. Das ist hingenommen: die
/// Zeile ist Werkzeug, kein Produkt.
struct SensorZeile: View {
    let station: String

    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @Environment(ZaehlerKoordinator.self) private var zaehler
    @State private var diagnoseOffen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sensorZeile
            // Nur mit offenem Satz: in Pause und Abschluss gibt es nichts zu zaehlen.
            if let text = Self.zaehlerText(meldung: zaehler.meldung) { zaehlerZeile(text) }
        }
    }

    /// Sensor-Spec B 6.7 und Nachtrag 14.10. Punkt 2: Art (oder Vorschlag)
    /// mit einem Tipp aenderbar, daneben der Stand.
    private func zaehlerZeile(_ text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Menu {
                ForEach(Befestigungsart.allCases, id: \.self) { art in
                    Button(Self.artName(art)) { zaehler.befestigungWaehlen(art) }
                }
            } label: {
                Text(Self.befestigungText(zaehler.befestigung))
                    .font(.system(size: 13).weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.text)
            }
            // Ohne Art sagt das Menue schon "Befestigung wählen"; doppelt waere Rauschen.
            if zaehler.meldung != .zaehltNicht(.keineBefestigung) {
                Text(text)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(Self.istPruefen(zaehler.meldung)
                        ? DesignSystem.Color.danger : DesignSystem.Color.textMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(minHeight: 44)
    }

    private var sensorZeile: some View {
        let zustand = koordinator.quelle.zustand
        return Button(action: tippen) {
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
        .sheet(isPresented: $diagnoseOffen) { SensorDiagnoseBlatt(station: station) }
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

    nonisolated static func artName(_ art: Befestigungsart) -> String {
        switch art {
        case .stapel: "Stapel"
        case .langhantel: "Langhantel"
        case .kurzhantel: "Kurzhantel"
        case .hebelarm: "Hebelarm"
        case .kabelgriff: "Kabelgriff"
        case .koerper: "Körper"
        }
    }

    nonisolated static func befestigungText(_ wahl: BefestigungsWahl?) -> String {
        guard let wahl else { return "Befestigung wählen" }
        return wahl.quelle == .vorschlag ? "\(artName(wahl.art)) (Vorschlag)" : artName(wahl.art)
    }

    nonisolated static func zaehlerText(meldung: ZaehlerMeldung?) -> String? {
        switch meldung {
        case nil: nil
        case .bereit: "zählt"
        case .stand(let n): "zählt · \(n)"
        case .pruefen(let n, let grund): "Zahl prüfen · \(n) (\(grundText(grund)))"
        case .zaehltNicht(.keinSensor): "zählt nicht: kein Sensor"
        case .zaehltNicht(.keineWiederholungen): "zählt hier nicht: keine Wiederholungen"
        case .zaehltNicht(.keineBefestigung): "Befestigung wählen"
        case .zaehltNicht(.nichtFreigegeben): "zählt hier noch nicht"
        }
    }

    nonisolated static func istPruefen(_ meldung: ZaehlerMeldung?) -> Bool {
        if case .pruefen? = meldung { return true }
        return false
    }

    private nonisolated static func grundText(_ grund: UnsicherGrund) -> String {
        switch grund {
        case .luecke: "Lücke"
        case .signalSchwach: "Signal schwach"
        case .taktUnregelmaessig: "Takt unregelmäßig"
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
