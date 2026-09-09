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
    /// "Mo", "Di", ... -- wie designsystem.md SS10 (KursZeit-Kommentar):
    /// "ccc" (stand-alone), nicht "EEE", liefert das ohne Punkt.
    let kuerzel: String
    /// "Montag", "Dienstag", ... fuer die Tagesueberschrift und VoiceOver.
    let wochentagVoll: String
    let tagesnummer: Int
    let istHeute: Bool
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

    /// Die sieben Kalendertage Montag bis Sonntag, die `jetzt` enthaelt.
    static func wochentage(enthaelt jetzt: Date, zeitzone: String) -> [KurseWochentag] {
        let kalender = kalender(zeitzone: zeitzone)
        let heute = kalender.startOfDay(for: jetzt)
        let montag = montag(enthaelt: jetzt, zeitzone: zeitzone)

        let idFormatter = DateFormatter()
        // en_US_POSIX fuer ein rein numerisches, festes Muster -- dieselbe
        // Begruendung wie bei KursZeit.uhrzeit.
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.timeZone = kalender.timeZone
        idFormatter.dateFormat = "yyyy-MM-dd"

        let kuerzelFormatter = DateFormatter()
        kuerzelFormatter.locale = Locale(identifier: "de_DE")
        kuerzelFormatter.timeZone = kalender.timeZone
        kuerzelFormatter.dateFormat = "ccc"

        let vollFormatter = DateFormatter()
        vollFormatter.locale = Locale(identifier: "de_DE")
        vollFormatter.timeZone = kalender.timeZone
        vollFormatter.dateFormat = "EEEE"

        return (0..<7).map { versatz in
            let tag = kalender.date(byAdding: .day, value: versatz, to: montag) ?? montag
            return KurseWochentag(
                id: idFormatter.string(from: tag),
                kuerzel: kuerzelFormatter.string(from: tag),
                wochentagVoll: vollFormatter.string(from: tag),
                tagesnummer: kalender.component(.day, from: tag),
                istHeute: kalender.isDate(tag, inSameDayAs: heute))
        }
    }
}

/// Der Wochenplan der Kurse (Kurse.dc.html) -- Kopf mit Studioname,
/// Wochenstreifen, die Termine des gewaehlten Tages, Fussnote.
///
/// Vier Abweichungen vom Artboard (Spec Abschnitt 6), alle bewusst:
/// 1. Der warngelb gefuellte Wartelisten-Balken entfaellt ganz -- `warn`
///    ist nur als Kontur erlaubt, nie als Flaeche, und die Zahl "20 von 20"
///    sagt dasselbe wie der Balken, ohne Knappheit einzufaerben.
/// 2. Das Artboard traegt den Akzent vierfach (gewaehlter Tag, ein
///    Belegungsbalken, der ANGEMELDET-Chip, die "Meine Kurse"-Textfarbe).
///    Hier bleibt genau eine Akzentflaeche: der gewaehlte Tag im
///    Wochenstreifen. Kein Screen ohne Hauptaktion bleibt ohne Akzent, aber
///    er markiert dann den aktiven Wert und nichts sonst -- derselbe
///    Gedanke wie beim Uebungswechsel (UebungWechselnSheet).
/// 3. Chip-Radius ist eine Pille (999pt), nicht die 6px des Artboards.
/// 4. Alle vier Terminzeilen tragen denselben Chevron. Im Artboard traegt
///    nur eine von vieren eine Tap-Affordance, was den Rest wie tote
///    Information aussehen laesst.
struct KurseWochenView: View {
    let beiAuswahl: (CourseWeekSession) -> Void
    let beiMeineKurse: () -> Void

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

