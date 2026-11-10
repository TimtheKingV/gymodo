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

/// Der Kalender am Kopf des Home-Tabs -- Flamme, Wochenstreifen mit den
/// Planmarken, die Trainingskarten des gewaehlten Tages. Die Monatsansicht
/// ist in den Plan-Tab gezogen (`PlanMonatsgitter`, Spec 1.1).
///
/// **Antippbar ist, was etwas zu zeigen hat** (`HomeSerie.tippZiel`): ein
/// vergangener Tag oder heute mit Einheit oder eigenem Kurs klappt ihn
/// darunter auf (und wieder zu); ein kuenftiger Tag mit Planmarke zeigt
/// seine Plantermine darunter (`beiPlanAuswahl`, E1) -- Home bleibt Home,
/// in den Plan geht es nur ueber "Im Plan". Ein Tag ohne beides tut nichts.
///
/// **Er ist der Zugang zum Verlauf.** Die fruehere Liste "Letzte
/// Trainings" ist weggefallen: sie zeigte dieselben Karten noch einmal,
/// nur nach Datum statt nach Tag geordnet, und ein Tag mit zwei
/// Einheiten stand darin zweimal mit derselben Ueberschrift. Wer eine
/// Einheit sucht, tippt jetzt ihren Tag an.
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
    /// Aus `Serienstand.weeklyTarget` (Aufgabe 8, R24) -- NICHT aus den
    /// Bootstrap-Zielen: „2 von 3 Tagen" braucht `trainedDays` und das
    /// Wochenziel aus demselben Abruf, sonst zeigt ein alter Cache das
    /// eine gegen das andere (Spec 4.5). `nil` blendet Label und Zeile
    /// vollstaendig aus -- die Serie bleibt unveraendert (nicht-
    /// verhandelbare Regel 1).
    let wochenziel: Int?
    let beiAuswahl: (String) -> Void
    /// Die eigenen bevorstehenden Kurse nach Ortstag (`HomeKurse.termineJeTag`),
    /// fuer den Punkt unter dem Tag und die Karte darunter (Testnotiz
    /// 06.10., #1).
    var kurseJeTag: [String: [GespeicherterTermin]] = [:]
    /// Frist und Zeitzone fuer die Kurskarte -- nil, solange keine
    /// Buchungen geladen sind; dann gibt es auch keine Kurse anzuzeigen.
    var kurseBuchungen: GespeicherteBuchungen? = nil
    /// Muskeln je Uebung (`HomeZeilen.muskelnJeUebung`) und Geschlecht der
    /// Figur: daraus entstehen Name und Mini-Figur der Trainingskarte.
    /// Ohne Katalog heisst die Karte "Training" und die Figur ist grau.
    var muskeln: [String: [GeraetMuskel]] = [:]
    var geschlecht: Geschlecht? = nil
    var beiKursAuswahl: (String) -> Void = { _ in }
    /// Planmarken je Tag ("yyyy-MM-dd", `HomeSerie.planMarken`); leer ohne Plan.
    var geplant: [String: PlanTagMarke.Art] = [:]
    /// Der gewaehlte Plantag (`HomeSerieTipp.planZeigen`): seine Tages-Id,
    /// der Aufrufer zeigt darunter dessen Termine. nil beim Zuklappen, bei
    /// Auswahl eines anderen Tages oder wenn der Tag seine Marke verliert.
    var beiPlanAuswahl: (String?) -> Void = { _ in }

    @State private var auswahl: HomeSerieAuswahl = .vorgabe

    var body: some View {
        let trainingstage = HomeSerie.trainingstage(
            stand: stand, einheitenJeTag: einheitenJeTag)
        let wochentage = HomeSerie.tage(stand, trainingstage: trainingstage, geplant: geplant)
        let gewaehlt = gewaehlterTag(wochentage: wochentage)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("DEINE SERIE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Spacer()
                if let wochenziel {
                    Text(HomeSerie.zielkopf(ziel: wochenziel).uppercased())
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .monospacedDigit()
                }
            }

            kopfzeile(wochentage)

            wochenstreifen(wochentage, gewaehlt: gewaehlt)
            if let wochenziel {
                zielzeile(wochentage, ziel: wochenziel)
            }

            if let gewaehlt, hatInhalt(gewaehlt) {
                tagesliste(tagId: gewaehlt,
                           einheiten: einheitenJeTag[gewaehlt] ?? [],
                           kurse: kurseJeTag[gewaehlt] ?? [])
            }
        }
        .animation(DesignSystem.Motion.oeffnen, value: gewaehlt)
        // Faellt die Auswahl zurueck (der Tag verliert seine Marke, die
        // Woche wechselt), steht sonst unten noch der alte Plantag.
        .onChange(of: planTag(gewaehlt, wochentage: wochentage)) { _, neu in
            if neu == nil { beiPlanAuswahl(nil) }
        }
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
            // Ein Plantag bleibt gewaehlt auch ohne Trainings oder Kurse:
            // er zeigt seine Termine unter dem Streifen (HomeRootView).
            return hatInhalt(id) || geplant[id] != nil ? id : vorgabe(wochentage)
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

    /// Einheiten oder eigene Kurse -- beides macht einen Tag antippbar.
    /// Die Vorgabe bleibt beim juengsten Trainingstag: ein Kurs in drei
    /// Tagen soll nicht die letzte Einheit verdraengen.
    func hatInhalt(_ tagId: String) -> Bool {
        hatEinheiten(tagId) || !(kurseJeTag[tagId] ?? []).isEmpty
    }

    /// Antippbar ist nur, was etwas zu zeigen hat (`HomeSerie.tippZiel`).
    /// Alles andere ist gar kein Knopf -- VoiceOver liest es als Text,
    /// nicht als Bedienelement, und niemand tippt ins Leere.
    func tippZiel(_ tag: HomeSerieTag) -> HomeSerieTipp? {
        HomeSerie.tippZiel(tag, heute: stand.today, hatInhalt: hatInhalt(tag.id))
    }

    /// Derselbe Tag noch einmal klappt ihn wieder zu. Ein Plantag meldet
    /// sich beim Aufrufer, jeder andere Tipp (zuklappen, vergangener Tag)
    /// meldet nil.
    func auswaehlen(_ tag: HomeSerieTag, gewaehlt: String?) {
        let zuklappen = gewaehlt == tag.id
        auswahl = zuklappen ? .keiner : .tag(tag.id)
        beiPlanAuswahl(!zuklappen && tippZiel(tag) == .planZeigen ? tag.id : nil)
    }

    /// Die gewaehlte Tages-Id, wenn sie ein Plantag ist; sonst nil.
    func planTag(_ gewaehlt: String?, wochentage: [HomeSerieTag]) -> String? {
        guard let gewaehlt, let tag = wochentage.first(where: { $0.id == gewaehlt }),
              tippZiel(tag) == .planZeigen else { return nil }
        return gewaehlt
    }
}

