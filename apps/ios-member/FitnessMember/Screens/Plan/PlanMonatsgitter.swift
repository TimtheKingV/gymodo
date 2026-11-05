import SwiftUI

/// Das Monatsgitter des Plan-Tabs -- herausgeloest aus dem Monat in
/// `HomeSerieView` (`monatsgitter`/`monatszelle`), der mit dem Kalender
/// hierher umzieht. Die Tage rechnet weiter `HomeSerie.monatstage` (volle
/// Wochen Mo-So, Nachbarmonate gedimmt), die Zelle ist `Kalenderzelle`;
/// darunter stehen dieselben Marken wie im Wochenstreifen.
///
/// Gerechnet wird mit Daten im Kalender des Plans (`PlanKalenderKontext`);
/// fuer `HomeSerie` werden sie zum Ortsdatum "yyyy-MM-dd" und zurueck.
struct PlanMonatsgitter<Marken: View>: View {
    /// Irgendein Tag des gezeigten Monats.
    let monat: Date
    let kalender: Calendar
    let heute: Date
    @ViewBuilder let marken: (Date) -> Marken
    let gewaehlt: Date?
    /// Tage ohne Daten (ausserhalb der wischbaren Wochen) sind kein Knopf.
    var waehlbar: (Date) -> Bool = { _ in true }
    /// Hantel statt Zahl wie im Streifen.
    var trainiert: (Date) -> Bool = { _ in false }
    /// VoiceOver-Label eines Tages.
    var label: (Date) -> String = { _ in "" }
    let beiTag: (Date) -> Void

    var body: some View {
        let ankerId = PlanMonatsgitterTage.tagId(monat, kalender: kalender)
        let tage = PlanMonatsgitterTage.tage(monat: monat, heute: heute, kalender: kalender)
        let spalten = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(HomeSerie.monatstitel(ankerId).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)

            // Der Buchstabe steht einmal als Spaltenkopf statt an jeder Zelle.
            LazyVGrid(columns: spalten, spacing: DesignSystem.Spacing.s8) {
                ForEach(Array(tage.prefix(7).enumerated()), id: \.offset) { _, tag in
                    Text(tag.zelle.buchstabe)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                .accessibilityHidden(true)

                ForEach(tage, id: \.zelle.id) { tag in
                    if !tag.zelle.ausserhalb && waehlbar(tag.datum) {
                        Button { beiTag(tag.datum) } label: {
                            zelle(tag).contentShape(Rectangle())
                        }
                        .buttonStyle(PressButtonStyle())
                        .accessibilityLabel(label(tag.datum))
                        .accessibilityHint("Zeigt den Tag in der Woche.")
                        .accessibilityAddTraits(istGewaehlt(tag.datum) ? .isSelected : [])
                    } else {
                        zelle(tag)
                            .accessibilityElement(children: .ignore)
                            .accessibilityHidden(tag.zelle.ausserhalb)
                            .accessibilityLabel(label(tag.datum))
                    }
                }
            }
        }
    }

    private func istGewaehlt(_ datum: Date) -> Bool {
        gewaehlt.map { kalender.isDate($0, inSameDayAs: datum) } ?? false
    }

    /// Die 44 pt traegt die Spalte, nicht der 40-pt-Kreis (designsystem.md SS4).
    private func zelle(_ tag: PlanMonatsgitterTage.Tag) -> some View {
        let hatTraining = !tag.zelle.ausserhalb && trainiert(tag.datum)
        return VStack(spacing: 6) {
            Kalenderzelle(
                inhalt: hatTraining ? .hantel : .zahl(tag.zelle.tagesnummer),
                istGewaehlt: istGewaehlt(tag.datum),
                istHeute: tag.zelle.istHeute,
                trainiert: hatTraining,
                gedeckt: tag.zelle.ausserhalb)
            marken(tag.datum)
                .opacity(tag.zelle.ausserhalb ? 0 : 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// Die Uebersetzung Plan-Kalender <-> `HomeSerie.monatstage`.
enum PlanMonatsgitterTage {
    struct Tag {
        let zelle: HomeSerieTag
        /// Tagesbeginn im Kalender des Plans.
        let datum: Date
    }

    static func tage(monat: Date, heute: Date, kalender: Calendar) -> [Tag] {
        let formatter = formatter(kalender)
        return HomeSerie.monatstage(
            um: formatter.string(from: monat), heute: formatter.string(from: heute), trainingstage: [])
            .compactMap { zelle in
                formatter.date(from: zelle.id).map { Tag(zelle: zelle, datum: kalender.startOfDay(for: $0)) }
            }
    }

    static func tagId(_ datum: Date, kalender: Calendar) -> String {
        formatter(kalender).string(from: datum)
    }

    /// en_US_POSIX fuer das feste Muster, Zeitzone des Plans.
    private static func formatter(_ kalender: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = kalender.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
