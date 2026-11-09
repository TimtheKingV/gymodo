#if DEBUG
import Sensorik
import SwiftUI

/// Die Zeile "Tracker" in "BEIM TRAINING" (Paket 3, F4). Eigene View, weil
/// nur sie die Sensor-Koordinatoren aus dem Environment braucht -- die gibt
/// es nur im Debug-Build.
struct TrackerProfilZeile: View {
    @Environment(SensorAufnahmeKoordinator.self) private var koordinator

    var body: some View {
        let quelle = koordinator.quelle
        NavigationLink {
            TrackerEinrichtungView()
        } label: {
            LabeledContent("Tracker") {
                Text(ProfilZeilen.trackerWert(hatGemerktenSensor: quelle.hatGemerktenSensor, zustand: quelle.zustand))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
        .testnotizElement("profil.tracker", typ: "NavigationLink")
    }
}

/// Der Tracker wird einmal im Profil eingerichtet (Paket 3, F4): verbinden,
/// bei mehreren Funden waehlen, vergessen, die Automatik an oder aus. Im
/// Training steht davon nur noch der Status. Darunter "Für Entwickler" --
/// das fruehere Diagnoseblatt (Spec 7.2), raus aus dem Training, aber fuer
/// die Erkennungsarbeit noch da. Bewusst eine schlichte Form aus
/// Systembausteinen.
struct TrackerEinrichtungView: View {
    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @Environment(ZaehlerKoordinator.self) private var zaehler
    @Environment(CatalogStore.self) private var katalog
    @Environment(\.openURL) private var oeffnen

    @State private var vergessenFragen = false
    /// Station, fuer die die Freitext-Befestigung gerade bearbeitet wird.
    @State private var station: String?
    @State private var befestigung = ""

    var body: some View {
        let zustand = koordinator.quelle.zustand
        let gemerkt = koordinator.quelle.hatGemerktenSensor
        let aktion = TrackerAnzeige.einrichtungsAktion(zustand, hatGemerktenSensor: gemerkt)
        Form {
            Section {
                status(zustand)
                aktionsknopf(aktion)
            }
            if case let .auswaehlen(funde) = aktion {
                Section("Tracker wählen") {
                    ForEach(funde) { fund in
                        Button("\(SensorName.anzeige(fund.name)) · \(fund.rssi) dBm") {
                            koordinator.quelle.waehlen(fund)
                        }
                    }
                    Button("Abbrechen") { koordinator.quelle.trennen() }
                }
            }
            Section {
                Toggle("Sätze automatisch starten und sichern", isOn: Binding(
                    get: { zaehler.automatikAktiv }, set: { zaehler.automatikAktiv = $0 }))
                    .testnotizElement("tracker.automatik", typ: "Toggle")
            }
            if gemerkt {
                Section {
                    Button("Tracker vergessen", role: .destructive) { vergessenFragen = true }
                        .testnotizElement("tracker.vergessen", typ: "Button")
                }
            }
            fuerEntwickler(zustand)
        }
        .tint(DesignSystem.Color.accent)
        .navigationTitle("Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Tracker vergessen?", isPresented: $vergessenFragen, titleVisibility: .visible) {
            Button("Tracker vergessen", role: .destructive) { koordinator.quelle.vergessen() }
        } message: {
            Text("Der Tracker wird getrennt und im Training nicht mehr angezeigt, bis du ihn wieder verbindest.")
        }
        // Auch ohne Return: wer die Einrichtung verlaesst, meint den Text so.
        .onDisappear { befestigungSichern() }
    }

    // MARK: - Status und Knopf

    private func status(_ zustand: SensorZustand) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "sensor.fill")
                .foregroundStyle(TrackerAnzeige.symbol(zustand) == .verbunden
                    ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(zustand.name.map(SensorName.anzeige) ?? SensorName.trackerName)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(TrackerAnzeige.status(zustand))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func aktionsknopf(_ aktion: TrackerAnzeige.Aktion) -> some View {
        switch aktion {
        case .verbinden:
            Button("Tracker verbinden") { koordinator.quelle.verbinden() }
                .testnotizElement("tracker.verbinden", typ: "Button")
        case .einstellungenOeffnen:
            Button("In Einstellungen erlauben") {
                if let url = URL(string: UIApplication.openSettingsURLString) { oeffnen(url) }
            }
            .testnotizElement("tracker.einstellungen", typ: "Button")
        case .auswaehlen, .keine:
            EmptyView()
        }
    }

    // MARK: - Für Entwickler (frueher das Diagnoseblatt im Training)

    @ViewBuilder
    private func fuerEntwickler(_ zustand: SensorZustand) -> some View {
        let s = koordinator.statistik
        Section {
            if let seit = koordinator.verbundenSeit {
                zeile("Verbunden seit", seit.formatted(date: .omitted, time: .standard))
            }
            zeile("Ist-Rate (letzte Sekunde)", "\(Int(koordinator.anzeigeRateHz)) Hz")
            zeile("Ist-Rate (gesamt)", "\(s.rateIstHz) Hz")
            zeile("Abstand Median", "\(s.abstandMs.median) ms")
            zeile("Abstand p95", "\(s.abstandMs.p95) ms")
            zeile("Abstand Maximum", "\(s.abstandMs.max) ms")
            zeile("Pakete", "\(s.pakete)")
            zeile("Lücken", "\(s.luecken)")
            zeile("Verworfene Bytes", "\(s.verworfeneBytes)")
        } header: {
            Text("Für Entwickler")
        } footer: {
            Text("Was am iPhone ankommt.")
        }
        Section("Rate am Sensor") {
            Picker("Soll-Rate", selection: Binding(
                get: { koordinator.quelle.rate },
                set: { koordinator.rateSetzen($0) })) {
                ForEach(SensorRate.allCases, id: \.self) { Text("\($0.rawValue) Hz").tag($0) }
            }
            .pickerStyle(.segmented)
        }
        Section("5-Minuten-Test") {
            if let rest = koordinator.ratentestRest {
                zeile("Läuft", "noch \(rest / 60):\(String(format: "%02d", rest % 60))")
            } else {
                Button("Test starten") { koordinator.ratentestStarten() }
                    .disabled(!zustand.istVerbunden)
            }
            if let datei = koordinator.letzterRatentest {
                zeile("Geschrieben", datei.lastPathComponent)
            }
        }
        Section {
            Picker("Gerät", selection: Binding(
                get: { station },
                set: { neu in
                    befestigungSichern()
                    station = neu
                    befestigung = neu.map { koordinator.befestigung(fuer: $0) } ?? ""
                })) {
                Text("–").tag(String?.none)
                ForEach(stationen) { Text($0.label).tag(Optional($0.schluessel)) }
            }
            if station != nil {
                TextField("z. B. Gewichtsstapel oben", text: $befestigung)
                    .onSubmit { befestigungSichern() }
            }
        } header: {
            Text("Befestigung je Gerät")
        } footer: {
            Text("Gilt ab der nächsten Aufnahme. Ohne diese Angabe lassen sich die Aufnahmen später nicht gruppieren.")
        }
    }

    /// Die Geraete des aktuellen Orts, wie in der Geraeteauswahl.
    private var stationen: [Station] {
        katalog.bootstrap.map { GeraeteAuswahl.stationen(bootstrap: $0, ort: katalog.ort) } ?? []
    }

    private func befestigungSichern() {
        guard let station else { return }
        koordinator.befestigungSetzen(befestigung, fuer: station)
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        LabeledContent(titel) { Text(wert).monospacedDigit() }
    }
}
#endif