    /// Ab wann eine Belegungszahl nicht mehr als frisch durchgeht. Spec 5.2
    /// nennt den Grund: „12 von 16" veraltet binnen Minuten. Fuenf Minuten
    /// ist die Grenze, ab der der Screen es sagt statt es zu verschweigen
    /// -- nicht die Grenze, ab der die Zahl falsch WIRD (das weiss niemand),
    /// sondern die, ab der sie ohne Datum eine Behauptung waere.
    private static let frischeGrenze: TimeInterval = 5 * 60

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
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf
                wochenstreifen(jetzt: jetzt)
                heuteUndMeineKurse(jetzt: jetzt)
                if let hinweis = standHinweis(jetzt: jetzt) {
                    InlineBanner(tone: .muted, message: hinweis, icon: "clock.arrow.circlepath")
                }
                inhalt(jetzt: jetzt)
                fussnote
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: gewaehlterTagId)
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

    /// Sagt, wie alt die Zahlen sind, sobald sie nicht mehr frisch sind --
    /// und was dagegen hilft. Solange sie frisch sind, steht hier nichts:
    /// ein Datum ueber einer gerade geholten Zahl waere Rauschen.
    /// Dieselbe "Stand: ..."-Formulierung wie in KursDetailView und
    /// KurseMeineView, ueber Zahlformat.stand aus einer Quelle.
    private func standHinweis(jetzt: Date) -> String? {
        guard kurse.woche != nil, let stand = kurse.wocheStand else { return nil }
        guard jetzt.timeIntervalSince(stand) >= Self.frischeGrenze else { return nil }
        return "Diese Angaben stammen vom letzten Abruf. Stand: \(Zahlformat.stand(stand)). Zum Aktualisieren nach unten ziehen."
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

    // MARK: - Wochenstreifen -- die eine Akzentflaeche des Screens

    private func wochentage(jetzt: Date) -> [KurseWochentag] {
        KurseWochenBerechnung.wochentage(enthaelt: jetzt, zeitzone: zeitzoneFuerAnfrage)
    }

    private func heutigerTagId(jetzt: Date) -> String {
        wochentage(jetzt: jetzt).first { $0.istHeute }?.id ?? ""
    }

    private func gewaehlterTag(jetzt: Date) -> String {
        gewaehlterTagId ?? heutigerTagId(jetzt: jetzt)
    }

    private func wochenstreifen(jetzt: Date) -> some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(wochentage(jetzt: jetzt)) { tag in
                let ausgewaehlt = tag.id == gewaehlterTag(jetzt: jetzt)
                Button {
                    gewaehlterTagId = tag.id
                } label: {
                    VStack(spacing: DesignSystem.Spacing.s4) {
                        Text(tag.kuerzel.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1)
                        Text("\(tag.tagesnummer)")
                            .font(.system(size: 16, weight: .black).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    // Die einzige Akzentflaeche des Screens: nur der
                    // gewaehlte Tag traegt sie, kein anderes Element.
                    .background(ausgewaehlt ? DesignSystem.Color.accent : Color.clear)
                    .foregroundStyle(ausgewaehlt ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("\(tag.wochentagVoll), \(tag.tagesnummer).\(tag.istHeute ? " Heute." : "")")
                .accessibilityAddTraits(ausgewaehlt ? .isSelected : [])
            }
        }
    }

    // MARK: - "Heute · Donnerstag" und "Meine Kurse"

    private func tagesueberschrift(jetzt: Date) -> String {
        let gewaehlt = gewaehlterTag(jetzt: jetzt)
        guard let tag = wochentage(jetzt: jetzt).first(where: { $0.id == gewaehlt }) else { return "" }
        return tag.istHeute ? "Heute · \(tag.wochentagVoll)" : tag.wochentagVoll
    }

    private func heuteUndMeineKurse(jetzt: Date) -> some View {
        HStack {
            Text(tagesueberschrift(jetzt: jetzt).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Spacer()
            // Kein Akzent -- die eine Akzentflaeche des Screens ist der
            // gewaehlte Tag (siehe Abweichung 2 oben), nicht dieser Link.
            //
            // .frame(minHeight: 44) steht INNERHALB des Labels, nicht
            // aussen: aussen zentriert der Button bloss seinen Inhalt in
            // einem 44pt hohen Kasten, waehrend die Trefferflaeche die
            // Glyphenhoehe der 13pt-Schrift behaelt (~17pt). Und dieser
            // Knopf ist der einzige Weg zu "Meine Kurse" -- es gibt weder
            // Tab noch Deep Link.
            Button(action: beiMeineKurse) {
                Text("Meine Kurse")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
        }
    }

    // MARK: - Inhalt: Skelett, Leer, Offline, Fehler, Liste

    /// Reihenfolge ist Bedeutung: ein fehlgeschlagenes Laden gewinnt immer
    /// gegen `woche == nil` (sonst zeigte ein gescheitertes Nachladen
    /// wieder das Skelett statt Offline/Fehler), und `woche == nil` ohne
    /// Fehler ist immer das ERSTE Laden (nach einem Erfolg bleibt `woche`
    /// beim naechsten Fehlversuch zwar nil, aber der Fehlerzweig greift
    /// dann schon vorher).
    ///
    /// Offline vs. Serverfehler kommt jetzt aus dem Fehler selbst
    /// (`APIError.offline`), nicht mehr aus `netz.istOnline`: der
    /// Netzwerkmonitor kann in der Sekunde zwischen einem Timeout und der
    /// naechsten Reachability-Meldung kurz "online" zeigen, waehrend die
    /// Anfrage selbst laengst mit .offline gescheitert ist -- der
    /// tatsaechlich gefangene Fehler ist die verlässlichere Quelle.
    @ViewBuilder
    private func inhalt(jetzt: Date) -> some View {
        if case .fehlgeschlagen(let fehler) = kurse.ladeZustand {
            if fehler == .offline {
                offlineKarte
            } else {
                fehlerKarte(servertext(fuer: fehler))
            }
        } else if kurse.woche == nil {
            skelett
        } else if termineDesTages(jetzt: jetzt).isEmpty {
            leerZustand
        } else {
            VStack(spacing: DesignSystem.Spacing.s12) {
                ForEach(termineDesTages(jetzt: jetzt)) { termin in
                    terminZeile(termin, jetzt: jetzt)
                }
            }
        }
    }

    private func termineDesTages(jetzt: Date) -> [CourseWeekSession] {
        let gewaehlt = gewaehlterTag(jetzt: jetzt)
        return (kurse.woche?.sessions ?? [])
            .filter { $0.localDay == gewaehlt }
            .sorted {
                (KursZeitpunkt.parse($0.startsAt) ?? .distantPast)
                    < (KursZeitpunkt.parse($1.startsAt) ?? .distantPast)
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
    /// -- derselbe Ton fuer denselben Zustand. "Meine Kurse" bleibt
    /// erreichbar (der Link oben ist reiner Client-Zustand, kein
    /// Netzzugriff), das sagt der zweite Satz ausdruecklich.
    private var offlineKarte: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("Kein Empfang")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Der Wochenplan braucht Empfang. „Meine Kurse“ bleibt verfügbar.")
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

    /// Zeigt den Servertext woertlich (`text`, aus `servertext(fuer:)`) --
    /// jetzt moeglich, weil KurseStore.laden(...) den gefangenen APIError
    /// seit dem Review zu Aufgabe 9 durchreicht statt ihn zu verwerfen
    /// (`KurseLadeZustand.fehlgeschlagen(APIError)`). Der zweite Satz sagt,
    /// was trotzdem gilt (designsystem.md SS5: Fehler sagen, was falsch
    /// ist UND was gilt).
    private func fehlerKarte(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.danger)
                Text("Deine eigenen Kurse bleiben über „Meine Kurse“ sichtbar.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
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
    private func servertext(fuer fehler: APIError) -> String {
        switch fehler {
        case .offline:
            "Keine Verbindung."
        case .unauthorized(let message), .validation(let message),
             .notFound(let message), .conflict(let message), .server(let message):
            message
        case .encodingFailed:
            "Die Anfrage konnte nicht gesendet werden."
        case .decodingFailed:
            "Die Antwort deines Studios ließ sich nicht lesen."
        }
    }

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
        case .angemeldet: ("ANGEMELDET", DesignSystem.Color.textMuted)
        case .warteliste: ("WARTELISTE", DesignSystem.Color.textMuted)
        case .abgesagt: ("ABGESAGT", DesignSystem.Color.warn)
        case .frei, .voll: nil
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
    private func terminZeile(_ termin: CourseWeekSession, jetzt: Date) -> some View {
        let zustand = KursZustandRechner.zustand(fuer: termin, jetzt: jetzt)
        // woche.timezone, NICHT Zahlformat.uhrzeit: ein Kurstermin gehoert
        // dem Studio, nicht dem Geraet (KursZeit-Kommentar). `kurse.woche`
        // ist hier garantiert nicht nil -- diese Zeile wird ausschliesslich
        // aus termineDesTages gebaut, das nur bei geladenem Plan existiert.
        let zeitzone = kurse.woche?.timezone ?? zeitzoneFuerAnfrage
        let beginn = KursZeitpunkt.parse(termin.startsAt)
        let istVorbei = zustand == .vorbei

        return Button {
            beiAuswahl(termin)
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
                    if zeigtBelegung(zustand) {
                        // Die Zahl statt eines Balkens (Abweichung 1 oben):
                        // "12 von 16" sagt dasselbe wie ein Fuellstand, ohne
                        // Knappheit als Fehlverhalten einzufaerben.
                        Text("\(termin.bookedCount) von \(termin.capacity)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                }

                Spacer(minLength: 0)

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
                    // Der Chevron ist reine Affordanz, kein tragender Text
                    // -- textFaint ist dafuer ausdruecklich zugelassen.
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Die Abblendung liegt auf der Flaeche, nicht auf der Zeile:
            // sonst traefe sie die Schrift mit (siehe Kommentar oben).
            .background(DesignSystem.Color.surface.opacity(istVorbei ? 0.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
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
