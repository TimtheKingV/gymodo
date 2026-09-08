import SwiftUI

/// Sheet statt Push: der Geraete-Screen bleibt dahinter sichtbar, weil sich
/// die Aktion auf ihn bezieht (Artboard-Kommentar).
struct UebungWechselnSheet: View {
    let modell: GeraetModel
    let beiWechsel: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    Text("\(modell.maschine.equipmentModel.name) · \(modell.maschine.label)")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)

                    ForEach(modell.uebungen) { uebung in
                        Button {
                            beiWechsel(uebung.id)
                            dismiss()
                        } label: {
                            zeile(uebung)
                        }
                        .buttonStyle(PressButtonStyle())
                    }

                    Text("Ein Wechsel öffnet einen neuen Block im Training. Deine bisherigen Sätze bleiben erhalten — du kannst jederzeit zurück.")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Übung wechseln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ uebung: GeraetUebung) -> some View {
        let laeuft = uebung.id == modell.uebungId
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(untertitel(uebung, laeuft: laeuft))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(laeuft ? DesignSystem.Color.surfaceRaised : DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }

    /// Drei Zustaende, nicht ein pauschales "laeuft"/"zuletzt": die laufende
    /// Zeile nennt Satzzahl und Gewicht, weil beides schon feststeht; jede
    /// andere Zeile mit Historie nennt Gewicht und Alter, damit erkennbar
    /// ist, wie verlaesslich die Zahl noch ist, bevor man die Scheiben
    /// auflegt (GeraetUebungWechseln.dc.html).
    private func untertitel(_ uebung: GeraetUebung, laeuft: Bool) -> String {
        if laeuft {
            // satzNummer ist der naechste Index, nicht die Anzahl bisheriger
            // Saetze -- und nur fuer die aktive Uebung ueberhaupt sinnvoll,
            // also genau diese Zeile.
            let saetze = modell.satzNummer - 1
            var teile = ["läuft"]
            if saetze > 0 {
                teile.append(saetze == 1 ? "1 Satz" : "\(saetze) Sätze")
            }
            teile.append(Zahlformat.gewichtMitEinheit(modell.gewicht))
            return teile.joined(separator: " · ")
        }
        if let gewicht = modell.letztesGewicht(fuer: uebung.id) {
            let zuletzt = altersangabe(fuer: uebung.id).map { "zuletzt \($0)" } ?? "zuletzt"
            return "\(Zahlformat.gewichtMitEinheit(gewicht)) · \(zuletzt)"
        }
        return "Noch nie trainiert · Ziel \(uebung.targetRepsMin) – \(uebung.targetRepsMax) Wdh."
    }

    /// "heute" statt "vor 0 Tagen" -- Letzteres liest sich wie ein
    /// Rechenfehler. nil ohne Historie oder wenn sich das Datum nicht
    /// parsen laesst; die Zeile zeigt dann nur das Gewicht.
    private func altersangabe(fuer uebungId: String) -> String? {
        guard let tage = modell.letzteNutzungInTagen(fuer: uebungId) else { return nil }
        if tage <= 0 { return "heute" }
        return tage == 1 ? "vor 1 Tag" : "vor \(tage) Tagen"
    }
}
