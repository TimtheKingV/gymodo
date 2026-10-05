import Charts
import SwiftUI

/// Uebungsfortschritt.dc.html -- das einzige Diagramm in M1
/// (designsystem.md SS13). Swift Charts, keine externe Abhaengigkeit.
struct UebungsfortschrittView: View {
    let exerciseId: String

    @Environment(VerlaufStore.self) private var verlauf
    @State private var fenster: Fortschrittsfenster = .dreiMonate

    private var uebung: ExerciseProgress? {
        verlauf.fortschritt.first { $0.id == exerciseId }
    }

    var body: some View {
        ScrollView {
            if let uebung {
                let punkte = fenster.punkte(uebung.points, jetzt: Date())

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf(uebung)
                    umschalter
                    diagramm(punkte, uebung: uebung)
                    rohwerte(punkte, uebung: uebung)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            } else {
                Text("Diese Übung steht nicht mehr im Verlauf.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s48)
            }
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["exerciseId": exerciseId])
    }

    private func kopf(_ uebung: ExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(uebung.machineLabel)
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)
            Text(uebung.exerciseName)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.textMuted)

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
                Text(Zahlformat.belastungMitEinheit(uebung.currentLoad, uebung.loadUnit))
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(HomeZeilen.veraenderung(uebung.changeLoad, einheit: uebung.loadUnit))
                    .font(DesignSystem.Typography.wertSekundaer)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(Zahlformat.belastungGesprochen(uebung.currentLoad, uebung.loadUnit)), Veränderung \(HomeZeilen.veraenderung(uebung.changeLoad, einheit: uebung.loadUnit)) \(Zahlformat.einheitGesprochen(uebung.loadUnit))")
        }
    }

    private var umschalter: some View {
        FensterUmschalter(fenster: $fenster)
    }

    /// Wie der Gewichtsverlauf: senkrechte Striche mit Datum, der letzte
    /// Eintrag auf zwei Dritteln, ab drei Punkten geschwungen (Testnotiz
    /// 05.10., #2, #3, #6) -- zwei Diagramme derselben Art lesen sich
    /// gleich.
    private func diagramm(_ punkte: [ExerciseProgress.Point], uebung: ExerciseProgress) -> some View {
        let yBereich = Fortschrittsfenster.achsenbereich(punkte.map(\.topLoad))
        let daten = punkte.map { datum(von: $0.performedOn) }
        let linie: InterpolationMethod = Zeitachse.geschwungen(anzahl: punkte.count) ? .monotone : .linear

        return Chart(punkte, id: \.performedOn) { punkt in
            RuleMark(
                x: .value("Datum", datum(von: punkt.performedOn)),
                yStart: .value("Belastung", yBereich.lowerBound),
                yEnd: .value("Belastung", punkt.topLoad)
            )
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(DesignSystem.Color.line)
            .accessibilityHidden(true)

            LineMark(
                x: .value("Datum", datum(von: punkt.performedOn)),
                y: .value("Belastung", punkt.topLoad)
            )
            .interpolationMethod(linie)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(DesignSystem.Color.accent)

            PointMark(
                x: .value("Datum", datum(von: punkt.performedOn)),
                y: .value("Belastung", punkt.topLoad)
            )
            .symbolSize(64)
            .foregroundStyle(DesignSystem.Color.accent)
            // Direkte Beschriftung NUR an Anfang und Ende (SS13) -- an
            // jedem Punkt waere sie Rauschen, und Text traegt Textfarben,
            // nie die Serienfarbe.
            .annotation(position: .top) {
                if punkt.performedOn == punkte.first?.performedOn
                    || punkt.performedOn == punkte.last?.performedOn {
                    Text(Zahlformat.belastung(punkt.topLoad, uebung.loadUnit))
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .monospacedDigit()
                }
            }
        }
        .chartYScale(domain: yBereich)
        .chartXScale(domain: Zeitachse.bereich(daten) ?? Zeitachse.leererBereich)
        // Achsenbeschriftung in text-faint (SS13), Kurzform "9. Jul". Die
        // Marken stehen genau an den Eintraegen, unter ihrem Strich; zu
        // dichte Beschriftungen laesst .greedy weg.
        .chartXAxis {
            AxisMarks(values: daten) {
                AxisValueLabel(
                    format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE")),
                    collisionResolution: .greedy
                )
                .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(DesignSystem.Color.line)
                AxisValueLabel()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: 200)
        // Geraet UND Uebung im Label (designsystem.md SS12, woertlich
        // "Verlauf Beinpresse, Beidbeinig") -- sonst kann
        // VoiceOver auf einem Screen mit mehreren Uebungen nicht sagen,
        // auf welcher Kurve es steht.
        .accessibilityLabel("Verlauf \(uebung.machineLabel), \(uebung.exerciseName)")
    }

    /// Die Plattform misst nichts -- die Kurve ist eine Zusammenfassung
    /// und muss nachpruefbar bleiben (SS13). Diese Liste ist zugleich die
    /// Wertetabelle, die VoiceOver als Alternative zur Kurve braucht
    /// (SS12).
    private func rohwerte(_ punkte: [ExerciseProgress.Point], uebung: ExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("SCHWERSTER BESTÄTIGTER SATZ JE TRAININGSTAG")
                .font(DesignSystem.Typography.label)
                .kerning(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(punkte.reversed(), id: \.performedOn) { punkt in
                HStack {
                    Text(datum(punkt.performedOn))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    Spacer()
                    Text(Zahlformat.belastungMitEinheit(punkt.topLoad, uebung.loadUnit))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(Zahlformat.malUmfang(punkt.volume, uebung.volumeKind))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .font(DesignSystem.Typography.fliesstext)
                .monospacedDigit()
            }
        }
    }

    /// Mittag UTC, wie `GewichtsverlaufHilfen.datum`.
    private func datum(von performedOn: String) -> Date {
        Zeitpunkt.parse("\(performedOn)T12:00:00Z") ?? Date()
    }

    /// "Donnerstag, 27. August" statt der rohen ISO-Form -- dieselbe
    /// Formatierung wie ueberall sonst im Verlauf (Zahlformat), kein
    /// drittes Datumsformat fuer dieselbe Angabe.
    private func datum(_ performedOn: String) -> String {
        guard let tag = Zeitpunkt.parse("\(performedOn)T12:00:00Z") else { return performedOn }
        return Zahlformat.wochentagDatum(tag)
    }
}
