import SwiftUI

/// Ein Tag im Wochenstreifen -- reine Ableitung aus einem Zeitpunkt und
/// einer Zeitzone, ohne jede Abhaengigkeit von Environment oder Store. `id`
/// steht bewusst im selben Format wie `CourseWeekSession.localDay`
/// ("yyyy-MM-dd"), damit ein Tag im Streifen ohne weitere Umrechnung gegen
/// die Termine des Wochenplans abgeglichen werden kann -- der Server
/// berechnet `localDay` bereits in der Studio-Zeitzone, ein zweiter,
/// eigener Zeitzonen-Abgleich beim Gruppieren waere doppelte, angreifbare
/// Arbeit.
struct KurseWochentag: Identifiable, Equatable {
    let id: String
    /// "M", "D", "M", ... -- die schmalste Form ("ccccc", stand-alone).
    /// Sieben Zellen nebeneinander sind ein Raster, kein Text: der zweite
    /// Buchstabe kostet Breite und sagt nichts, was die Stellung im
    /// Streifen nicht schon sagt. Dieselbe Zelle wie im Home-Kalender
    /// (HomeSerieTag.buchstabe) -- zwei Wochenstreifen in einer App, die
    /// sich in Form und Beschriftung unterscheiden, waeren zwei Entwuerfe.
    let buchstabe: String
    /// "Montag", "Dienstag", ... fuer die Tagesueberschrift und VoiceOver.
    let wochentagVoll: String
    let tagesnummer: Int
    let istHeute: Bool
    /// Der Tagesbeginn in der Studio-Zeitzone. Traegt die Ueberschrift
    /// (`KurseWochenInhalt.tagesueberschrift`), die seit dem Wegfall der
    /// Wochenleiste den Monat mitnennen muss.
    let datum: Date
}

/// Die Berechnung des Wochenstreifens -- eine reine Funktion, getestet in
/// KurseWochenBerechnungTests, absichtlich ohne `Date()`- oder
/// `TimeZone.current`-Vorgabewert: `jetzt` und `zeitzone` kommen immer vom
/// Aufrufer, damit ein Test einen festen Zeitpunkt vorgeben kann.
enum KurseWochenBerechnung {
    private static func kalender(zeitzone: String) -> Calendar {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")!
        kalender.locale = Locale(identifier: "de_DE")
        return kalender
    }

    /// Der Montag (Tagesbeginn) der Woche, die `jetzt` in `zeitzone`
    /// enthaelt. Nicht ueber `Calendar.firstWeekday` geloest, das je nach
    /// Systemregion Sonntag sein kann -- die Woche startet hier immer am
    /// Montag, unabhaengig vom Geraet.
    static func montag(enthaelt jetzt: Date, zeitzone: String) -> Date {
        let kalender = kalender(zeitzone: zeitzone)
        let heute = kalender.startOfDay(for: jetzt)
        // component(.weekday) liefert 1 = Sonntag ... 7 = Samstag, immer in
        // dieser Zaehlung, unabhaengig vom Kalender-Identifier.
        let wochentagIndex = kalender.component(.weekday, from: heute)
        let versatz = wochentagIndex == 1 ? -6 : -(wochentagIndex - 2)
        return kalender.date(byAdding: .day, value: versatz, to: heute) ?? heute
    }

    /// Die exklusive Obergrenze fuer `KurseStore.laden(von:bis:)`:
    /// `jetzt` plus 14 Tage (Spec 5.1 -- "dieselbe Abfrage mit groesserem
    /// Fenster (jetzt bis +14 Tage)").
    ///
    /// EIN Fenster fuer beide Screens, nicht zwei. `KurseStore.laden(...)`
    /// ueberschreibt `eigene` bei jedem Aufruf mit genau dem, was im
    /// aktuellen Fenster liegt -- gaebe es ein zweites, kleineres Fenster
    /// irgendwo, beschnitten sich die beiden Screens gegenseitig den
    /// Cache. Der Wochenstreifen filtert ohnehin je Tag ueber `localDay`
    /// und zeigt ueberzaehlige Tage nie an; "Meine Kurse" bekommt damit
    /// seine kommenden Anmeldungen, ohne dass irgendwo ein eigener
    /// Endpoint oder ein zweiter Ladeweg entsteht.
    ///
    /// Ueber den Kalender addiert, nicht ueber 14 * 86400 Sekunden: eine
    /// Zeitumstellung im Fenster verschoebe die Grenze sonst um eine
    /// Stunde.
    ///
    /// Die aktuelle Woche liegt immer vollstaendig darin: ihr Sonntag
    /// endet spaetestens sieben Tage nach `jetzt`.
    static func fensterEnde(ab jetzt: Date, zeitzone: String) -> Date {
        let kalender = kalender(zeitzone: zeitzone)
        return kalender.date(byAdding: .day, value: 14, to: jetzt)
            ?? jetzt.addingTimeInterval(14 * 86400)
    }