// MARK: - Kopfzeile

private extension HomeSerieView {
    /// Gedeckt bei einer Serie von null UND in einer Woche, die noch
    /// leer ist -- die Zahl bleibt beide Male stehen. Sie ist die Antwort
    /// auf "wie lange schon", und "0" wie "2" sind Antworten; die Flamme
    /// sagt ueber die Farbe etwas anderes, naemlich ob diese Woche schon
    /// etwas steht. Die Begruendung steht an `HomeSerie.serieLaeuft`.
    var laeuft: Bool { HomeSerie.serieLaeuft(stand) }

    func kopfzeile(_ wochentage: [HomeSerieTag]) -> some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            flamme
                // Die Tageszellen sind einzeln bedienbar und tragen ihr
                // eigenes Label. Dieser Satz beantwortet die Woche
                // trotzdem auf einmal, ohne dass VoiceOver sieben
                // Elemente durchlaufen muss.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    HomeSerie.vorlesetext(wochen: stand.weeks, tage: wochentage, ziel: wochenziel))

            Text(
                HomeSerie.fussnote(
                    gesamt: gesamt, lastSessionAt: lastSessionAt,
                    jetzt: jetzt, kalender: .current)
            )
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(DesignSystem.Color.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Woche

private extension HomeSerieView {
    func wochenstreifen(_ tage: [HomeSerieTag], gewaehlt: String?) -> some View {
        // Abstand 0 und gleich breite Spalten: die Zelle ist 40 pt, die
        // Spalte auf einem 390er Screen 50 -- die 10 pt Luft entstehen
        // aus der Spaltenbreite, nicht aus einem Abstand, und bleiben
        // damit auf jedem Geraet im selben Verhaeltnis.
        HStack(spacing: 0) {
            ForEach(tage) { tag in
                if let ziel = tippZiel(tag) {
                    Button {
                        auswaehlen(tag, gewaehlt: gewaehlt)
                    } label: {
                        wochenzelle(tag, gewaehlt: gewaehlt)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel(tagLabel(tag))
                    .accessibilityHint(ziel == .planZeigen ? "Zeigt die geplanten Termine des Tages." : "Zeigt Trainings und Kurse des Tages.")
                    .accessibilityAddTraits(tag.id == gewaehlt ? .isSelected : [])
                } else {
                    wochenzelle(tag, gewaehlt: gewaehlt)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tagLabel(tag))
                }
            }
        }
    }

    /// „2 von 3 Tagen diese Woche" -- eine zweite, unabhaengige Aussage
    /// neben der Serie (nicht-verhandelbare Regel 1): sie zaehlt dieselbe
    /// Menge, die der Streifen darueber schon faerbt, keine zweite Quelle.
    ///
    /// Der „Ziel erreicht"-Teil ist reiner Text in `textMuted`, ohne
    /// Akzent und ohne Animation -- die Flamme traegt den Akzent des
    /// Screens bereits, und ein Zustandswechsel hier ist kein Erfolg zum
    /// Feiern, nur eine Zaehlung (designsystem.md SS2, SS6).
    func zielzeile(_ wochentage: [HomeSerieTag], ziel: Int) -> some View {
        let trainiert = wochentage.filter(\.trainiert).count
        return HStack(spacing: DesignSystem.Spacing.s8) {
            Text(HomeSerie.zielzeile(trainiert: trainiert, ziel: ziel))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.textMuted)
            Spacer(minLength: 0)
            zielstriche(trainiert: trainiert, ziel: ziel)
                // Der Text daneben sagt bereits alles -- die Striche sind
                // eine zweite, rein visuelle Form derselben Aussage und
                // sollen VoiceOver nicht ein zweites Mal durchlaufen.
                .accessibilityHidden(true)
        }
    }

    func zielstriche(trainiert: Int, ziel: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(0..<max(ziel, 0), id: \.self) { index in
                // Erledigte Zieltage in der Signalfarbe, offene in `line`.
                // Weiss sagte hier nur "gefuellt" -- dieselbe Farbe, die
                // im Streifen darueber jede Tageszahl traegt, ob trainiert
                // oder nicht. Ein erreichter Zieltag ist aber genau das,
                // wofuer die Signalfarbe da ist (Testnotiz vom
                // 19. September, Eintrag 2).
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < trainiert ? DesignSystem.Color.accent : DesignSystem.Color.line)
                    .frame(width: 18, height: 4)
            }
        }
    }

    /// Die Zelle mit ihrem Buchstaben -- die Trefferflaeche ist die ganze
    /// Spalte, nicht der Kreis: 40 pt allein blieben unter den 44 aus
    /// designsystem.md SS4.
    func wochenzelle(_ tag: HomeSerieTag, gewaehlt: String?) -> some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            buchstabe(tag, istGewaehlt: tag.id == gewaehlt)
            VStack(spacing: 6) {
                zelle(tag, istGewaehlt: tag.id == gewaehlt)
                marke(tag)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Unter dem Tag die Planmarke, dieselbe wie im Plan-Tab (`PlanTagMarke`);
    /// ohne Planmarke der Kurspunkt. Beide teilen sich die Stelle, damit
    /// unter einem Tag nie zwei Zeichen stehen.
    func marke(_ tag: HomeSerieTag) -> some View {
        Group {
            if let art = tag.geplant {
                PlanTagMarke(art: art)
                    .accessibilityHidden(true)
            } else {
                kurspunkt(tag)
            }
        }
        .frame(height: 8)
    }

    /// Der Punkt unter dem Tag, wenn man dort einen Kurs hat (Testnotiz
    /// 06.10., #1) -- dieselbe Form wie unter den Tagesboxen der
    /// Kurse-Seite (`KurseWochenView.punkt`). Gruen fuer einen Platz, Gelb
    /// fuer die Warteliste. Ohne Kurs bleibt er unsichtbar stehen, damit
    /// die Zellen nicht in der Hoehe springen.
    func kurspunkt(_ tag: HomeSerieTag) -> some View {
        let punkt = HomeKurse.punkt(kurseJeTag[tag.id], jetzt: jetzt)
        return Circle()
            .fill(punkt == .warteliste ? DesignSystem.Color.warn : DesignSystem.Color.accent)
            .frame(width: 5, height: 5)
            .opacity(punkt == .keiner ? 0 : 1)
            .accessibilityHidden(true)
    }

    func buchstabe(_ tag: HomeSerieTag, istGewaehlt: Bool) -> some View {
        Text(tag.buchstabe)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(buchstabenfarbe(tag, istGewaehlt: istGewaehlt))
    }

    /// Nur die Uebersetzung `HomeSerieTag` -> `Kalenderzelle`: die Zelle
    /// selbst und ihre Farbregel stehen im Designsystem, weil der
    /// Kursplan dieselbe braucht.
    func zelle(_ tag: HomeSerieTag, istGewaehlt: Bool) -> some View {
        Kalenderzelle(
            inhalt: tag.trainiert ? .hantel : .zahl(tag.tagesnummer),
            istGewaehlt: istGewaehlt,
            istHeute: tag.istHeute,
            trainiert: tag.trainiert,
            gedeckt: tag.ausserhalb)
    }

    func buchstabenfarbe(_ tag: HomeSerieTag, istGewaehlt: Bool) -> Color {
        if istGewaehlt { return DesignSystem.Color.text }
        if tag.trainiert || tag.istHeute { return DesignSystem.Color.textMuted }
        return DesignSystem.Color.textFaint
    }
}

