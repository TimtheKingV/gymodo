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
    /// Woche ist das keiner, und der Streifen traegt dort folglich keine
    /// Akzentflaeche ohne Anlass.
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
/// Vier aeltere Festlegungen gelten unveraendert weiter:
///
/// 1. **Die Ein-Akzent-Regel ist aufgegeben.** Frueher trug dieser Screen
///    genau eine Akzentflaeche (den gewaehlten Tag). Das laesst sich nicht
///    halten, wenn die eigenen Anmeldungen mit auf den Screen kommen --
///    sie MUESSEN sich abheben, sonst war die Zusammenlegung sinnlos.
///    Die neue Regel: **Flaeche heisst gewaehlt, Kontur heisst deins.**
///    Nur der gewaehlte Tag ist accent-GEFUELLT; Anmeldungen tragen den
///    Akzent als Kontur, Plakette und Punkt.
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

    /// 60-Sekunden-Kadenz statt einer einmalig beim Aufbau gelesenen
    /// Date() -- dasselbe Muster wie in KursDetailView und KurseMeineView,
    /// und aus demselben Grund: @Observable loest kein Neuzeichnen aus,
    /// wenn bloss Zeit vergeht. Ohne den Tick bliebe ein begonnener Kurs
    /// als buchbar samt Belegungszahl stehen (und widerspraeche dem
    /// Kursdetail, das die Uhr hat), und ueber Mitternacht markierte der
    /// Wochenstreifen weiter gestern als "heute".
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            screenInhalt(jetzt: context.date)
        }
    }

    private func screenInhalt(jetzt: Date) -> some View {
        // EINE Einteilung je Durchlauf, hier oben gebildet: sie entscheidet
        // zugleich, ob der Umschalter erscheint, welche Haelfte gilt und was
        // die Liste zeigt. Bildete KurseBandView sie selbst noch einmal,
        // koennten die drei auseinanderlaufen.
        let eigene = kurse.eigene
        let einteilung = eigene.map {
            KurseMeineEinteilung.bilden(aus: $0.termine, jetzt: jetzt, zeitzone: $0.timezone)
        }
        let hatAnmeldungen = !(einteilung?.istLeer ?? true)
        let ansicht = KurseAnsicht.geltend(
            gewaehlt: gewaehlteAnsicht, hatAnmeldungen: hatAnmeldungen)

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf
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
        .task(id: katalog.activeStudioId) { await neuLaden() }
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
        guard let studioId = katalog.activeStudioId else { return }
        let jetzt = Date()
        let von = KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzoneFuerAnfrage)
        // Bis "jetzt plus 14 Tage", nicht bis zum naechsten Montag: das
        // eine Fenster fuer beide Screens (Spec 5.1, siehe fensterEnde).
        // Dieser Screen zeigt davon weiterhin nur den gewaehlten Tag --
        // termineDesTages filtert ueber localDay.
        let bis = KurseWochenBerechnung.fensterEnde(ab: jetzt, zeitzone: zeitzoneFuerAnfrage)
        await kurse.laden(studioId: studioId, von: von, bis: bis)
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
            Text("KURSE")
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

    private var studioName: String {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name ?? ""
    }

    /// Die Zeitzone fuer den Wochenstreifen und das Anfragefenster, BEVOR
    /// der Wochenplan zum ersten Mal geladen ist -- `woche.timezone` gibt
    /// es dann noch nicht. Sobald der Plan da ist, zaehlt fuer Uhrzeiten
    /// ausschliesslich `woche.timezone` (siehe terminZeile); dieser Wert
    /// hier dient nur der Woche-Berechnung selbst und dem Ladefenster.
    private var zeitzoneFuerAnfrage: String {
        kurse.woche?.timezone
            ?? katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.timezone
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
            wochenstreifen(jetzt: jetzt)
            if KurseAnsicht.zeigtUmschalter(hatAnmeldungen: hatAnmeldungen) {
                umschalter(ansicht)
            }
        }
    }

    /// Die beiden Haelften „Angemeldet“ und „Alle Kurse“.
    ///
    /// Die gewaehlte Haelfte ist accent-GEFUELLT -- die zweite Akzentflaeche
    /// des Screens neben dem gewaehlten Tag, und aus demselben Grund
    /// zulaessig: sie sagt dasselbe Wort („das hier ist gewaehlt“), nicht
    /// ein zweites. Beide Haelften sind gleich breit, damit keine wie die
    /// wichtigere aussieht, und beide 44pt hoch (designsystem.md SS4).
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

    /// Ein ECHTER Paging-Container, keine selbstgebaute DragGesture.
    ///
    /// Das ist kein Geschmacksurteil: mit der Wochenleiste sind die Pfeile
    /// weggefallen, und damit der antippbare Zwilling der Wischgeste. Eine
    /// eigene Geste haette VoiceOver gar nichts gelassen. `TabView(.page)`
    /// bringt den Dreifinger-Wisch mit; die beiden benannten
    /// Aktionen darunter machen den Wochenwechsel zusaetzlich ueber den
    /// Rotor erreichbar -- und ueber Schaltersteuerung.
    private func wochenstreifen(jetzt: Date) -> some View {
        let alle = montage(jetzt: jetzt)
        let index = wochenIndex(jetzt: jetzt)

        return TabView(
            selection: Binding(
                get: { index },
                set: { waehleWoche(index: $0, jetzt: jetzt) })
        ) {
            ForEach(Array(alle.enumerated()), id: \.offset) { seite, montag in
                tagesboxen(
                    KurseWochenBerechnung.wochentage(
                        abMontag: montag, jetzt: jetzt, zeitzone: zeitzoneFuerAnfrage),
                    jetzt: jetzt)
                .frame(maxHeight: .infinity, alignment: .top)
                .tag(seite)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Feste Hoehe: 12pt Buchstabe, 6pt Abstand, 40pt Kreis, 6pt
        // Abstand, 5pt Punkt. Eine TabView hat keine Eigenhoehe, ohne
        // diese Angabe fuellte sie den ganzen ScrollView.
        .frame(height: 69)
        .accessibilityAction(named: "Nächste Woche") {
            waehleWoche(index: min(index + 1, alle.count - 1), jetzt: jetzt)
        }
        .accessibilityAction(named: "Vorherige Woche") {
            waehleWoche(index: max(index - 1, 0), jetzt: jetzt)
        }
    }

    private func tagesboxen(_ tage: [KurseWochentag], jetzt: Date) -> some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(tage) { tag in
                let ausgewaehlt = tag.id == gewaehlterTag(jetzt: jetzt)
                let indikator = KurseTagesindikator.fuer(
                    tagId: tag.id, termine: kurse.woche?.sessions ?? [], jetzt: jetzt)
                Button {
                    gewaehlterTagId = tag.id
                } label: {
                    VStack(spacing: 6) {
                        // Der Buchstabe steht UEBER der Zelle, nicht darin:
                        // dieselbe Anordnung wie im Home-Kalender, und die
                        // Zelle bleibt dadurch ein Kreis statt eines Kastens
                        // mit zwei Zeilen.
                        Text(tag.buchstabe)
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(
                                ausgewaehlt
                                    ? DesignSystem.Color.text : DesignSystem.Color.textFaint)

                        ZStack {
                            // Die einzige AkzentFLAECHE des Screens: nur der
                            // gewaehlte Tag traegt sie (siehe Festlegung 1 oben).
                            Circle().fill(ausgewaehlt ? DesignSystem.Color.accent : Color.clear)
                            Text("\(tag.tagesnummer)")
                                .font(.system(size: 16, weight: .black).monospacedDigit())
                                .foregroundStyle(
                                    ausgewaehlt
                                        ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                        }
                        .frame(width: 40, height: 40)

                        punkt(indikator)
                    }
                    // Die Trefferflaeche ist die ganze Spalte, nicht der
                    // Kreis: 40 pt allein blieben unter den 44 aus
                    // designsystem.md SS4.
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel(tagLabel(tag, indikator: indikator))
                .accessibilityAddTraits(ausgewaehlt ? .isSelected : [])
            }
        }
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
                        terminZeile(termin, jetzt: jetzt, herkunft: herkunft)
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
        return (kurse.woche?.sessions ?? [])
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

    // MARK: - Terminzeile

    /// Ob die Belegungszahl bei diesem Zustand gezeigt wird. `vorbei` und
    /// `abgesagt` lassen sie weg (wie im Artboard die Vorbei-Zeile ohne
    /// Balken/Zahl) -- eine Platzzahl ist fuer einen Termin, den man weder
    /// buchen noch stornieren kann, keine Information mehr, nur Rauschen.
    private func zeigtBelegung(_ zustand: KursZustand) -> Bool {
        switch zustand {
        case .frei, .voll, .angemeldet, .warteliste: true
        case .vorbei, .abgesagt: false
        }
    }

    /// Text und Farbe des Statuschips -- ausschliesslich als Umriss
    /// gezeichnet (siehe terminZeile), nie als Flaeche. `nil` bei frei/voll:
    /// kein Chip (Aufgabenbrief-Tabelle).
    ///
    /// "VORBEI" stand hier in `textFaint` bei 10pt und bekam von der Zeile
    /// zusaetzlich `.opacity(0.5)` -- ueber `bg` komponiert rund 1,7 : 1.
    /// `textFaint` ist laut designsystem.md SS2 nur ab 15pt oder fuer
    /// nicht tragenden Text zugelassen, und "VORBEI" ist die tragende
    /// Aussage der Zeile. Jetzt `textMuted`; die Abblendung der Zeile
    /// betrifft den Chip nicht mehr (siehe terminZeile).
    private func chipInhalt(_ zustand: KursZustand) -> (text: String, farbe: Color)? {
        switch zustand {
        case .vorbei: ("VORBEI", DesignSystem.Color.textMuted)
        case .abgesagt: ("ABGESAGT", DesignSystem.Color.warn)
        // Die eigenen Zustaende tragen keinen Chip mehr, sondern Kontur und
        // Marke (Festlegung 2 oben). Zwei Woerter waren zu wenig, um die
        // eigene Zeile von ihren Nachbarn zu unterscheiden.
        case .angemeldet, .warteliste: nil
        case .frei, .voll: nil
        }
    }

    /// Die Kontur einer eigenen Anmeldung -- `nil` fuer jede fremde Zeile.
    /// `warn` bleibt dabei Kontur und wird nie Flaeche (designsystem.md SS2).
    private func kontur(_ zustand: KursZustand) -> (farbe: Color, staerke: CGFloat)? {
        switch zustand {
        case .angemeldet: (DesignSystem.Color.accent, 1.5)
        case .warteliste: (DesignSystem.Color.warn.opacity(0.33), 1)
        case .frei, .voll, .vorbei, .abgesagt: nil
        }
    }

    /// Die Marke rechts. Sie ersetzt den Chevron nur bei den eigenen
    /// Zustaenden -- jede andere Zeile behaelt ihn, damit keine wie tote
    /// Information wirkt.
    ///
    /// Beide tragen ein `accessibilityLabel`: die Zeile fasst ihre Kinder
    /// zusammen (`children: .combine`), damit steht das Wort wieder in der
    /// Vorlesung, das mit dem Chip verschwunden ist. Ohne das haenge der
    /// Status allein an der Farbe.
    @ViewBuilder
    private func marke(_ zustand: KursZustand, wartelistenplatz: Int?) -> some View {
        switch zustand {
        case .angemeldet:
            ZStack {
                Circle().fill(DesignSystem.Color.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DesignSystem.Color.onAccent)
            }
            .frame(width: 26, height: 26)
            .accessibilityLabel("Angemeldet")
        case .warteliste:
            // Die Position steht nur, wenn sie FRISCH ist -- sie aendert
            // sich ohne Zutun des Mitglieds (jemand davor storniert, es
            // rueckt nach). Eine Zahl von vorhin koennte jemanden dazu
            // bringen, eine Warteliste zu verlassen, auf der er laengst
            // nachgerueckt ist. Sonst dieselbe Sanduhr wie im Band.
            if let platz = wartelistenplatz {
                VStack(spacing: 1) {
                    Text("\(platz)")
                        .font(.system(size: 20, weight: .black).monospacedDigit())
                    Text("PLATZ")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                }
                .foregroundStyle(DesignSystem.Color.warn)
                .accessibilityLabel("Warteliste, Platz \(platz)")
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.warn)
                    .accessibilityLabel("Auf der Warteliste")
            }
        case .frei, .voll, .vorbei, .abgesagt:
            EmptyView()
        }
    }

    private func trainerUndRaum(_ termin: CourseWeekSession) -> String? {
        let teile = [termin.instructorName, termin.room].compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// Jede Zeile ist antippbar und traegt denselben Chevron (Abweichung 4
    /// oben) -- unabhaengig vom Zustand, damit keine der vier Zeilen wie
    /// tote Information wirkt.
    ///
    /// `jetzt` kommt aus dem 60-Sekunden-Tick der TimelineView in `body`,
    /// nicht aus einem frisch erzeugten Date(): sonst blieb ein bereits
    /// begonnener Kurs als buchbar samt Belegungszahl stehen, bis
    /// irgendein unabhaengiger Grund den Screen neu zeichnete.
    ///
    /// Eine vergangene Zeile ist zurueckgenommen, aber lesbar: die
    /// Abblendung liegt auf der FLAECHE (surface), nicht auf der ganzen
    /// Karte. `.opacity(0.5)` ueber allem traf zuvor auch "VORBEI" (10pt)
    /// und die Dauer (11pt), die ohnehin in textFaint standen -- rund
    /// 1,7 : 1, weit unter jeder Schwelle, in einem Keller gelesen.
    /// Zurueckgenommen wird jetzt ueber die Flaeche und ueber den Wechsel
    /// des Kursnamens von `text` nach `textMuted`; jede Schrift der Zeile
    /// bleibt dabei ueber der Schwelle.
    private func terminZeile(
        _ termin: CourseWeekSession, jetzt: Date, herkunft: KurseHerkunft
    ) -> some View {
        let zustand = KursZustandRechner.zustand(fuer: termin, jetzt: jetzt)
        // woche.timezone, NICHT Zahlformat.uhrzeit: ein Kurstermin gehoert
        // dem Studio, nicht dem Geraet (KursZeit-Kommentar). `kurse.woche`
        // ist hier garantiert nicht nil -- diese Zeile wird ausschliesslich
        // aus termineDesTages gebaut, das nur bei geladenem Plan existiert.
        let zeitzone = kurse.woche?.timezone ?? zeitzoneFuerAnfrage
        let beginn = Zeitpunkt.parse(termin.startsAt)
        let istVorbei = zustand == .vorbei

        let kontur = kontur(zustand)

        return Button {
            beiAuswahl(termin.sessionId)
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(beginn.map { KursZeit.uhrzeit($0, zeitzone: zeitzone) } ?? "--:--")
                        .font(.system(size: 17, weight: .black).monospacedDigit())
                        .foregroundStyle(istVorbei ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    // textMuted statt textFaint: die Dauer ist tragend und
                    // steht bei 11pt, also unter den 15pt, ab denen
                    // textFaint zulaessig waere (designsystem.md SS2).
                    Text("\(termin.durationMin) min")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(termin.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(istVorbei ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    if let zeile = trainerUndRaum(termin) {
                        Text(zeile)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                    if zeigtBelegung(zustand), herkunft.zeigtBelegung {
                        // Leiste UND Zahl. Die Leiste ist kein Fuellstand,
                        // sondern ein Segment je Platz -- sie macht ohne
                        // Lesen erfassbar, was die Zahl exakt sagt, und
                        // faerbt Knappheit nicht als Fehlverhalten ein
                        // (deshalb weiterhin kein warngelber Balken).
                        //
                        // herkunft.zeigtBelegung ist die zweite Bedingung:
                        // eine Zahl von vorhin ist keine Zahl mehr (Spec
                        // 5.2), und eine Leiste von vorhin erst recht
                        // nicht. Der Banner oben sagt, dass sie deshalb
                        // fehlt -- sie verschwindet nicht wortlos.
                        BelegungZeile(
                            belegt: termin.bookedCount, kapazitaet: termin.capacity,
                            // In der eigenen Zeile ist Gruen schon vergeben
                            // ("das ist deiner"): die Leiste bleibt dort
                            // gedeckt, sonst traegt eine Farbe zwei
                            // Bedeutungen nebeneinander.
                            farbe: zustand == .angemeldet
                                ? DesignSystem.Color.textMuted : DesignSystem.Color.accent)
                    }
                }

                Spacer(minLength: 0)

                if kontur != nil {
                    marke(zustand, wartelistenplatz: herkunft.zeigtBelegung ? termin.ownWaitlistPosition : nil)
                } else {
                    HStack(spacing: DesignSystem.Spacing.s8) {
                        if let chip = chipInhalt(zustand) {
                            Text(chip.text)
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.7)
                                .foregroundStyle(chip.farbe)
                                .padding(.horizontal, DesignSystem.Spacing.s8)
                                .padding(.vertical, DesignSystem.Spacing.s4)
                                .overlay(Capsule().stroke(chip.farbe, lineWidth: 1))
                        }
                        // Der Chevron ist reine Affordanz, kein tragender
                        // Text -- textFaint ist dafuer ausdruecklich
                        // zugelassen.
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
                }
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Die Abblendung liegt auf der Flaeche, nicht auf der Zeile:
            // sonst traefe sie die Schrift mit (siehe Kommentar oben).
            .background(DesignSystem.Color.surface.opacity(istVorbei ? 0.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            // Kontur statt Chip (Festlegung 2 oben). Als overlay, nicht als
            // border: eine Kontur veraendert die Zeilenhoehe nicht, die
            // eigene Zeile bleibt also genau so hoch wie ihre Nachbarn.
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(kontur?.farbe ?? .clear, lineWidth: kontur?.staerke ?? 0))
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Kursdetails")
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
