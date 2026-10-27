#if DEBUG
import SwiftUI
import Sensorik

/// Eine Zeile ueber den Raedern, nur im Debug-Build (Spec 7.1). Kostet 44 pt,
/// die der Satzpfad auf einem 667-pt-iPhone nicht uebrig hat -- im
/// Debug-Build scrollt die Seite dort deshalb. Das ist hingenommen: die
/// Zeile ist Werkzeug, kein Produkt.
struct SensorZeile: View {
    let station: String

    @Environment(ZaehlerKoordinator.self) private var zaehler
    @Environment(SensorAufnahmeKoordinator.self) private var aufnahme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Debug-Zeile "Sensor verbinden" wurde zur SensorKarte (Testnotiz 15.10., #5).
            if Funktionen.sensorKarte { SensorKarte(station: station) }
            if zaehler.automatikAktiv, zaehler.befestigung != nil {
                Text(automatikText)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            // Nur mit offenem Satz: in Pause und Abschluss gibt es nichts zu zaehlen.
            if let text = Self.zaehlerText(meldung: zaehler.meldung) { zaehlerZeile(text) }
            if aufnahme.aufnahmeLaeuft { markenZeile }
        }
    }

    private var automatikText: String {
        guard zaehler.quelle.zustand.istVerbunden else { return "Automatik wartet auf den Sensor" }
        switch zaehler.automatik.zustand {
        case .wartet: return "Automatik bereit · zwei Wiederholungen starten"
        case .startkandidat: return "Satzstart wird geprüft"
        case .laeuft:
            if let rest = zaehler.automatik.speichernIn {
                return "Sichern nach Ruhe · \(Int(ceil(rest))) s"
            }
            return "Automatik wartet auf Messwerte"
        case .satzende: return "Satz wird gesichert …"
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
                    .lineLimit(3)
            }
            Spacer()
        }
        .frame(minHeight: 44)
    }

    /// Satzgrenzen fuer die Auswertung: nach dem Aufheben "Start", vor dem
    /// Ablegen "Ende". Ohne Tipp bleibt die Aufnahme wie bisher gueltig.
    private var markenZeile: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(SatzMarke.allCases, id: \.self) { marke in
                let gesetzt = aufnahme.marken.contains(marke)
                Button { aufnahme.markeSetzen(marke) } label: {
                    Text(Self.markeText(marke, gesetzt: gesetzt))
                        .font(.system(size: 13).weight(.semibold))
                        .foregroundStyle(gesetzt ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                        .padding(.horizontal, DesignSystem.Spacing.s12)
                        .frame(minHeight: 36)
                        .overlay(Capsule().stroke(DesignSystem.Color.textMuted, lineWidth: 1))
                }
                .disabled(gesetzt)
            }
            Spacer()
        }
        .frame(minHeight: 44)
    }

    nonisolated static func markeText(_ marke: SatzMarke, gesetzt: Bool) -> String {
        switch (marke, gesetzt) {
        case (.satzbeginn, false): "Satz Start"
        case (.satzbeginn, true): "Start ✓"
        case (.satzende, false): "Satz Ende"
        case (.satzende, true): "Ende ✓"
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
        case .pruefen(let n, .luecke): "Verbindung unterbrochen – Zahl bitte prüfen · \(n)"
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
