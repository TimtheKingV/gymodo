#if DEBUG
import Sensorik
import SwiftUI

/// Diagnose und Ratentest (Spec 7.2). Bewusst eine schlichte Form aus
/// Systembausteinen: das Blatt ist Werkzeug und folgt keinem Artboard.
struct SensorDiagnoseBlatt: View {
    let station: String

    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @Environment(\.dismiss) private var schliessen
    @State private var befestigung = ""

    var body: some View {
        let s = koordinator.statistik
        NavigationStack {
            Form {
                Section("Verbindung") {
                    zeile("Sensor", koordinator.quelle.zustand.name ?? "–")
                    zeile("Akku", koordinator.quelle.zustand.akkuProzent.map { "\($0) %" } ?? "–")
                    if let seit = koordinator.verbundenSeit {
                        zeile("Verbunden seit", seit.formatted(date: .omitted, time: .standard))
                    }
                }
                Section("Was am iPhone ankommt") {
                    zeile("Ist-Rate (letzte Sekunde)", "\(Int(koordinator.anzeigeRateHz)) Hz")
                    zeile("Ist-Rate (gesamt)", "\(s.rateIstHz) Hz")
                    zeile("Abstand Median", "\(s.abstandMs.median) ms")
                    zeile("Abstand p95", "\(s.abstandMs.p95) ms")
                    zeile("Abstand Maximum", "\(s.abstandMs.max) ms")
                    zeile("Pakete", "\(s.pakete)")
                    zeile("Lücken", "\(s.luecken)")
                    zeile("Verworfene Bytes", "\(s.verworfeneBytes)")
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
                            .disabled(!koordinator.quelle.zustand.istVerbunden)
                    }
                    if let datei = koordinator.letzterRatentest {
                        zeile("Geschrieben", datei.lastPathComponent)
                    }
                }
                Section {
                    TextField("z. B. Gewichtsstapel oben", text: $befestigung)
                        .onSubmit { koordinator.befestigungSetzen(befestigung, fuer: station) }
                } header: {
                    Text("Befestigung an diesem Gerät")
                } footer: {
                    Text("Gilt ab der nächsten Aufnahme. Ohne diese Angabe lassen sich die Aufnahmen später nicht gruppieren.")
                }
                Section {
                    Button("Sensor vergessen", role: .destructive) {
                        koordinator.quelle.vergessen()
                        schliessen()
                    }
                }
            }
            .navigationTitle("Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fertig") { schliessen() } }
            .onAppear { befestigung = koordinator.befestigung(fuer: station) }
            // Auch ohne Return: wer das Blatt schliesst, meint den Text so.
            .onDisappear { koordinator.befestigungSetzen(befestigung, fuer: station) }
        }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        LabeledContent(titel) { Text(wert).monospacedDigit() }
    }
}
#endif