    /// Die Montage der Wochen, durch die sich der Streifen wischen laesst.
    ///
    /// Aufgenommen wird nur, was das Ladefenster VOLLSTAENDIG hergibt: ein
    /// Montag zaehlt, wenn auch sein Sonntag noch vor `fensterEnde` liegt.
    /// Eine angebrochene letzte Woche waere schlimmer als gar keine -- der
    /// Streifen zeigte dort ein paar Tage mit Kursen und den Rest leer, und
    /// das liest sich wie ein Studio, das ab Mittwoch nichts mehr anbietet.
    ///
    /// Praktisch sind das zwei Wochen, an jedem Wochentag. Die Zahl steht
    /// hier trotzdem nirgends: aendert sich `fensterEnde`, wandert das
    /// Paging von allein mit.
    ///
    /// Rueckwaerts gibt es nichts -- das Fenster beginnt am Montag dieser
    /// Woche (siehe `KurseWochenView.neuLaden`), davor haette der Streifen
    /// keine Daten zu zeigen.
    static func wochenMontage(ab jetzt: Date, zeitzone: String) -> [Date] {
        let kalender = kalender(zeitzone: zeitzone)
        let ende = fensterEnde(ab: jetzt, zeitzone: zeitzone)
        var montage: [Date] = []
        var laufend = montag(enthaelt: jetzt, zeitzone: zeitzone)

        // Die Obergrenze ist eine Schranke gegen eine kaputte Zeitrechnung,
        // keine fachliche Grenze: `date(byAdding:)` kann nil liefern, und
        // ohne sie liefe die Schleife dann ewig.
        while montage.count < 8 {
            guard let sonntagEnde = kalender.date(byAdding: .day, value: 7, to: laufend),
                  sonntagEnde <= ende else { break }
            montage.append(laufend)
            laufend = sonntagEnde
        }
        return montage
    }

    /// Der Montag der Woche, in der ein `KurseWochentag.id` liegt.
    ///
    /// Ueber EINEN Formatter statt ueber `wochentage(...)`, das je Aufruf
    /// drei DateFormatter und sieben Strukturen baut -- diese Ableitung
    /// laeuft im Bildaufbau, mehrfach je Durchlauf.
    ///
    /// `nil` bei unlesbarer Kennung: die kommt aus gemerktem Zustand und
    /// koennte einen aelteren Stand tragen. Der Aufrufer faellt dann auf
    /// heute zurueck, statt eine Woche zu raten.
    static func montag(fuerTagId tagId: String, zeitzone: String) -> Date? {
        let formatter = DateFormatter()
        // en_US_POSIX fuer ein rein numerisches, festes Muster -- dieselbe
        // Begruendung wie bei KursZeit.uhrzeit.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let tag = formatter.date(from: tagId) else { return nil }
        return montag(enthaelt: tag, zeitzone: zeitzone)
    }

    /// Der Tag, der tatsaechlich gilt -- der gemerkte, solange er in einer
    /// der wischbaren Wochen liegt, sonst heute.
    ///
    /// Der Rueckfall ist kein Zierrat: bleibt die App ueber den
    /// Wochenwechsel offen, wandert das Ladefenster weiter und der
    /// gemerkte Tag faellt hinten heraus. Ohne ihn stuende der Streifen
    /// auf einer Woche, zu der es keine Tagesliste mehr gibt -- ein leerer
    /// Screen ohne jede Erklaerung.
    static func gueltigerTag(gewaehlt: String?, jetzt: Date, zeitzone: String) -> String {
        let heute = wochentage(enthaelt: jetzt, zeitzone: zeitzone)
            .first { $0.istHeute }?.id ?? ""
        guard let gewaehlt,
              let montag = montag(fuerTagId: gewaehlt, zeitzone: zeitzone),
              wochenMontage(ab: jetzt, zeitzone: zeitzone).contains(montag)
        else { return heute }
        return gewaehlt
    }

    /// Die sieben Kalendertage Montag bis Sonntag, die `jetzt` enthaelt.
    static func wochentage(enthaelt jetzt: Date, zeitzone: String) -> [KurseWochentag] {
        wochentage(
            abMontag: montag(enthaelt: jetzt, zeitzone: zeitzone),
            jetzt: jetzt, zeitzone: zeitzone)
    }

    /// Dieselben sieben Tage, aber fuer eine BELIEBIGE Woche -- das ist,
    /// was der wischbare Streifen braucht. `jetzt` bleibt getrennt, weil
    /// nur daran haengt, welcher Tag `istHeute` traegt: in einer kuenftigen
    /// Woche ist das keiner, und der Streifen traegt dort folglich keinen
    /// Akzentring ohne Anlass.
    static func wochentage(abMontag montag: Date, jetzt: Date, zeitzone: String) -> [KurseWochentag] {
        let kalender = kalender(zeitzone: zeitzone)
        let heute = kalender.startOfDay(for: jetzt)

        let idFormatter = DateFormatter()
        // en_US_POSIX fuer ein rein numerisches, festes Muster -- dieselbe
        // Begruendung wie bei KursZeit.uhrzeit.
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.timeZone = kalender.timeZone
        idFormatter.dateFormat = "yyyy-MM-dd"

        let buchstabenFormatter = DateFormatter()
        buchstabenFormatter.locale = Locale(identifier: "de_DE")
        buchstabenFormatter.timeZone = kalender.timeZone
        // "ccccc" (stand-alone, narrow) liefert "M", "D", "M", "D", "F",
        // "S", "S" -- nicht "EEEEE", das in manchen Sprachen die Form
        // fuer "am Montag" waehlt.
        buchstabenFormatter.dateFormat = "ccccc"

        let vollFormatter = DateFormatter()
        vollFormatter.locale = Locale(identifier: "de_DE")
        vollFormatter.timeZone = kalender.timeZone
        vollFormatter.dateFormat = "EEEE"

        return (0..<7).map { versatz in
            let tag = kalender.date(byAdding: .day, value: versatz, to: montag) ?? montag
            return KurseWochentag(
                id: idFormatter.string(from: tag),
                buchstabe: buchstabenFormatter.string(from: tag).uppercased(),
                wochentagVoll: vollFormatter.string(from: tag),
                tagesnummer: kalender.component(.day, from: tag),
                istHeute: kalender.isDate(tag, inSameDayAs: heute),
                datum: tag)
        }
    }
}

