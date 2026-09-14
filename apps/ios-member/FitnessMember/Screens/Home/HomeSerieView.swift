import SwiftUI

/// Was von der Auswahl gemerkt wird.
///
/// Drei Faelle statt eines `String?`, weil "noch nichts angetippt" und
/// "bewusst zugeklappt" zwei verschiedene Dinge sind: der erste faellt
/// auf den juengsten Trainingstag zurueck, der zweite bleibt leer.
enum HomeSerieAuswahl: Equatable {
    case vorgabe
    case tag(String)
    case keiner
}

/// Der Kalender am Kopf des Home-Tabs -- Flamme, Wochenstreifen, die
/// Einheiten des gewaehlten Tages, ein Umschalter auf den Monat.
///
/// **Nur ein Trainingstag ist antippbar.** Ein Tag ohne Einheit tut
/// nichts -- er hat nichts zu zeigen. Er oeffnete eine Zeit lang
/// stattdessen den Monat, und das war beim Benutzen schlicht verwirrend:
/// dieselbe Geste schlug je nach Tag in zwei verschiedene Richtungen
/// aus, ohne dass man vorher sah, in welche. Auf den Monat fuehrt jetzt
/// genau eine Stelle, und die steht sichtbar darunter.
///
/// **Er ist der Zugang zum Verlauf.** Die fruehere Liste "Letzte
/// Trainings" ist weggefallen: sie zeigte dieselben Karten noch einmal,
/// nur nach Datum statt nach Tag geordnet, und ein Tag mit zwei
/// Einheiten stand darin zweimal mit derselben Ueberschrift. Wer eine
/// Einheit sucht, tippt jetzt ihren Tag an.
///
/// **Zwei Kanaele an der Tageszelle, und nur zwei.** Die FUELLUNG sagt,
/// was der Tag ist (nichts, trainiert, gewaehlt), der RING sagt heute.
/// Weil sie getrennt sind, kollidiert kein Zustand mit einem anderen --
/// ein Tag kann zugleich heute, trainiert und gewaehlt sein, und alle
/// drei bleiben lesbar. Der Akzent bleibt dabei eine Linie, keine
/// Flaeche: designsystem.md SS2 laesst genau eine Akzentflaeche je
/// Screen zu, und die traegt hier die Flamme.
///
/// **Die Flamme steht ueber dem Streifen, nicht darin.** Sie sass links
/// neben den Tagen und nahm ihnen 68 pt -- sieben Zellen auf 282 pt
/// standen so dicht, dass der Streifen gestaucht wirkte. Jetzt hat er
/// die volle Breite, und die Fussnote fuellt die Zeile neben der Flamme,
/// die sonst leer bliebe.
struct HomeSerieView: View {
    let stand: Serienstand
    let gesamt: Int
    let lastSessionAt: String?
    /// Vom Aufrufer, damit der Streifen keine eigene Uhr hat und in
    /// einer Vorschau ein fester Tag vorgegeben werden kann.
    let jetzt: Date
    /// Die abgeschlossenen Einheiten nach Ortstag -- gebuendelt vom
    /// Aufrufer (`HomeSerie.einheitenJeTag`), damit dieser View die
    /// Zeitzone des Studios nicht kennen muss.
    let einheitenJeTag: [String: [SessionSummary]]
    let beiAuswahl: (String) -> Void

    @State private var auswahl: HomeSerieAuswahl = .vorgabe
    @State private var monatOffen = false

    var body: some View {
        let trainingstage = HomeSerie.trainingstage(
            stand: stand, einheitenJeTag: einheitenJeTag)
        let wochentage = HomeSerie.tage(stand, trainingstage: trainingstage)
        let gewaehlt = gewaehlterTag(wochentage: wochentage)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("DEINE SERIE")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            kopfzeile(wochentage)

            if monatOffen {
                monatsgitter(trainingstage: trainingstage, gewaehlt: gewaehlt)
            } else {
                wochenstreifen(wochentage, gewaehlt: gewaehlt)
            }

            if let gewaehlt, let einheiten = einheitenJeTag[gewaehlt], !einheiten.isEmpty {
                tagesliste(tagId: gewaehlt, einheiten: einheiten)
            }

            umschalter
        }
        .animation(DesignSystem.Motion.oeffnen, value: monatOffen)
        .animation(DesignSystem.Motion.oeffnen, value: gewaehlt)
    }
}

// MARK: - Auswahl

