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
                    diagramm(punkte)
                    rohwerte(punkte)
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
                Text(Zahlformat.gewichtMitEinheit(uebung.currentWeightKg))
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(HomeZeilen.veraenderung(uebung.changeKg))
                    .font(DesignSystem.Typography.wertSekundaer)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(Zahlformat.gewichtGesprochen(uebung.currentWeightKg)), Veränderung \(HomeZeilen.veraenderung(uebung.changeKg)) Kilogramm")
        }
    }

    /// Der Akzent markiert hier den aktiven Wert -- der Screen hat keine
    /// Hauptaktion, und es bleibt bei genau EINER Akzentflaeche (SS2).
    private var umschalter: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(Fortschrittsfenster.allCases) { wahl in
                Button(wahl.titel) { fenster = wahl }
                    .font(DesignSystem.Typography.label)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(height: 44)
                    .background(wahl == fenster ? DesignSystem.Color.accent : DesignSystem.Color.surface)
                    .foregroundStyle(wahl == fenster ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.pille))
            }
        }
    }

    private func diagramm(_ punkte: [ExerciseProgress.Point]) -> some View {
        Chart(punkte, id: \.performedOn) { punkt in
            LineMark(
                x: .value("Datum", Zeitpunkt.parse("\(punkt.performedOn)T12:00:00Z") ?? Date()),
                y: .value("Gewicht", punkt.topWeightKg)
            )
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(DesignSystem.Color.accent)

            PointMark(
                x: .value("Datum", Zeitpunkt.parse("\(punkt.performedOn)T12:00:00Z") ?? Date()),
                y: .value("Gewicht", punkt.topWeightKg)
            )
            .symbolSize(64)
            .foregroundStyle(DesignSystem.Color.accent)
            // Direkte Beschriftung NUR an Anfang und Ende (SS13) -- an
            // jedem Punkt waere sie Rauschen, und Text traegt Textfarben,
            // nie die Serienfarbe.
            .annotation(position: .top) {
                if punkt.performedOn == punkte.first?.performedOn
                    || punkt.performedOn == punkte.last?.performedOn {
                    Text(Zahlformat.gewicht(punkt.topWeightKg))
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .monospacedDigit()
                }
            }
        }
        .chartYScale(domain: Fortschrittsfenster.achsenbereich(punkte))
        // Achsenbeschriftung in text-faint (SS13) -- eine andere Regel als
        // die direkte Beschriftung an den Datenpunkten oben: beide stehen
        // nebeneinander. Kurzform "9. Jul", keine Wochentage -- die
        // ausgeschriebene Form gehoert der Rohwerteliste unter dem
        // Diagramm. Keine feste Anzahl von Marken erzwungen: Swift Charts
        // waehlt sie passend zur Spannweite, ein fester Wert wuerde sie
        // bei einem kurzen oder langen Zeitraum falsch platzieren.
        .chartXAxis {
            AxisMarks {
                AxisGridLine().foregroundStyle(DesignSystem.Color.line)
                AxisValueLabel(
                    format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE"))
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
        .accessibilityLabel("Gewichtsverlauf")
    }

    /// Die Plattform misst nichts -- die Kurve ist eine Zusammenfassung
    /// und muss nachpruefbar bleiben (SS13). Diese Liste ist zugleich die
    /// Wertetabelle, die VoiceOver als Alternative zur Kurve braucht
    /// (SS12).
    private func rohwerte(_ punkte: [ExerciseProgress.Point]) -> some View {
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
                    Text(Zahlformat.gewichtMitEinheit(punkt.topWeightKg))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("× \(punkt.reps)")
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .font(DesignSystem.Typography.fliesstext)
                .monospacedDigit()
            }
        }
    }

    /// "Donnerstag, 27. August" statt der rohen ISO-Form -- dieselbe
    /// Formatierung wie ueberall sonst im Verlauf (Zahlformat), kein
    /// drittes Datumsformat fuer dieselbe Angabe.
    private func datum(_ performedOn: String) -> String {
        guard let tag = Zeitpunkt.parse("\(performedOn)T12:00:00Z") else { return performedOn }
        return Zahlformat.wochentagDatum(tag)
    }
}