/// Der Wochenplan der Kurse (Kurse.dc.html) -- Kopf mit Studioname,
/// Wochenstreifen, Umschalter, die passende Liste darunter, Fussnote.
///
/// Der Screen zeigt seit dem Umbau EINEN Kalender ganz oben und darunter
/// entweder die eigenen Anmeldungen (`KurseBandView`) oder die Termine des
/// gewaehlten Tages -- umgeschaltet ueber die beiden Haelften unter dem
/// Streifen (`KurseAnsicht`). Davor standen beide Listen untereinander:
/// wer angemeldet war, scrollte an den eigenen Kursen vorbei zum Plan, und
/// wer es nicht war, las eine Ueberschrift ohne Inhalt.
///
/// Drei Festlegungen zum Umschalter:
///
/// 1. **Er erscheint nur mit mindestens einer offenen Anmeldung.** Sonst
///    beginnt der Screen direkt mit dem Wochenplan -- eine Haelfte, die
///    auf eine leere Liste zeigt, ist schlimmer als kein Knopf.
/// 2. **Der Kalender wirkt nur auf „Alle Kurse“.** „Angemeldet“ zeigt alle
///    kommenden Anmeldungen des Ladefensters, naechste zuerst. Tagesweise
///    gefiltert waere diese Haelfte an den meisten Tagen leer. Die Punkte
///    unter den Tageszellen sagen weiterhin, an welchen Tagen ein eigener
///    Platz steht.
/// 3. **Die Ueberschriften der beiden Listen sind weg** -- „DEINE KURSE“
///    ueber dem Band und „ALLE KURSE“ ueber dem Streifen. Beide Woerter
///    stehen jetzt auf dem Umschalter; zweimal dasselbe untereinander sagt
///    nichts doppelt so gut. Die Tagesueberschrift („Heute · Mi, 9.
///    September“) bleibt, sie sagt etwas anderes.
///
/// Vier aeltere Festlegungen, die erste davon neu gefasst:
///
/// 1. **Die eine Akzentflaeche des Screens ist der Umschalter**
///    „Angemeldet/Alle Kurse“, nicht mehr der gewaehlte Tag. Der Tag
///    hatte sie an sich gezogen, obwohl er nicht die Hauptaktion des
///    Screens ist -- und der heutige Tag blieb dadurch voellig
///    unmarkiert, weil die Flaeche schon vergeben war. Jetzt ist der
///    gewaehlte Tag weiss (`text`) und heute traegt den Akzent als RING:
///    eine Linie kostet keine Flaeche, also stehen beide Aussagen
///    nebeneinander. Fuer die Anmeldungen bleibt es dabei, dass sie sich
///    abheben MUESSEN, sonst war die Zusammenlegung sinnlos -- sie
///    tragen den Akzent als Kontur, Plakette und Punkt.
/// 2. **Kein ANGEMELDET-Chip mehr.** Zwei Woerter unterschieden die eigene
///    Zeile von ihren Nachbarn; jetzt tun es Kontur und Haken. Farbe traegt
///    den Status dabei nicht allein: der Haken ist eine Form, und sein
///    `accessibilityLabel` bringt das Wort in die Vorlesung zurueck.
/// 3. **Der Abmelden-Knopf steht nur im Band**, nicht an der Zeile. Sonst
///    stuende dieselbe Handlung zweimal auf einem Screen, und die Zeile im
///    Plan waere um ihre Fusszeile hoeher als jede andere.
/// 4. Der warngelb GEFUELLTE Balken bleibt weiterhin aus -- `warn` ist nur
///    als Kontur erlaubt. Die Belegungsleiste (`BelegungsleisteView`) ist
///    kein Fuellstand, sondern ein Segment je Platz, und sie steht immer
///    neben der Zahl, nie an ihrer Stelle.
struct KurseWochenView: View {
    /// Die sessionId statt des ganzen Termins: das Band kennt nur seine
    /// gespeicherten Buchungen, die Tagesliste den vollen `CourseWeekSession`
    /// -- beide sollen denselben Weg ins Kursdetail nehmen.
    let beiAuswahl: (String) -> Void
    /// Meldet den Abschluss, wenn ein Beitritt die laufende Einheit beendet.
    let loader: any GeraetLoading
    /// Der Plan-Tab ohne aktiven Plan zeigt diesen Screen unter seinem Namen
    /// (Ruling: "Kurse wie bisher plus PlanEinrichtenKarte").
    var titel = "KURSE"
    /// Steht unter dem Kopf -- dort die Karte "Plan einrichten".
    var zusatz: AnyView?

    @Environment(KurseStore.self) private var kurse
    @Environment(CatalogStore.self) private var katalog
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// nil, solange niemand einen Tag angetippt hat -- dann gilt der
    /// heutige Tag. Kein gespeicherter Default in init: der haengt von
    /// Umgebung (Studio-Zeitzone) ab, die im Initializer noch nicht lesbar
    /// ist, und eine rein abgeleitete Ableitung bleibt auch dann richtig,
    /// wenn die Mitternacht waehrend einer offenen App-Sitzung vergeht.
    @State private var gewaehlterTagId: String?

    /// nil, solange niemand den Umschalter angefasst hat -- dann gilt die
    /// Vorauswahl aus `KurseAnsicht.geltend`. Dasselbe Muster wie
    /// `gewaehlterTagId` darueber und aus demselben Grund: eine rein
    /// abgeleitete Vorauswahl bleibt auch dann richtig, wenn sich die
    /// Daten unter der offenen App aendern.
    @State private var gewaehlteAnsicht: KurseAnsicht?