private extension HomeSerieView {
    /// Der Tag, der tatsaechlich ausgeklappt ist.
    ///
    /// Der gemerkte gilt nur, solange er noch Einheiten traegt: der
    /// Verlauf wird bei jedem Erscheinen des Tabs neu geladen, und ein
    /// Tag, der dabei aus der gedeckelten Liste faellt, haette sonst eine
    /// leere Ueberschrift ohne Karten darunter. Derselbe Rueckfall wie
    /// `KurseWochenBerechnung.gueltigerTag`.
    func gewaehlterTag(wochentage: [HomeSerieTag]) -> String? {
        switch auswahl {
        case .keiner:
            return nil
        case .tag(let id):
            return hatEinheiten(id) ? id : vorgabe(wochentage)
        case .vorgabe:
            return vorgabe(wochentage)
        }
    }

    /// Der juengste Trainingstag der laufenden Woche -- was der Screen
    /// zeigt, bevor jemand etwas antippt.
    ///
    /// Nicht "nichts": mit "Letzte Trainings" ist die Stelle weggefallen,
    /// an der die letzte Einheit ohne Zutun stand, und ein Home-Tab, der
    /// den Verlauf erst nach einem Tap hergibt, hat ihn versteckt.
    func vorgabe(_ wochentage: [HomeSerieTag]) -> String? {
        wochentage.reversed().first { hatEinheiten($0.id) }?.id
    }

    func hatEinheiten(_ tagId: String) -> Bool {
        !(einheitenJeTag[tagId] ?? []).isEmpty
    }

    /// Antippbar ist nur, was etwas zu zeigen hat: ein Tag mit Einheiten,
    /// und keiner aus einem Nachbarmonat. Alles andere ist gar kein
    /// Knopf -- VoiceOver liest es als Text, nicht als Bedienelement, und
    /// niemand tippt ins Leere.
    func istWaehlbar(_ tag: HomeSerieTag) -> Bool {
        hatEinheiten(tag.id) && !tag.ausserhalb
    }

    /// Derselbe Tag noch einmal klappt ihn wieder zu.
    func auswaehlen(_ tag: HomeSerieTag, gewaehlt: String?) {
        auswahl = gewaehlt == tag.id ? .keiner : .tag(tag.id)
    }
}

// MARK: - Kopfzeile

private extension HomeSerieView {
    /// Gedeckt bei einer Serie von null -- die Zahl bleibt trotzdem
    /// stehen. Sie ist die Antwort auf "wie lange schon", und "0" ist
    /// eine Antwort; die Flamme sagt ueber die Farbe, dass gerade nichts
    /// laeuft.
    var laeuft: Bool { stand.weeks > 0 }

    func kopfzeile(_ wochentage: [HomeSerieTag]) -> some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            flamme
                // Die Tageszellen sind einzeln bedienbar und tragen ihr
                // eigenes Label. Dieser Satz beantwortet die Woche
                // trotzdem auf einmal, ohne dass VoiceOver sieben
                // Elemente durchlaufen muss.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    HomeSerie.vorlesetext(wochen: stand.weeks, tage: wochentage))