// MARK: - Die Einheiten des Tages

private extension HomeSerieView {
    func tagesliste(tagId: String, einheiten: [SessionSummary], kurse: [GespeicherterTermin]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(HomeSerie.tagestitel(tagId).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            // Karten, nicht Einheiten: wer nach einer kurzen Pause
            // weitermacht, hat einmal trainiert (HomeZeilen.trainingskarten).
            ForEach(HomeZeilen.trainingskarten(einheiten)) { karte in
                Button {
                    // Die Id des aeltesten Teils -- die Route bleibt
                    // sessionDetail(id:), das Detail sucht sich die uebrigen
                    // Teile selbst.
                    beiAuswahl(karte.id)
                } label: {
                    EinheitKarte(modell: .training(karte, muskeln: muskeln), geschlecht: geschlecht)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel(kartenLabel(karte))
            }

            // Dieselbe Karte wie im Band "Angemeldet" der Kurse-Seite, mit
            // "Abmelden" und Rueckfrage (Testnotiz 06.10., #1) -- kein
            // Nachbau, damit Frist, Warteliste und Fehler hier genauso
            // gelten wie dort.
            if !kurse.isEmpty, let kurseBuchungen {
                KurseBandView(
                    beiAuswahl: beiKursAuswahl,
                    jetzt: jetzt,
                    einteilung: KurseMeineEinteilung.bilden(
                        aus: kurse, jetzt: jetzt, zeitzone: kurseBuchungen.timezone),
                    eigene: kurseBuchungen)
            }
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
        switch HomeKurse.punkt(kurseJeTag[tag.id], jetzt: jetzt) {
        case .angemeldet: teile.append("Kurs, du bist angemeldet.")
        case .warteliste: teile.append("Kurs, du stehst auf der Warteliste.")
        case .keiner: break
        }
        switch tag.geplant {
        case .einheit: teile.append("Einheit geplant.")
        // Der Kurspunkt hat den Kurs oben schon genannt.
        case .kurs: if HomeKurse.punkt(kurseJeTag[tag.id], jetzt: jetzt) == .keiner { teile.append("Kurs geplant.") }
        case .cardio: teile.append("Cardio geplant.")
        case .verpasst: teile.append("Verpasst.")
        case nil: break
        }
        return teile.joined(separator: " ")
    }

    /// Die Karte als Satz: erst die grosse Zeile (Zeit und Saetze), dann
    /// die kleine (Uhrzeit und Geraete).
    ///
    /// Ohne "Auto beendet", seit die Marke ins Detail gewandert ist: das
    /// Label soll sagen, was die Karte zeigt, und nicht eine Ansage mehr
    /// machen als das Auge. Wer es genau wissen will, oeffnet die Einheit
    /// -- dort liest VoiceOver den Hinweis samt Erklaerung.
    func kartenLabel(_ karte: Trainingskarte) -> String {
        let titel = TrainingsProfil.berechne(karte: karte, muskeln: muskeln).titel
        return "\(titel). \(HomeZeilen.grosseZeile(karte)). \(HomeZeilen.kleineZeile(karte))."
    }
}

// MARK: - Vorschau

/// Fester Tag statt `Date()`: sonst wanderte der Ring jeden Tag eine
/// Zelle weiter und die Vorschau zeigte je nach Wochentag etwas anderes.
#Preview {
    // Mit Bloecken: die kleine Zeile der Karte zaehlt die verschiedenen
    // machineId, ohne Bloecke stuende in der Vorschau "0 Geraete".
    func einheit(_ id: String, _ start: String, _ ende: String) -> SessionSummary {
        let bloecke = ["Beinpresse", "Latzug"].map { geraet in
            SessionSummary.Block(
                machineId: geraet, machineLabel: geraet, exerciseId: "u-\(geraet)",
                exerciseName: geraet,
                loadUnit: .kg, secondaryUnit: nil, volumeKind: .reps, sets: [])
        }
        return SessionSummary(
            id: id, startedAt: start, completedAt: ende, completedReason: "manual",
            machineCount: bloecke.count, setCount: 8, blocks: bloecke)
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
            wochenziel: 3,
            beiAuswahl: { _ in })
        .padding(.horizontal, 20)
        .padding(.vertical, DesignSystem.Spacing.s24)
    }
    .background(DesignSystem.Color.bg)
}
