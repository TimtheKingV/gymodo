import SwiftUI

/// SessionDetail.dc.html -- die Bloecke und Saetze einer Einheit.
///
/// Ohne eigenen Abruf: getSessions liefert die Bloecke mit, abgeleitet
/// aus den Saetzen und gruppiert nach (Geraet, Uebung). Ein zweiter
/// Durchgang am selben Geraet trifft denselben Block.
///
/// Ohne Vorschlaege: die gehoeren zum Abschluss. Fuer eine selbsttaetig
/// beendete Einheit existiert gar keine Vorschlagszeile (abschluss.ts),
/// ein Abschnitt dafuer bliebe hier bei jeder vergessenen Einheit leer.
struct SessionDetailView: View {
    let sessionId: String

    @Environment(VerlaufStore.self) private var verlauf

    private var einheit: SessionSummary? {
        verlauf.sessions.first { $0.id == sessionId }
    }

    var body: some View {
        ScrollView {
            if let einheit {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf(einheit)
                    ForEach(Array(einheit.blocks.enumerated()), id: \.offset) { _, block in
                        blockKarte(block)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            } else {
                // Der Verlauf wurde zwischenzeitlich geleert (Abmelden,
                // Kontowechsel). Kein Fehler, kein leerer Screen ohne Wort.
                Text("Diese Einheit steht nicht mehr im Verlauf.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s48)
            }
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kopf(_ einheit: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Zeitpunkt.parse(einheit.startedAt).map(Zahlformat.kurzerWochentagDatum) ?? "")
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)

            Text(untertitel(einheit))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()
        }
    }

    /// "18:04 – 18:51 · 47 min · 3 Geräte · 8 Sätze". Bei einer
    /// selbsttaetig beendeten Einheit entfallen Zeitraum und Dauer: ihr
    /// Ende liegt beim letzten Satz, nicht beim Ende des Trainings.
    private func untertitel(_ einheit: SessionSummary) -> String {
        var teile: [String] = []

        if einheit.completedReason != "auto",
           let start = Zeitpunkt.parse(einheit.startedAt),
           let endeIso = einheit.completedAt,
           let ende = Zeitpunkt.parse(endeIso) {
            teile.append("\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende))")
        }
        if let dauer = HomeZeilen.dauerText(einheit) { teile.append(dauer) }
        teile.append("\(einheit.machineCount) \(einheit.machineCount == 1 ? "Gerät" : "Geräte")")
        teile.append("\(einheit.setCount) \(einheit.setCount == 1 ? "Satz" : "Sätze")")

        return teile.joined(separator: " · ")
    }

    private func blockKarte(_ block: SessionSummary.Block) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack {
                Text("\(block.machineLabel) · \(block.exerciseName)")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer()
                Text("\(block.sets.count) \(block.sets.count == 1 ? "SATZ" : "SÄTZE")")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }

            ForEach(block.sets, id: \.setIndex) { satz in
                satzZeile(satz)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func satzZeile(_ satz: SessionSummary.Block.Set) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Text("\(satz.setIndex)")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(width: 16, alignment: .leading)

            Text(Zahlformat.gewichtMitEinheit(satz.weightKg))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()

            Text("× \(satz.reps)")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()

            // Nur wo eine Reserve erfasst wurde -- der Schalter im Profil
            // entscheidet ueber die ERFASSUNG, nicht rueckwirkend ueber
            // die Anzeige dessen, was schon gespeichert ist.
            if let rir = satz.rir {
                Text("RIR \(Int(rir))")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }

            if satz.problemFlag {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DesignSystem.Color.warn)
                    .accessibilityLabel("Problem gemeldet")
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Satz \(satz.setIndex), \(Zahlformat.gewichtGesprochen(satz.weightKg)), \(Zahlformat.wiederholungenGesprochen(satz.reps))")
    }
}