    @State private var beitretenOffen = false

    /// Die abgewaehlten Studios des Filters (Testnotiz 11.10., #15), als
    /// durch Komma getrennte IDs. Gemerkt werden die AUSGEBLENDETEN: ein
    /// neues Studio ist damit von selbst sichtbar.
    @AppStorage("kurseAusgeblendeteStudios") private var ausgeblendetText = ""

    /// 60-Sekunden-Kadenz statt einer einmalig beim Aufbau gelesenen
    /// Date() -- dasselbe Muster wie in KursDetailView und KurseMeineView,
    /// und aus demselben Grund: @Observable loest kein Neuzeichnen aus,
    /// wenn bloss Zeit vergeht. Ohne den Tick bliebe ein begonnener Kurs
    /// als buchbar samt Belegungszahl stehen (und widerspraeche dem
    /// Kursdetail, das die Uhr hat), und ueber Mitternacht markierte der
    /// Wochenstreifen weiter gestern als "heute".
    var body: some View {
        Group {
            switch KurseOrtZustand.fuer(studios: alleStudios.count) {
            case .plan:
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    screenInhalt(jetzt: context.date)
                }
            case .beitreten:
                beitretenInhalt
            }
        }
        .testnotizScreen()
    }

    /// Ohne jede Mitgliedschaft: kein Plan, kein Laden -- nur der Weg zu
    /// einem Studio.
    private var beitretenInhalt: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            kopf
            if let zusatz { zusatz }
            Text(KurseOrtZustand.hinweis)
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
            SecondaryButton(title: "Studio beitreten") { beitretenOffen = true }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Color.bg)
        .sheet(isPresented: $beitretenOffen) {
            NavigationStack {
                StudioBeitretenView(loader: loader) { beitretenOffen = false }
            }
        }
    }

    private func screenInhalt(jetzt: Date) -> some View {
        // EINE Einteilung je Durchlauf, hier oben gebildet: sie entscheidet
        // zugleich, ob der Umschalter erscheint, welche Haelfte gilt und was
        // die Liste zeigt. Bildete KurseBandView sie selbst noch einmal,
        // koennten die drei auseinanderlaufen.
        let eigene = kurse.eigene
        let einteilung = eigene.map {
            KurseMeineEinteilung.bilden(
                aus: KurseFilter.sichtbar($0.termine, ausgeblendet: ausgeblendet),
                jetzt: jetzt, zeitzone: $0.timezone)
        }
        let hatAnmeldungen = !(einteilung?.istLeer ?? true)
        let ansicht = KurseAnsicht.geltend(
            gewaehlt: gewaehlteAnsicht, hatAnmeldungen: hatAnmeldungen)

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf
                if let zusatz { zusatz }
                if KurseFilter.zeigtAuswahl(studios: alleStudios.count) {
                    studioAuswahl
                }
                kalender(jetzt: jetzt, hatAnmeldungen: hatAnmeldungen, ansicht: ansicht)
                if ansicht == .angemeldet, let eigene, let einteilung {
                    KurseBandView(
                        beiAuswahl: beiAuswahl, jetzt: jetzt,
                        einteilung: einteilung, eigene: eigene)
                } else {
                    let herkunft = herkunft(jetzt: jetzt)
                    // Der Banner gehoert zum Wochenplan, nicht zum Screen:
                    // er erklaert die fehlenden Platzzahlen der Terminliste.
                    // Ueber den eigenen Anmeldungen stuende er ohne Bezug --
                    // die kommen von der Platte und zeigen gar keine Zahl.
                    if kurse.woche != nil,
                       let hinweis = herkunft.satz(
                           stand: kurse.wocheStand,
                           zusatz: "Die freien Plätze lassen wir deshalb weg. Zum Aktualisieren nach unten ziehen.") {
                        InlineBanner(tone: .muted, message: hinweis, icon: herkunft.symbol)
                    }
                    tagesliste(
                        jetzt: jetzt, herkunft: herkunft, hatAnmeldungen: hatAnmeldungen)
                }
                fussnote
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: gewaehlterTagId)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: ansicht)
        }
        .background(DesignSystem.Color.bg)
        // Ziehen zum Aktualisieren: der Weg, den das Mitglied ohne
        // Anleitung findet, und der einzige, der auch dann noch da ist,
        // wenn der Plan steht und bloss alt ist.
        .refreshable { await neuLaden() }
        // An der Studioliste statt am aktiven Ort: der Plan zeigt alle
        // Studios, ein Ortswechsel aendert nur die Reihenfolge (Testnotiz
        // 11.10., #15).
        .task(id: alleStudios) { await neuLaden() }
        // Ein Reconnect-Ausloeser. Ohne ihn blieb "Kein Empfang" stehen,
        // bis das Mitglied den Tab verliess und zurueckkam -- und der
        // Screen sagte auch nicht, dass es das tun soll.
        .onChange(of: netz.istOnline) { _, istOnline in
            guard istOnline else { return }
            Task { await neuLaden() }
        }
        // Rueckkehr aus dem Hintergrund. .task(id:) laeuft dabei nicht
        // erneut; ohne diesen Ausloeser stuende die Belegungszahl von vor
        // zwei Stunden unveraendert da.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await neuLaden() }
        }
    }

    /// Der eine Ladeweg des Screens -- alle vier Ausloeser (erster Aufbau,
    /// Ziehen, Reconnect, Rueckkehr aus dem Hintergrund) gehen hier durch,
    /// damit das Anfragefenster nicht an vier Stellen berechnet wird.
    private func neuLaden() async {
        await kurse.ladenAbDieserWoche(studioIds: alleStudios, zeitzone: zeitzoneFuerAnfrage)
    }

    /// Die eine Ableitung, die alle drei Kurse-Screens teilen -- sie
    /// entscheidet zugleich, ob eine Belegungszahl noch etwas aussagt
    /// (siehe KurseHerkunft).
    private func herkunft(jetzt: Date) -> KurseHerkunft {
        KurseHerkunft.bilden(
            ladeZustand: kurse.ladeZustand, wocheStand: kurse.wocheStand, jetzt: jetzt)
    }

    // MARK: - Kopf

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titel)
                .font(DesignSystem.Typography.screentitel)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer()
            Text(studioName.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Bei einem sichtbaren Studio sein Name, sonst wie viele es sind.
    private var studioName: String {
        let sichtbar = KurseFilter.sichtbareStudios(alle: alleStudios, ausgeblendet: ausgeblendet)
        if sichtbar.count == 1, let einziges = sichtbar.first { return name(vonStudio: einziges) }
        return "\(sichtbar.count) Studios"
    }

    // MARK: - Studios (Testnotiz 11.10., #15)

    /// Alle Studios des Mitglieds, das aktive vorn -- dieselbe Regel wie
    /// auf Home, damit beide dieselbe Menge laden.
    private var alleStudios: [String] {
        KurseStudios.reihenfolge(
            alle: katalog.bootstrap?.studios.map(\.id) ?? [], aktiv: katalog.activeStudioId)
    }

    private var ausgeblendet: Set<String> {
        Set(ausgeblendetText.split(separator: ",").map(String.init))
    }

    private func name(vonStudio id: String) -> String {
        katalog.bootstrap?.studios.first { $0.id == id }?.name ?? ""
    }

    /// Ein Chip je Studio; ein Tipp blendet es aus oder wieder ein. Das
    /// letzte sichtbare bleibt (KurseFilter.umschalten). Gleich breit bis
    /// drei Studios, darueber scrollbar.
    private var studioAuswahl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(alleStudios, id: \.self) { studio in
                    let aktiv = !ausgeblendet.contains(studio)
                    Button {
                        let neu = KurseFilter.umschalten(studio, ausgeblendet: ausgeblendet, alle: alleStudios)
                        ausgeblendetText = neu.sorted().joined(separator: ",")
                    } label: {
                        Chip(text: name(vonStudio: studio), isActive: aktiv,
                             innenabstand: DesignSystem.Spacing.s16)
                            .frame(minWidth: 96)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityAddTraits(aktiv ? .isSelected : [])
                    .accessibilityHint(aktiv ? "Blendet die Kurse dieses Studios aus" : "Zeigt die Kurse dieses Studios")
                }
            }
        }
        .scrollClipDisabled()
        .testnotizElement("kurse.studioauswahl", typ: "ScrollView")
    }

    /// Die Termine der sichtbaren Studios -- Tagesliste und Indikator lesen
    /// beide hier, damit kein Punkt auf einen ausgeblendeten Kurs zeigt.
    private var sichtbareTermine: [CourseWeekSession] {
        KurseFilter.sichtbar(kurse.woche?.sessions ?? [], ausgeblendet: ausgeblendet)
    }

    /// Die Zeitzone fuer den Wochenstreifen und das Anfragefenster, BEVOR
    /// der Wochenplan zum ersten Mal geladen ist -- `woche.timezone` gibt
    /// es dann noch nicht. Sobald der Plan da ist, zaehlt fuer Uhrzeiten
    /// ausschliesslich `woche.timezone` (siehe terminZeile); dieser Wert
    /// hier dient nur der Woche-Berechnung selbst und dem Ladefenster.
    private var zeitzoneFuerAnfrage: String {
        kurse.woche?.timezone
            ?? alleStudios.first.flatMap { erstes in katalog.bootstrap?.studios.first { $0.id == erstes }?.timezone }
            ?? "UTC"
    }

    // MARK: - Kalender: Ueberschrift, wischbarer Streifen, Tages-Indikator

    private func wochentage(jetzt: Date) -> [KurseWochentag] {
        KurseWochenBerechnung.wochentage(
            abMontag: gewaehlterMontag(jetzt: jetzt), jetzt: jetzt, zeitzone: zeitzoneFuerAnfrage)
    }

    /// Der gemerkte Tag, solange er in einer der wischbaren Wochen liegt --
    /// sonst heute (siehe `KurseWochenBerechnung.gueltigerTag`).
    private func gewaehlterTag(jetzt: Date) -> String {
        KurseWochenBerechnung.gueltigerTag(
            gewaehlt: gewaehlterTagId, jetzt: jetzt, zeitzone: zeitzoneFuerAnfrage)
    }

    private func montage(jetzt: Date) -> [Date] {
        KurseWochenBerechnung.wochenMontage(ab: jetzt, zeitzone: zeitzoneFuerAnfrage)
    }

    /// Der Montag der Woche, die gerade im Streifen steht. Abgeleitet aus
    /// dem gewaehlten TAG, nicht aus einem zweiten Zustand: zwei
    /// unabhaengige Merker (Seite und Tag) koennen auseinanderlaufen --
    /// etwa wenn ueber Mitternacht eine Woche wegfaellt -, und dann zeigte
    /// der Streifen eine andere Woche als die Liste darunter.
    private func gewaehlterMontag(jetzt: Date) -> Date {
        KurseWochenBerechnung.montag(
            fuerTagId: gewaehlterTag(jetzt: jetzt), zeitzone: zeitzoneFuerAnfrage)
            ?? KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzoneFuerAnfrage)
    }

    private func wochenIndex(jetzt: Date) -> Int {
        montage(jetzt: jetzt).firstIndex(of: gewaehlterMontag(jetzt: jetzt)) ?? 0
    }

    /// Beim Blaettern wandert die Auswahl mit: in die laufende Woche auf
    /// den heutigen Tag, in jede andere auf ihren Montag. Ohne das bliebe
    /// der gewaehlte Tag in der alten Woche stehen -- der Streifen zeigte
    /// die neue, die Liste darunter die alte.
    private func waehleWoche(index: Int, jetzt: Date) {
        let alle = montage(jetzt: jetzt)
        guard alle.indices.contains(index) else { return }
        let tage = KurseWochenBerechnung.wochentage(
            abMontag: alle[index], jetzt: jetzt, zeitzone: zeitzoneFuerAnfrage)
        gewaehlterTagId = (tage.first { $0.istHeute } ?? tage.first)?.id
    }

    /// Der Kalender steht ganz oben und ohne Ueberschrift: die fruehere
    /// Wochenleiste mit Datumsspanne und Vor/Zurueck-Pfeilen ist weg
    /// (gewischt wird auf den Tagesboxen selbst), und „ALLE KURSE“ darueber
    /// ist mit dem Umbau in den Umschalter gewandert. Weil damit die
    /// einzige Monatsangabe des Screens verschwunden war, traegt sie die
    /// Tagesueberschrift unter dem Streifen.
    ///
    /// Streifen und Umschalter stehen in EINEM Block mit engerem Abstand
    /// (s16 statt der s24 zwischen den Abschnitten): der Umschalter gehoert
    /// sichtbar zum Kalender darueber, nicht zur Liste darunter -- sonst
    /// laese er sich als Ueberschrift der Liste, und die Verbindung zum
    /// Tag, den er in einer seiner beiden Haelften filtert, ginge verloren.
    private func kalender(
        jetzt: Date, hatAnmeldungen: Bool, ansicht: KurseAnsicht
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            wochenstreifen(jetzt: jetzt, ansicht: ansicht)
            if KurseAnsicht.zeigtUmschalter(hatAnmeldungen: hatAnmeldungen) {
                umschalter(ansicht)
            }
        }
    }

    /// Die beiden Haelften „Angemeldet“ und „Alle Kurse“.
    ///
    /// Die gewaehlte Haelfte ist accent-GEFUELLT -- die einzige
    /// Akzentflaeche fuer eine Aktion, seit der gewaehlte Tag im Streifen
    /// weiss ist und heute nur noch einen Ring traegt. Sie steht hier
    /// richtig, weil der Umschalter die Hauptaktion des Screens ist: er
    /// entscheidet, was die Liste ueberhaupt zeigt. Beide Haelften sind
    /// gleich breit, damit keine wie die wichtigere aussieht, und beide
    /// 44pt hoch (designsystem.md SS4).
    ///
    /// `.isSelected` statt einer zweiten Beschriftung: VoiceOver sagt damit
    /// „ausgewaehlt“, ohne dass der Zustand am Gruen allein haengt.
    private func umschalter(_ ansicht: KurseAnsicht) -> some View {
        HStack(spacing: 0) {
            ForEach(KurseAnsicht.allCases, id: \.self) { haelfte in
                let aktiv = haelfte == ansicht
                Button {
                    gewaehlteAnsicht = haelfte
                } label: {
                    Text(haelfte.titel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            aktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(aktiv ? DesignSystem.Color.accent : Color.clear)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel(haelfte.titel)
                .accessibilityAddTraits(aktiv ? .isSelected : [])
            }
        }
        // 2pt Luft zwischen gefuellter Haelfte und Aussenkontur -- ohne sie
        // liefen die beiden Kapselkanten aufeinander und die Kontur
        // verschwaende hinter dem Gruen.
        .padding(2)
        .overlay(Capsule().stroke(DesignSystem.Color.line, lineWidth: 1))
    }

    /// Der Streifen selbst steht in `KurseWochenstreifen` (mit dem Plan-Tab
    /// geteilt); hier nur, was der Kurse-Screen darunter zeigt und was ein
    /// Tag-Tipp an der Ansicht aendert.
    private func wochenstreifen(jetzt: Date, ansicht: KurseAnsicht) -> some View {
        KurseWochenstreifen(
            montage: montage(jetzt: jetzt), index: wochenIndex(jetzt: jetzt), jetzt: jetzt,
            zeitzone: zeitzoneFuerAnfrage, gewaehlterTagId: gewaehlterTag(jetzt: jetzt),
            beiWochenwahl: { waehleWoche(index: $0, jetzt: jetzt) },
            beiTagwahl: { tag in
                gewaehlterTagId = tag.id
                // Ein Tag ohne eigenen Platz hat in der "Angemeldet"-Haelfte
                // nichts zu sagen -- die Begruendung steht an
                // KurseAnsicht.nachTagwahl.
                //
                // NUR bei einer echten Aenderung schreiben. Sonst machte jeder
                // Tag-Tipp aus `nil` eine getippte Wahl, und `nil` heisst hier
                // etwas: "hat den Umschalter noch nie angefasst". Wer ohne
                // Anmeldungen (also in `.alle`) einen Tag antippt, haette sich
                // damit stillschweigend auf `.alle` festgelegt -- und nach
                // seiner ersten Buchung stuende der Screen auf "Alle Kurse"
                // statt auf den eigenen Anmeldungen, ohne dass er je
                // umgeschaltet hat.
                let neueAnsicht = KurseAnsicht.nachTagwahl(bisher: ansicht, indikator: indikator(tag, jetzt: jetzt))
                if neueAnsicht != ansicht { gewaehlteAnsicht = neueAnsicht }
            },
            label: { tagLabel($0, indikator: indikator($0, jetzt: jetzt)) },
            marke: { punkt(indikator($0, jetzt: jetzt)) })
    }

    private func indikator(_ tag: KurseWochentag, jetzt: Date) -> KurseTagesindikator {
        KurseTagesindikator.fuer(tagId: tag.id, termine: sichtbareTermine, jetzt: jetzt)
    }

    /// Der Punkt bleibt auch dann im Layout, wenn er nichts anzeigt --
    /// sonst waeren die Tagesboxen einer kursfreien Woche 5pt hoeher als
    /// die der naechsten, und der Streifen sprunge beim Wischen.
    private func punkt(_ indikator: KurseTagesindikator) -> some View {
        Circle()
            .fill(indikator == .angemeldet ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
            .frame(width: 5, height: 5)
            .opacity(indikator == .keiner ? 0 : 1)
    }

    /// Der Punkt selbst ist fuer VoiceOver unsichtbar (er ist eine
    /// Verzierung ohne eigene Bedienung) -- seine Aussage steht hier im
    /// Label des Tages, wo sie hingehoert.
    private func tagLabel(_ tag: KurseWochentag, indikator: KurseTagesindikator) -> String {
        var teile = ["\(tag.wochentagVoll), \(tag.tagesnummer)."]
        if tag.istHeute { teile.append("Heute.") }
        switch indikator {
        case .keiner: teile.append("Keine Kurse.")
        case .kurse: teile.append("Kurse an diesem Tag.")
        case .angemeldet: teile.append("Kurse an diesem Tag, du bist angemeldet.")
        }
        return teile.joined(separator: " ")
    }

    // MARK: - Inhalt: Skelett, Leer, Offline, Fehler, Liste

    /// Reihenfolge ist Bedeutung, und sie hat sich mit der Schlusswelle
    /// umgedreht: **ein vorhandener Plan gewinnt gegen jeden Fehler.**
    ///
    /// Frueher stand der Fehlerzweig zuerst, weil `KurseStore.laden` bei
    /// jedem Fehlversuch `woche = nil` setzte -- es gab also gar nichts
    /// mehr zu zeigen. Seit der Plan im Speicher stehen bleibt, waere das
    /// Verschenken von Namen, Uhrzeiten und Raeumen eine Ueberreaktion:
    /// die aendern sich nicht. Was sich aendert, ist die Belegung, und die
    /// blendet `herkunft.zeigtBelegung` aus. Der Banner darueber sagt, wie
    /// alt der Plan ist und dass die Plaetze deshalb fehlen.
    ///
    /// Die Karten bleiben fuer den Fall, dass es wirklich nichts zu zeigen
    /// gibt -- Kaltstart ohne Empfang, Fehler beim allerersten Laden.
    ///
    /// Offline vs. Serverfehler kommt aus dem Fehler selbst
    /// (`APIError.offline`), nicht aus `netz.istOnline`: der
    /// Netzwerkmonitor kann in der Sekunde zwischen einem Timeout und der
    /// naechsten Reachability-Meldung kurz "online" zeigen, waehrend die
    /// Anfrage selbst laengst mit .offline gescheitert ist -- der
    /// tatsaechlich gefangene Fehler ist die verlässlichere Quelle.
    private func tagesliste(
        jetzt: Date, herkunft: KurseHerkunft, hatAnmeldungen: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(tagesueberschrift(jetzt: jetzt).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            inhalt(jetzt: jetzt, herkunft: herkunft, hatAnmeldungen: hatAnmeldungen)
        }
    }

    /// „Heute · Mi, 9. September“ -- mit Datum, seit die Wochenleiste weg
    /// ist (siehe `KurseWochenInhalt.tagesueberschrift`).
    private func tagesueberschrift(jetzt: Date) -> String {
        let gewaehlt = gewaehlterTag(jetzt: jetzt)
        guard let tag = wochentage(jetzt: jetzt).first(where: { $0.id == gewaehlt })
        else { return "" }
        return KurseWochenInhalt.tagesueberschrift(tag, zeitzone: zeitzoneFuerAnfrage)
    }

    @ViewBuilder
    private func inhalt(
        jetzt: Date, herkunft: KurseHerkunft, hatAnmeldungen: Bool
    ) -> some View {
        if kurse.woche != nil {
            if termineDesTages(jetzt: jetzt).isEmpty {
                leerZustand
            } else {
                VStack(spacing: DesignSystem.Spacing.s12) {
                    ForEach(termineDesTages(jetzt: jetzt)) { termin in
                        KursTerminZeile(
                            termin: termin, jetzt: jetzt, herkunft: herkunft,
                            zeitzone: kurse.zeitzone(fuer: termin.sessionId)
                                ?? kurse.woche?.timezone ?? zeitzoneFuerAnfrage,
                            trainerUndRaum: trainerUndRaum(termin), beiAuswahl: beiAuswahl)
                    }
                }
            }
        } else if case .fehlgeschlagen(let fehler) = kurse.ladeZustand {
            if fehler == .offline {
                offlineKarte(hatAnmeldungen: hatAnmeldungen)
            } else {
                fehlerKarte(fehler.servertext, hatAnmeldungen: hatAnmeldungen)
            }
        } else {
            skelett
        }
    }

    private func termineDesTages(jetzt: Date) -> [CourseWeekSession] {
        let gewaehlt = gewaehlterTag(jetzt: jetzt)
        return sichtbareTermine
            .filter { $0.localDay == gewaehlt }
            .sorted {
                (Zeitpunkt.parse($0.startsAt) ?? .distantPast)
                    < (Zeitpunkt.parse($1.startsAt) ?? .distantPast)
            }
    }

    /// Nur beim ERSTEN Laden, nur ueber der Terminliste -- niemals ueber
    /// einer Zahl (designsystem.md SS5). Reine Flaechen ohne jeden Text,
    /// keine Platzhalterzahl, die spaeter falsch aussehen koennte.
    private var skelett: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .fill(DesignSystem.Color.surfaceRaised)
                    .frame(height: 76)
            }
        }
        // Ein Ladezustand darf nie stumm sein (designsystem.md SS5) -- ohne
        // dieses Label liest VoiceOver drei leere Flaechen ohne Erklaerung.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kurse werden geladen")
    }

    /// Ueberschrift plus naechster Schritt, keine leere Statistik.
    private var leerZustand: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text("Für diesen Tag hat dein Studio keinen Kurs eingetragen.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            Text("Wähle einen anderen Tag oben in der Woche.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .accessibilityElement(children: .combine)
    }

    /// danger-Umriss auf 10% danger-Flaeche, wie OfflineLeiste (GeraetView)
    /// -- derselbe Ton fuer denselben Zustand. Die Haelfte „Angemeldet“
    /// bleibt erreichbar (sie liest aus `KurseStore.eigene`, also von der
    /// Platte, und braucht kein Netz), das sagt der zweite Satz
    /// ausdruecklich. Er nannte nacheinander „Meine Kurse“ und „Deine
    /// Kurse“; beide gibt es nicht mehr, die Aussage gilt unveraendert.
    private func offlineKarte(hatAnmeldungen: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("Kein Empfang")
                        .font(.system(size: 15, weight: .semibold))
                    // Der zweite Satz zeigt auf eine Haelfte des
                    // Umschalters -- und der steht nur da, wenn es
                    // ueberhaupt eine Anmeldung gibt. Ohne diese Bedingung
                    // verwiese die Karte auf einen Knopf, den es auf dem
                    // Screen nicht gibt.
                    Text(hatAnmeldungen
                        ? "Der Wochenplan braucht Empfang. Deine Anmeldungen stehen oben unter „Angemeldet“."
                        : "Der Wochenplan braucht Empfang.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .lineSpacing(3)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            wiederholenKnopf
        }
        .foregroundStyle(DesignSystem.Color.danger)
        .padding(DesignSystem.Spacing.s12)
        // clipShape VOR overlay: umgekehrt schnitte die Maske die aeussere
        // Haelfte der 1pt-Kontur weg und liesse eine halbe uebrig
        // (dieselbe Reihenfolge wie in InlineBanner).
        .background(DesignSystem.Color.danger.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
    }

    /// Der Weg zurueck aus beiden Fehlerkarten. Ohne ihn blieb "Kein
    /// Empfang" stehen, bis das Mitglied von selbst darauf kam, den Tab zu
    /// wechseln -- und der Screen sagte nicht, dass das hilft.
    /// Rueckmeldung braucht der Knopf keine eigene: ein Versuch setzt
    /// `ladeZustand` auf `.laedt`, womit die Karte dem beschrifteten
    /// Skelett weicht ("Kurse werden geladen").
    private var wiederholenKnopf: some View {
        Button {
            Task { await neuLaden() }
        } label: {
            Text("Erneut versuchen")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .overlay(Capsule().stroke(DesignSystem.Color.line, lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
    }

    /// Zeigt den Servertext woertlich (`text`, aus `APIError.servertext`) --
    /// jetzt moeglich, weil KurseStore.laden(...) den gefangenen APIError
    /// seit dem Review zu Aufgabe 9 durchreicht statt ihn zu verwerfen
    /// (`KurseLadeZustand.fehlgeschlagen(APIError)`). Der zweite Satz sagt,
    /// was trotzdem gilt (designsystem.md SS5: Fehler sagen, was falsch
    /// ist UND was gilt).
    private func fehlerKarte(_ text: String, hatAnmeldungen: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.danger)
                // Siehe offlineKarte: der Verweis steht nur, wenn es die
                // Haelfte gibt, auf die er zeigt.
                if hatAnmeldungen {
                    Text("Deine eigenen Anmeldungen stehen weiterhin oben unter „Angemeldet“.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .lineSpacing(3)
                }
            }
            .accessibilityElement(children: .combine)
            wiederholenKnopf
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
    }

    /// Der Servertext woertlich fuer alles, was tatsaechlich vom Server
    /// kommt (SS5). `.offline` gehoert hier nicht her -- das bekommt in
    /// `inhalt` seine eigene, ehrliche Formulierung (`offlineKarte`), nie
    /// "fehlgeschlagen". `.encodingFailed`/`.decodingFailed` sind rein
    /// clientseitige Faelle ohne Servertext (siehe APIError-Kommentare);
    /// hier ein knapper, ehrlicher Ersatzsatz statt eines erfundenen
    /// Server-Zitats.

    /// Mit dem Studio, sobald mehr als eines sichtbar ist -- sonst saehe
    /// man nicht, wohin man faehrt (Testnotiz 11.10., #15).
    private func trainerUndRaum(_ termin: CourseWeekSession) -> String? {
        let mitStudio = KurseFilter.sichtbareStudios(alle: alleStudios, ausgeblendet: ausgeblendet).count > 1
        return KursTerminZeile.trainerUndRaum(termin, studioName: mitStudio ? { name(vonStudio: $0) } : nil)
    }


    // MARK: - Fussnote

    private var fussnote: some View {
        Text("Kursplan und Plätze verwaltet dein Studio.")
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
}
