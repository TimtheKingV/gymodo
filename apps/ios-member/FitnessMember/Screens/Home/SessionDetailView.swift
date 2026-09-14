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
///
/// Der Screen zeigt ALLE Teile der angetippten Karte, nicht nur die
/// Einheit hinter der Id: eine Karte, die zwei Einheiten zusammenfasst,
/// darf nicht in ein Detail fuehren, das eine davon verschweigt -- die
/// Saetze der zweiten waeren sonst nirgends zu sehen. Die Teile kommen
/// aus derselben Faltung wie die Liste (`HomeZeilen.karte(fuer:in:)`),
/// damit Liste und Detail nie verschieden gruppieren.
///
/// Das Zusammenfassen bleibt reine ANZEIGE: die Teile stehen untereinander
/// und behalten ihre eigene Ueberschrift, in den Daten bleiben sie
/// getrennte Sessions -- kein Satz wird umgehaengt.
struct SessionDetailView: View {
    let sessionId: String

    @Environment(VerlaufStore.self) private var verlauf

    private var karte: Trainingskarte? {
        HomeZeilen.karte(fuer: sessionId, in: verlauf.sessions)
    }

    var body: some View {
        ScrollView {
            if let karte {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf(karte)
                    ForEach(karte.teile) { teil in
                        teilAbschnitt(teil, mitUeberschrift: karte.teile.count > 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            } else {
                // Der Verlauf wurde zwischenzeitlich geleert (Abmelden,
                // Kontowechsel). Kein Fehler, kein leerer Screen ohne Wort.
                Text("Diese Einheit steht nicht mehr im Verlauf. Auf Home steht, was gerade geladen ist.")
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

    /// Datum des aeltesten Teils, darunter dieselben zwei Zeilen wie auf
    /// der Karte: wer die Karte antippt, soll oben wiederfinden, was er
    /// angetippt hat, statt eine zweite Rechnung ueber dieselbe Sache.
    private func kopf(_ karte: Trainingskarte) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Zeitpunkt.parse(karte.teile[0].startedAt).map(Zahlformat.kurzerWochentagDatum) ?? "")
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)

            Text(HomeZeilen.grosseZeile(karte))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()

            Text(HomeZeilen.kleineZeile(karte))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()
        }
    }

    /// Die Bloecke eines Teils unter seiner Uhrzeit.
    ///
    /// Die Ueberschrift steht nur bei mehreren Teilen: bei einem einzigen
    /// truege sie nichts bei, was der Kopf nicht schon sagt. Ohne sie hat
    /// der Abschnitt ein einziges Kind -- der Screen sieht dann aus wie
    /// vor dem Zusammenfassen.
    private func teilAbschnitt(_ teil: SessionSummary, mitUeberschrift: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            if mitUeberschrift {
                Text(HomeZeilen.teilUeberschrift(teil).uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                ForEach(Array(teil.blocks.enumerated()), id: \.offset) { _, block in
                    blockKarte(block)
                }
            }
        }
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
        var label = "Satz \(satz.setIndex), \(Zahlformat.gewichtGesprochen(satz.weightKg)), \(Zahlformat.wiederholungenGesprochen(satz.reps))"
        if satz.problemFlag {
            label.append(", Problem gemeldet")
        }

        return HStack(spacing: DesignSystem.Spacing.s12) {
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

            if satz.problemFlag {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DesignSystem.Color.warn)
            }

            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