            Text(
                HomeSerie.fussnote(
                    gesamt: gesamt, lastSessionAt: lastSessionAt,
                    jetzt: jetzt, kalender: .current)
            )
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }

    var flamme: some View {
        VStack(spacing: DesignSystem.Spacing.s4) {
            HStack(spacing: DesignSystem.Spacing.s4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(
                        laeuft ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
                Text("\(stand.weeks)")
                    .font(.system(size: 27, weight: .black).monospacedDigit())
                    .foregroundStyle(
                        laeuft ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
            }
            Text(HomeSerie.wochenLabel(stand.weeks).uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(
                    laeuft ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
        }
        .frame(width: 56)
    }
}

// MARK: - Woche und Monat

private extension HomeSerieView {
    func wochenstreifen(_ tage: [HomeSerieTag], gewaehlt: String?) -> some View {
        // Abstand 0 und gleich breite Spalten: die Zelle ist 40 pt, die
        // Spalte auf einem 390er Screen 50 -- die 10 pt Luft entstehen
        // aus der Spaltenbreite, nicht aus einem Abstand, und bleiben
        // damit auf jedem Geraet im selben Verhaeltnis.
        HStack(spacing: 0) {
            ForEach(tage) { tag in
                if istWaehlbar(tag) {
                    Button {
                        auswaehlen(tag, gewaehlt: gewaehlt)
                    } label: {
                        wochenzelle(tag, gewaehlt: gewaehlt)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel(tagLabel(tag))
                    .accessibilityHint("Zeigt die Einheiten des Tages.")
                    .accessibilityAddTraits(tag.id == gewaehlt ? .isSelected : [])
                } else {
                    wochenzelle(tag, gewaehlt: gewaehlt)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tagLabel(tag))
                }
            }
        }
    }

    func monatsgitter(trainingstage: Set<String>, gewaehlt: String?) -> some View {
        let anker = gewaehlt ?? stand.today
        let tage = HomeSerie.monatstage(
            um: anker, heute: stand.today, trainingstage: trainingstage)
        let spalten = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(HomeSerie.monatstitel(anker).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            // Der Buchstabe steht hier einmal als Spaltenkopf statt an
            // jeder Zelle -- ueber sechs Zeilen waere er sechsmal
            // dasselbe Wort.
            LazyVGrid(columns: spalten, spacing: DesignSystem.Spacing.s8) {
                ForEach(Array(tage.prefix(7).enumerated()), id: \.offset) { _, tag in
                    Text(tag.buchstabe)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                .accessibilityHidden(true)

                ForEach(tage) { tag in
                    if istWaehlbar(tag) {
                        Button {
                            auswaehlen(tag, gewaehlt: gewaehlt)
                        } label: {
                            monatszelle(tag, gewaehlt: gewaehlt)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressButtonStyle())
                        .accessibilityLabel(tagLabel(tag))
                        .accessibilityHint("Zeigt die Einheiten des Tages.")
                        .accessibilityAddTraits(tag.id == gewaehlt ? .isSelected : [])
                    } else {
                        monatszelle(tag, gewaehlt: gewaehlt)
                            .accessibilityElement(children: .ignore)
                            .accessibilityHidden(tag.ausserhalb)
                            .accessibilityLabel(tagLabel(tag))
                    }
                }
            }
        }
    }

    /// Die Zelle mit ihrem Buchstaben -- die Trefferflaeche ist die ganze
    /// Spalte, nicht der Kreis: 40 pt allein blieben unter den 44 aus
    /// designsystem.md SS4.
    func wochenzelle(_ tag: HomeSerieTag, gewaehlt: String?) -> some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            buchstabe(tag, istGewaehlt: tag.id == gewaehlt)
            zelle(tag, istGewaehlt: tag.id == gewaehlt)
        }
        .frame(maxWidth: .infinity)
    }

    func monatszelle(_ tag: HomeSerieTag, gewaehlt: String?) -> some View {
        zelle(tag, istGewaehlt: tag.id == gewaehlt)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
    }

    func buchstabe(_ tag: HomeSerieTag, istGewaehlt: Bool) -> some View {
        Text(tag.buchstabe)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(buchstabenfarbe(tag, istGewaehlt: istGewaehlt))
    }

    /// Die Hantel ERSETZT die Tagesnummer, sie steht nicht daneben. Der
    /// Streifen beantwortet auf einen Blick "an welchen Tagen", und dafuer
    /// muss die Antwort die groesste Form in der Zelle sein.
    func zelle(_ tag: HomeSerieTag, istGewaehlt: Bool) -> some View {
        ZStack {
            Circle().fill(fuellung(tag, istGewaehlt: istGewaehlt))

            if tag.trainiert {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
            } else {
                Text("\(tag.tagesnummer)")
                    .font(.system(size: 16, weight: .black).monospacedDigit())
                    .foregroundStyle(
                        tag.istHeute ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint)
            }
        }
        .frame(width: 40, height: 40)
        // strokeBorder statt stroke: der Ring liegt INNEN und laesst die
        // Zelle 40 pt breit, sonst sprungen die Spalten um den heutigen
        // Tag herum auseinander.
        .overlay(
            Circle().strokeBorder(
                DesignSystem.Color.accent, lineWidth: tag.istHeute ? 1.5 : 0))
        .opacity(tag.ausserhalb ? 0.4 : 1)
    }

    func fuellung(_ tag: HomeSerieTag, istGewaehlt: Bool) -> Color {
        if istGewaehlt { return DesignSystem.Color.line }
        if tag.trainiert { return DesignSystem.Color.surfaceRaised }
        return .clear
    }

    func buchstabenfarbe(_ tag: HomeSerieTag, istGewaehlt: Bool) -> Color {
        if istGewaehlt { return DesignSystem.Color.text }
        if tag.trainiert || tag.istHeute { return DesignSystem.Color.textMuted }
        return DesignSystem.Color.textFaint
    }
}

// MARK: - Die Einheiten des Tages

private extension HomeSerieView {
    func tagesliste(tagId: String, einheiten: [SessionSummary]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(HomeSerie.tagestitel(tagId).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(einheiten) { einheit in
                Button {
                    beiAuswahl(einheit.id)
                } label: {
                    tageskarte(einheit)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    func tageskarte(_ einheit: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(HomeZeilen.kartenTitel(einheit))
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()

            HStack(spacing: DesignSystem.Spacing.s8) {
                if einheit.completedReason == "auto" {
                    Text("AUTO BEENDET")
                        .font(DesignSystem.Typography.label)
                        .foregroundStyle(DesignSystem.Color.warn)
                        .padding(.horizontal, DesignSystem.Spacing.s8)
                        .padding(.vertical, DesignSystem.Spacing.s4)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.pille)
                                .stroke(DesignSystem.Color.warn, lineWidth: 1))
                }
                Text(HomeZeilen.zeilenText(einheit))
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }
}

// MARK: - Umschalter

private extension HomeSerieView {
    /// Kein Rahmen und keine volle Breite: ein 48 pt hoher Umriss quer
    /// ueber den Screen wog schwerer als die Karten darueber, um die es
    /// eigentlich geht. Uebrig bleibt das Wort und ein Winkel darunter,
    /// rechtsbuendig unter dem Streifen -- der Winkel zeigt in die
    /// Richtung, in die der Kalender geht.
    ///
    /// Die 44 pt aus designsystem.md SS4 traegt die Trefferflaeche, nicht
    /// die Schrift: sichtbar sind rund 28, antippbar der ganze Streifen
    /// rechts.
    var umschalter: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                monatOffen.toggle()
            } label: {
                VStack(spacing: DesignSystem.Spacing.s4) {
                    Text(monatOffen ? "Wochenansicht" : "Monatsansicht")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: monatOffen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignSystem.Color.textMuted)
                .padding(.leading, DesignSystem.Spacing.s24)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
        }
    }
}

// MARK: - VoiceOver

private extension HomeSerieView {
    func tagLabel(_ tag: HomeSerieTag) -> String {
        var teile = ["\(tag.wochentagVoll), \(tag.tagesnummer)."]
        if tag.istHeute { teile.append("Heute.") }

        switch (einheitenJeTag[tag.id] ?? []).count {
        case 0:
            // Ein Tag, den der Server als trainiert nennt, dessen Einheit
            // aber in keiner Buendelung steht, hat noch kein Ende --
            // sie laeuft gerade im Training-Tab.
            teile.append(tag.trainiert ? "Training läuft." : "Kein Training.")
        case 1:
            teile.append("Eine Einheit.")
        case let anzahl:
            teile.append("\(anzahl) Einheiten.")
        }
        return teile.joined(separator: " ")
    }

}

// MARK: - Vorschau

/// Fester Tag statt `Date()`: sonst wanderte der Ring jeden Tag eine
/// Zelle weiter und die Vorschau zeigte je nach Wochentag etwas anderes.
#Preview {
    func einheit(_ id: String, _ start: String, _ ende: String) -> SessionSummary {
        SessionSummary(
            id: id, startedAt: start, completedAt: ende, completedReason: "manual",
            machineCount: 3, setCount: 8, blocks: [])
    }

    return ScrollView {
        HomeSerieView(
            stand: Serienstand(
                weeks: 3, weekStart: "2026-09-07", today: "2026-09-11",
                trainedDays: ["2026-09-07", "2026-09-09", "2026-09-11"]),
            gesamt: 34,
            lastSessionAt: "2026-09-11T16:51:00Z",
            jetzt: Date(timeIntervalSince1970: 1_789_050_000),
            einheitenJeTag: HomeSerie.einheitenJeTag(
                [
                    einheit("a", "2026-09-11T16:04:00Z", "2026-09-11T16:51:00Z"),
                    einheit("b", "2026-09-11T05:12:00Z", "2026-09-11T05:38:00Z"),
                    einheit("c", "2026-09-09T15:48:00Z", "2026-09-09T16:39:00Z"),
                    einheit("d", "2026-09-07T16:12:00Z", "2026-09-07T16:55:00Z"),
                    einheit("e", "2026-09-05T08:04:00Z", "2026-09-05T08:58:00Z"),
                    einheit("f", "2026-09-03T15:55:00Z", "2026-09-03T16:41:00Z"),
                    einheit("g", "2026-09-01T16:20:00Z", "2026-09-01T17:05:00Z"),
                ],
                zeitzone: "Europe/Berlin"),
            beiAuswahl: { _ in })
        .padding(.horizontal, 20)
        .padding(.vertical, DesignSystem.Spacing.s24)
    }
    .background(DesignSystem.Color.bg)
}
