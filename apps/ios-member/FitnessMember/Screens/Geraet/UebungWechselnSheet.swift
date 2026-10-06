import SwiftUI

/// Sheet statt Push: der Geraete-Screen bleibt dahinter sichtbar, weil sich
/// die Aktion auf ihn bezieht (Artboard-Kommentar). Seit der Testnotiz
/// 06.10. (#11, #12) erreichbar ueber "Übung abschließen" -> "Weitere Übung
/// an dem Gerät", nicht mehr ueber einen eigenen Knopf auf der Satzseite.
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

                    Text("Jede Übung bekommt ihren eigenen Block im Training. Deine bisherigen Sätze bleiben erhalten — du kannst jederzeit zurück.")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Weitere Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .testnotizScreen(kontext: ["machineId": modell.maschine.id])
    }

    /// Ohne Akzentbalken und ohne hervorgehobene Flaeche (Testnotiz 06.10.,
    /// #9): seit der Wechsel nach "Übung abschließen" kommt, ist die zuletzt
    /// laufende Uebung keine Auswahl mehr, die man markieren muesste. Links
    /// steht der Platz fuer das Sinnbild der Uebung, wie in der Liste auf
    /// "Gerät erkannt" (#3).
    private func zeile(_ uebung: GeraetUebung) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Uebungsbild()
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(untertitel(uebung))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }

    /// Drei Zustaende: Schon in dieser Einheit dran gewesen, dann die Saetze
    /// wie in der Blockliste des Trainings ("2 Sätze · 7,5 kg", Rueckfrage
    /// zur Testnotiz 06.10., #12). Sonst mit Historie Belastung und Alter,
    /// damit erkennbar ist, wie verlaesslich die Zahl noch ist, bevor man
    /// das Geraet danach einstellt (GeraetUebungWechseln.dc.html). Ohne
    /// Historie steht der Korridor in der Umfangsart der Uebung.
    private func untertitel(_ uebung: GeraetUebung) -> String {
        if let block = modell.blockInEinheit(fuer: uebung.id) {
            return "Heute · \(TrainingTab.blockzeile(block))"
        }
        if let belastung = modell.letzteBelastung(fuer: uebung.id) {
            let zuletzt = altersangabe(fuer: uebung.id).map { "zuletzt \($0)" } ?? "zuletzt"
            return "\(Zahlformat.belastungMitEinheit(belastung, modell.loadUnit)) · \(zuletzt)"
        }
        return "Noch nie trainiert · Ziel \(Zahlformat.korridorMitEinheit(uebung.targetMin, uebung.targetMax, uebung.volumeKind))"
    }

    /// "heute" statt "vor 0 Tagen" -- Letzteres liest sich wie ein
    /// Rechenfehler. nil ohne Historie oder wenn sich das Datum nicht
    /// parsen laesst; die Zeile zeigt dann nur die Belastung.
    private func altersangabe(fuer uebungId: String) -> String? {
        guard let tage = modell.letzteNutzungInTagen(fuer: uebungId) else { return nil }
        if tage <= 0 { return "heute" }
        return tage == 1 ? "vor 1 Tag" : "vor \(tage) Tagen"
    }
}
