import SwiftUI

/// Die Hauptaktion eines Kurstermins -- ein Teil der Sechsertabelle (Spec
/// Abschnitt 5.3). Zwei der sechs Zustaende haben keine (`.abgesagt`,
/// `.vorbei`); die anderen vier fuehren auf genau zwei Store-Aufrufe:
/// `.anmelden`/`.aufWarteliste` rufen `buchen(sessionId:)` (der Server
/// entscheidet selbst, ob der Platz gebucht oder gewartelistet wird --
/// `BookOutcome.result`), `.abmelden`/`.wartelisteVerlassen` rufen
/// `stornieren(sessionId:)` (dieselbe DELETE-Route entfernt die eigene
/// Buchung unabhaengig davon, ob sie gebucht oder gewartelistet war).
enum KursDetailHauptaktion: Equatable {
    case anmelden
    case aufWarteliste
    case abmelden
    case wartelisteVerlassen

    var titel: String {
        switch self {
        case .anmelden: "Anmelden"
        case .aufWarteliste: "Auf die Warteliste"
        case .abmelden: "Abmelden"
        case .wartelisteVerlassen: "Warteliste verlassen"
        }
    }

    var istBuchen: Bool {
        switch self {
        case .anmelden, .aufWarteliste: true
        case .abmelden, .wartelisteVerlassen: false
        }
    }
}

/// Die Sechsertabelle selbst: Zustand -> Hauptaktion und Fusstext -- eine
/// reine Ableitung, absichtlich getrennt vom View, damit sie ohne UI
/// testbar ist (`KursDetailInhaltTests`).
///
/// `abmeldenBisUhrzeit`/`wartelistenplatz` kommen bereits aufgeloest von
/// aussen: eine erfundene Uhrzeit oder Position waere schlimmer als eine
/// fehlende Zeile (Aufgabenbrief) -- liefert die aufrufende Stelle `nil`
/// (unlesbarer Beginn bzw. keine bekannte Position, z. B. ohne Netz),
/// entfaellt die jeweilige Fusszeile ersatzlos.
///
/// `abmeldefristVerstrichen` ist **kein siebter Zustand** -- die Spec
/// kennt sechs, und `KursZustand` bleibt unveraendert. Es ist eine zweite,
/// orthogonale Ableitung, die nur `.angemeldet` betrifft: sobald die Frist
/// verstrichen ist, verschwindet "Abmelden" (kein deaktivierter Knopf, der
/// Wirkung vortaeuscht -- dieselbe Regel wie bei `.abgesagt`/`.vorbei`),
/// und der Fusstext sagt, was gilt. `.warteliste` bleibt davon
/// unberuehrt: `cancel_course_booking` (0038_kurse_nachlese.sql) prueft
/// die Frist ausdruecklich nur fuer `v_buchung.status = 'booked'` -- ein
/// Wartelistenplatz laesst sich jederzeit bis Kursbeginn verlassen, ohne
/// Frist. Review-Fund (Aufgabe 10, Nachtrag).
enum KursDetailInhalt {
    static func hauptaktion(
        fuer zustand: KursZustand, abmeldefristVerstrichen: Bool
    ) -> KursDetailHauptaktion? {
        switch zustand {
        case .abgesagt, .vorbei: nil
        case .angemeldet: abmeldefristVerstrichen ? nil : .abmelden
        case .warteliste: .wartelisteVerlassen
        case .frei: .anmelden
        case .voll: .aufWarteliste
        }
    }

    /// Wortlaut exakt aus dem Aufgabenbrief (Spec Abschnitt 5.3), Ziffer
    /// fuer Ziffer. `.angemeldet` und `.frei` teilen sich denselben Satz --
    /// bei `.frei` ist das die Frist, "damit sie vor der Zusage bekannt
    /// ist" (Aufgabenbrief), nicht ein eigener Wortlaut. Der Satz nach
    /// verstrichener Frist ist eigener Wortlaut (Review-Fund): sagt, was
    /// nicht mehr geht (kein "Abmelden" mehr da) und was gilt (der Platz
    /// bleibt reserviert) -- SS5.
    static func fusstext(
        fuer zustand: KursZustand, abmeldenBisUhrzeit: String?,
        abmeldefristVerstrichen: Bool, wartelistenplatz: Int?
    ) -> String? {
        switch zustand {
        case .abgesagt:
            "Dein Studio hat diesen Termin abgesagt."
        case .vorbei:
            "Dieser Termin ist vorbei."
        case .angemeldet:
            if abmeldefristVerstrichen {
                "Die Abmeldefrist ist verstrichen. Dein Platz bleibt reserviert."
            } else {
                abmeldenBisUhrzeit.map { "Abmelden ist bis \($0) möglich." }
            }
        case .frei:
            abmeldenBisUhrzeit.map { "Abmelden ist bis \($0) möglich." }
        case .warteliste:
            wartelistenplatz.map { "Du stehst auf Platz \($0)." }
        case .voll:
            "Alle Plätze sind vergeben."
        }
    }

    /// Ob die Abmeldefrist zum Zeitpunkt `jetzt` bereits verstrichen ist --
    /// derselbe Zeitpunkt wie `KursZustandRechner.abmeldenBis`, hier als
    /// Vergleich statt als Anzeige. `>=`, derselbe Grenzfall wie beim
    /// Kursbeginn selbst (`KursZustandRechner.zustand`): auf die Sekunde
    /// genau gilt die Frist bereits als verstrichen, nicht erst eine
    /// Sekunde danach.
    ///
    /// Ein unlesbarer Beginn liefert `false`, nicht `true`: nicht
    /// nachweisbar verstrichen ist etwas anderes als nachweisbar nicht
    /// verstrichen, und `false` ist hier die sicherere Seite -- sonst
    /// verschwaende der einzige Abmelden-Weg wegen eines Datenfehlers,
    /// statt nur die Uhrzeit-Zeile wegzulassen (wie beim unlesbaren Beginn
    /// oben, Aufgabenbrief).
    static func abmeldefristVerstrichen(startsAt: String, fristStunden: Int, jetzt: Date) -> Bool {
        guard let deadline = KursZustandRechner.abmeldenBis(startsAt: startsAt, fristStunden: fristStunden)
        else { return false }
        return jetzt >= deadline
    }
}

/// Die schmale Zustandsauswertung fuer einen ohne Netz gespeicherten
/// Termin (`GespeicherterTermin`) -- `KursZustandRechner.zustand(fuer:)`
/// nimmt eine volle `CourseWeekSession`, die es ohne Netz nicht gibt
/// (Aufgabenbrief, Hinweis 4). Dieselbe Auswertungsreihenfolge wie dort:
/// abgesagt schlaegt vorbei, vorbei schlaegt den eigenen Status.
///
/// `KurseFileStore` persistiert ausschliesslich Termine mit eigenem Status
/// (`ownStatus != nil`) -- `.frei`/`.voll` sind hier deshalb strukturell
/// unerreichbar, nicht nur unwahrscheinlich: ein Termin ohne eigene
/// Buchung landet nie auf der Platte.
enum KursDetailOfflineZustand {
    static func zustand(fuer termin: GespeicherterTermin, jetzt: Date) -> KursZustand {
        if termin.status == "cancelled" { return .abgesagt }
        if let beginn = KursZeitpunkt.parse(termin.startsAt), beginn <= jetzt { return .vorbei }
        return termin.ownStatus == "waitlisted" ? .warteliste : .angemeldet
    }
}

/// Der Screen eines einzelnen Kurstermins (`KursDetail.dc.html`): Datum,
/// Kursname, Eckdaten, Beschreibung, Studio-Zuschreibung, Hauptaktion,
/// Fusstext.
///
/// Der Termin wird ausschliesslich aus dem Store gelesen (nicht als Wert
/// durchgereicht), damit er nach Buchen/Stornieren aktuell bleibt --
/// `KurseStore.buchen`/`.stornieren` laden nach jedem Versuch neu.
///
/// **Drei Abweichungen vom Artboard (Spec Abschnitt 6), alle vorgegeben:**
/// 1. Zwei Akzentflaechen werden eine: das Artboard faerbt sowohl das
///    Datum als auch die Plaetze-Zahl samt Belegungsbalken in `accent`.
///    Hier traegt ausschliesslich die Hauptaktion den Akzent -- Datum und
///    Plaetze-Zahl sind `textMuted`/`text`, der Balken entfaellt ganz
///    (dieselbe Entscheidung wie in `KurseWochenView`: eine Zahl sagt
///    dasselbe wie ein Fuellstand, ohne Knappheit einzufaerben).
/// 2. Sechs Zustaende statt des einen im Artboard (`.frei`) -- die ganze
///    Sechsertabelle oben.
/// 3. "Bis 2 Stunden" ist im Artboard hartkodiert; hier kommt die Frist
///    aus `CourseWeek.cancellationDeadlineHours` bzw.
///    `GespeicherteBuchungen.cancellationDeadlineHours`, als Uhrzeit ueber
///    `KursZustandRechner.abmeldenBis`.
///
/// **Eigene Ergaenzungen, keine der drei benannten Abweichungen -- bitte
/// im Review pruefen:**
/// - Die "Plaetze"-Karte des Artboards (eigene Flaeche mit Balken) ist
///   eine vierte Eckdaten-Zeile geworden, wie der Aufgabenbrief die
///   Eckdaten selbst aufzaehlt ("Beginn, Trainer, Ort, Plaetze") --
///   weniger Flaechen, ein Balken weniger, der sowieso keine Akzentflaeche
///   mehr sein durfte.
/// - Der Fusstext (das "Darunter" der Sechsertabelle) steht in
///   `textMuted`, nicht im `textFaint` des Artboards: in den beiden
///   aktionslosen Zustaenden ist er die EINZIGE Information des Screens
///   ueber den Zustand, in den anderen vieren die tragende Frist-/
///   Positionsangabe -- "im Zweifel text-muted" (Aufgabenbrief).
/// - Der Artboard-Chevron ("< Kurse") oben ist NICHT nachgebaut: die
///   Signatur dieser Aufgabe (`KursDetailView { let sessionId: String }`)
///   gibt keinen Ruecksprung-Callback her, und ein Chevron ohne
///   Wirkung waere genau der stumme Knopf, den die Global Constraints
///   ausdruecklich verbieten. Aufgabe 12 pusht diesen Screen auf einen
///   `NavigationStack` -- der Zurueck-Pfeil kommt von dort, kostenlos und
///   funktionsfaehig, ohne dass diese Datei ihn selbst zeichnet.
/// - Das Artboard-Beispiel "Donnerstag, 27. August" widerspricht
///   designsystem.md SS10 ("Mi, 27. August") und damit dem bereits
///   gebauten `KursZeit.datumAusgeschrieben` (Kurzform "ccc, d. MMMM").
///   Diese Datei folgt der Spec und der bestehenden Funktion, nicht dem
///   Artboard-Beispiel -- siehe Bericht.
/// - Der obere Banner "Ohne Empfang. Stand: ..." (nur im Offline-Zweig)
///   traegt Ton `.muted`, nicht `.danger`: die gezeigten Daten sind
///   ehrlich, nur aelter -- kein Fehlschlag (Aufgabenbrief, Hinweis 1).
///   `.danger` bleibt fuer einen tatsaechlich fehlgeschlagenen
///   Buchungs-/Stornierungsversuch reserviert (`fehlermeldung` unten). Die
///   Stand-Zeitangabe kommt aus `GespeicherteBuchungen.stand`: ohne sie
///   waere der Cache eine stille Behauptung (dieselbe Begruendung wie bei
///   `KurseFileStore`).
///
/// **Die Uhr laeuft mit, waehrend der Screen offen bleibt (Review-Fund,
/// Aufgabe 10 Nachtrag):** `body` ist in eine `TimelineView(.periodic(from:
/// .now, by: 60))` gefasst, nach dem Muster aus `TrainingRootView`
/// (Aufgabe 5) -- `@Observable` meldet den Ablauf einer Frist nicht von
/// selbst, weil sich dabei keine beobachtete Eigenschaft aendert. Die
/// Umschaltung haengt an der Stelle, die der Tick wirklich erreicht: der
/// gesamte Inhalt (`quelle(jetzt:)`, `TerminAnsicht.jetzt`,
/// `aktionsBereich`) wird MIT `context.date` neu berechnet, nicht mit
/// einem beim ersten Aufbau eingefrorenen `Date()`. Betrifft zwei
/// Ableitungen gleichermassen: den Kursbeginn selbst (`.vorbei`) und die
/// Abmeldefrist (`abmeldefristVerstrichen`) -- beide vergleichen einen
/// gespeicherten Zeitpunkt gegen "jetzt" und waeren sonst gleichermassen
/// stehengeblieben.
///
/// **Bekannte Luecke, nicht in dieser Aufgabe behebbar:** Der Server
/// nimmt eine BUCHUNG aus, die durch automatisches Nachruecken von der
/// Warteliste entstand (`promoted_at is null`-Bedingung in
/// `cancel_course_booking`, 0038_kurse_nachlese.sql) -- eine nachgerueckte
/// Person kann jederzeit bis Kursbeginn abmelden, ohne Frist, weil sie den
/// Platz nie freiwillig angenommen hat. `CourseWeekSession`/
/// `GespeicherterTermin` tragen kein Feld dafuer; der Client kann eine
/// nachgerueckte von einer urspruenglich gebuchten Person nicht
/// unterscheiden. Diese Datei berechnet `abmeldefristVerstrichen` deshalb
/// so, als gaelte die Frist immer -- fuer eine nachgerueckte Person
/// verschwindet "Abmelden" hier moeglicherweise, obwohl der Server es noch
/// zuliesse. Das zu schliessen braucht ein neues API-Feld, ausserhalb des
/// Umfangs dieser Aufgabe -- siehe Bericht.
struct KursDetailView: View {
    let sessionId: String

    @Environment(KurseStore.self) private var kurse
    @Environment(CatalogStore.self) private var katalog

    @State private var aktionLaeuft = false
    @State private var fehlermeldung: String?

    var body: some View {
        // 60-Sekunden-Kadenz statt einer einmalig beim Aufbau gelesenen
        // Date() -- sonst blieben sowohl der Kursbeginn-Uebergang
        // (.vorbei) als auch die Abmeldefrist auf dem Stand des ersten
        // Renderns stehen, bis irgendein unabhaengiger Grund den Screen
        // neu zeichnet (siehe Datei-Kopfkommentar).
        TimelineView(.periodic(from: .now, by: 60)) { context in
            screenInhalt(jetzt: context.date)
        }
    }

    @ViewBuilder
    private func screenInhalt(jetzt: Date) -> some View {
        switch quelle(jetzt: jetzt) {
        case .online(let ansicht), .offline(let ansicht):
            inhalt(ansicht, herkunft: herkunft(jetzt: jetzt))
        case .keineDaten:
            keineDatenInhalt
        }
    }

    // MARK: - Wie alt die Angaben sind

    /// Dieselbe Ableitung wie in KurseWochenView und KurseMeineView --
    /// eine Loesung fuer dieselbe Sache, siehe KurseHerkunft.
    ///
    /// Dieser Screen laedt nicht selbst; er lebt von dem, was der
    /// Wochenplan geholt hat. Genau deshalb braucht er die Regel: "12 von
    /// 16" stand hier ohne jede Altersangabe, auch Stunden nach dem
    /// letzten Abruf, und direkt darunter loest das Mitglied eine Buchung
    /// aus.
    private func herkunft(jetzt: Date) -> KurseHerkunft {
        KurseHerkunft.bilden(
            ladeZustand: kurse.ladeZustand, wocheStand: kurse.wocheStand, jetzt: jetzt)
    }

    /// Der Zeitpunkt, den der Hinweis nennt: was dieser Screen gerade
    /// zeigt. Kommt der Termin aus `woche`, ist es deren Abrufzeitpunkt;
    /// faellt er auf den Cache zurueck, dessen Stand.
    private var angezeigterStand: Date? {
        kurse.woche != nil ? kurse.wocheStand : kurse.eigene?.stand
    }

    // MARK: - Datenquelle: online (voll) oder offline (schmal)

    /// Vereinheitlichte Sicht auf einen Termin, unabhaengig davon, ob er
    /// aus `store.woche` (online, volle Daten) oder `store.eigene`
    /// (offline, schmaler Cache) stammt.
    private struct TerminAnsicht {
        let name: String
        let description: String?
        let startsAt: String
        let durationMin: Int
        let room: String?
        let instructorName: String?
        let zustand: KursZustand
        let zeitzone: String
        let fristStunden: Int
        /// Derselbe Zeitpunkt, mit dem `zustand` berechnet wurde -- aus
        /// dem 60-Sekunden-Tick der `TimelineView` in `body`, nicht aus
        /// einem frisch erzeugten `Date()` (siehe Datei-Kopfkommentar).
        /// `aktionsBereich` braucht ihn zusaetzlich fuer den Vergleich
        /// gegen die Abmeldefrist.
        let jetzt: Date
        /// `nil` ohne Netz -- `GespeicherterTermin` traegt keine
        /// Belegungszahlen (Aufgabenbrief, Hinweis 3).
        let belegung: (belegt: Int, kapazitaet: Int)?
        /// `nil` ohne Netz -- eine Wartelistenposition aendert sich ohne
        /// Zutun des Mitglieds und ist ohne frischen Abruf nicht haltbar
        /// (Aufgabenbrief, Hinweis 3).
        let wartelistenplatz: Int?
    }

    private enum Quelle {
        case online(TerminAnsicht)
        case offline(TerminAnsicht)
        /// Weder in `store.woche` noch in `store.eigene` gefunden -- noch
        /// nicht geladen, oder das Laden ist gescheitert.
        case keineDaten
    }

    private func quelle(jetzt: Date) -> Quelle {
        if let woche = kurse.woche, let termin = woche.sessions.first(where: { $0.sessionId == sessionId }) {
            return .online(ansicht(aus: termin, in: woche, jetzt: jetzt))
        }
        if let eigene = kurse.eigene, let termin = eigene.termine.first(where: { $0.sessionId == sessionId }) {
            return .offline(ansicht(aus: termin, in: eigene, jetzt: jetzt))
        }
        return .keineDaten
    }

    private func ansicht(aus termin: CourseWeekSession, in woche: CourseWeek, jetzt: Date) -> TerminAnsicht {
        TerminAnsicht(
            name: termin.name,
            description: termin.description,
            startsAt: termin.startsAt,
            durationMin: termin.durationMin,
            room: termin.room,
            instructorName: termin.instructorName,
            zustand: KursZustandRechner.zustand(fuer: termin, jetzt: jetzt),
            zeitzone: woche.timezone,
            fristStunden: woche.cancellationDeadlineHours,
            jetzt: jetzt,
            belegung: (belegt: termin.bookedCount, kapazitaet: termin.capacity),
            wartelistenplatz: termin.ownWaitlistPosition)
    }

    private func ansicht(aus termin: GespeicherterTermin, in eigene: GespeicherteBuchungen, jetzt: Date) -> TerminAnsicht {
        TerminAnsicht(
            name: termin.name,
            description: termin.description,
            startsAt: termin.startsAt,
            durationMin: termin.durationMin,
            room: termin.room,
            instructorName: termin.instructorName,
            zustand: KursDetailOfflineZustand.zustand(fuer: termin, jetzt: jetzt),
            zeitzone: eigene.timezone,
            fristStunden: eigene.cancellationDeadlineHours,
            jetzt: jetzt,
            belegung: nil,
            wartelistenplatz: nil)
    }

    // MARK: - Inhalt bei vorhandenen Daten

    private func inhalt(_ ansicht: TerminAnsicht, herkunft: KurseHerkunft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                if let hinweis = herkunft.satz(
                    stand: angezeigterStand,
                    zusatz: ansicht.belegung == nil ? nil : "Die freien Plätze lassen wir deshalb weg.") {
                    InlineBanner(tone: .muted, message: hinweis, icon: herkunft.symbol)
                }
                kopf(ansicht)
                eckdaten(ansicht, herkunft: herkunft)
                beschreibung(ansicht)
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            aktionsBereich(ansicht)
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s12)
                .padding(.bottom, DesignSystem.Spacing.s16)
                .background(DesignSystem.Color.bg)
        }
    }

    // MARK: - Kopf: Datum + Kursname

    private func kopf(_ ansicht: TerminAnsicht) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            // KursZeit.datumAusgeschrieben, nicht Zahlformat.uhrzeit -- ein
            // Kurstermin gehoert der Studio-Zeitzone (Aufgabenbrief,
            // Hinweis 5). Unlesbarer Beginn: die Zeile entfaellt, statt ein
            // erfundenes Datum zu zeigen.
            if let beginn = KursZeitpunkt.parse(ansicht.startsAt) {
                Text(KursZeit.datumAusgeschrieben(beginn, zeitzone: ansicht.zeitzone))
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Text(ansicht.name.uppercased())
                .font(DesignSystem.Typography.screentitel)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
        }
    }

    // MARK: - Eckdaten: Beginn, Trainer, Ort, Plaetze

    private func eckdaten(_ ansicht: TerminAnsicht, herkunft: KurseHerkunft) -> some View {
        let zeitraum = zeitraumText(ansicht)
        let platz = platzText(ansicht, herkunft: herkunft)
        return VStack(spacing: 0) {
            eckdatenZeile(icon: "clock", label: "Beginn", wert: zeitraum)
            if let trainer = ansicht.instructorName {
                trenner
                eckdatenZeile(icon: "person", label: "Trainer", wert: trainer)
            }
            if let ort = ansicht.room {
                trenner
                eckdatenZeile(icon: "mappin.and.ellipse", label: "Ort", wert: ort)
            }
            if let platz {
                trenner
                eckdatenZeile(icon: "person.2", label: "Plätze", wert: platz)
            }
        }
        .background(DesignSystem.Color.surface)
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der 1pt-Kontur weg (Vorlage: InlineBanner).
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }

    private var trenner: some View {
        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
    }

    /// `monospacedDigit()` steht pauschal auf jedem Wert, auch auf Text
    /// ohne Ziffern (Trainername, Raum): die Eigenschaft wirkt nur auf
    /// Ziffern-Glyphen, Buchstaben bleiben unveraendert -- eine Fallunter-
    /// scheidung "istZahl" waere hier reine Redundanz.
    private func eckdatenZeile(icon: String, label: String, wert: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textMuted)
            Spacer()
            Text(wert)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func zeitraumText(_ ansicht: TerminAnsicht) -> String {
        guard let beginn = KursZeitpunkt.parse(ansicht.startsAt) else { return "–" }
        let ende = beginn.addingTimeInterval(Double(ansicht.durationMin) * 60)
        return "\(KursZeit.uhrzeit(beginn, zeitzone: ansicht.zeitzone)) – \(KursZeit.uhrzeit(ende, zeitzone: ansicht.zeitzone))"
    }

    /// Wie in `KurseWochenView.zeigtBelegung`: nur bei `.frei`, `.voll`,
    /// `.angemeldet`, `.warteliste` -- nie bei `.vorbei`/`.abgesagt` (keine
    /// Information mehr fuer einen nicht mehr buch-/stornierbaren Termin)
    /// und nie ohne Netz (`belegung == nil`, Aufgabenbrief Hinweis 3).
    ///
    /// Und nie, wenn der Abruf zu lange her ist oder gescheitert ist
    /// (`herkunft.zeigtBelegung`, Spec 5.2): eine Zahl von vorhin ist
    /// keine Zahl mehr. Die Zeile faellt dann ganz weg -- der Banner oben
    /// sagt, dass sie deshalb fehlt.
    private func platzText(_ ansicht: TerminAnsicht, herkunft: KurseHerkunft) -> String? {
        guard herkunft.zeigtBelegung, let belegung = ansicht.belegung else { return nil }
        switch ansicht.zustand {
        case .frei, .voll, .angemeldet, .warteliste:
            return "\(belegung.belegt) von \(belegung.kapazitaet)"
        case .vorbei, .abgesagt:
            return nil
        }
    }

    // MARK: - Beschreibung + Studio-Zuschreibung

    @ViewBuilder
    private func beschreibung(_ ansicht: TerminAnsicht) -> some View {
        if let text = ansicht.description, !text.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                Text("Worum es geht")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(4)
                if !studioName.isEmpty {
                    Text("Kursbeschreibung von \(studioName).")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
            }
        }
    }

    private var studioName: String {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name ?? ""
    }

    // MARK: - Hauptaktion + Fusstext -- die eine Akzentflaeche des Screens

    /// Die Hauptaktion ist die EINZIGE Akzentflaeche des Screens (Global
    /// Constraints). In den beiden aktionslosen Zustaenden (`.abgesagt`,
    /// `.vorbei`) gibt es hier folgerichtig gar keine: ein Screen ohne
    /// Hauptaktion hat keinen aktiven Wert, den der Akzent markieren
    /// muesste -- statt eines Knopfs steht der Fusstext allein, und der
    /// ist nie stumm (er sagt ausdruecklich, warum nichts zu tun ist).
    private func aktionsBereich(_ ansicht: TerminAnsicht) -> some View {
        let verstrichen = KursDetailInhalt.abmeldefristVerstrichen(
            startsAt: ansicht.startsAt, fristStunden: ansicht.fristStunden, jetzt: ansicht.jetzt)
        let hauptaktion = KursDetailInhalt.hauptaktion(
            fuer: ansicht.zustand, abmeldefristVerstrichen: verstrichen)
        let fusstext = KursDetailInhalt.fusstext(
            fuer: ansicht.zustand,
            abmeldenBisUhrzeit: abmeldenBisUhrzeit(ansicht),
            abmeldefristVerstrichen: verstrichen,
            wartelistenplatz: ansicht.wartelistenplatz)

        return VStack(spacing: DesignSystem.Spacing.s8) {
            // `hauptaktion != nil` als Bedingung: ohne Knopf ist der
            // Banner gegenstandslos. Laeuft die Abmeldefrist zwischen
            // einem gescheiterten Versuch und dem naechsten Tick ab, stand
            // sonst gleichzeitig der rote Banner und der Fusstext da, der
            // dasselbe schon sagt -- und es gab keinen Knopf mehr, mit dem
            // sich der Banner haette loeschen lassen.
            if let fehlermeldung, hauptaktion != nil {
                // Servertext woertlich -- nur der Server weiss, ob der
                // Platz gerade vergeben wurde oder die Frist vorbei ist
                // (Aufgabenbrief). Ausnahme: `.offline`, siehe
                // aktionsfehler(_:istBuchen:).
                InlineBanner(tone: .danger, message: fehlermeldung)
            }
            if let hauptaktion {
                PrimaryButton(title: hauptaktion.titel, isLoading: aktionLaeuft) {
                    await ausfuehren(hauptaktion)
                }
            }
            if let fusstext {
                Text(fusstext)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// `KursZustandRechner.abmeldenBis` mit der Frist des Studios
    /// (`cancellationDeadlineHours`), nicht der hartkodierten Zwei aus dem
    /// Artboard -- formatiert in der Studio-Zeitzone. `nil` bei
    /// unlesbarem Beginn: eine erfundene Uhrzeit waere schlimmer als
    /// keine (Aufgabenbrief).
    private func abmeldenBisUhrzeit(_ ansicht: TerminAnsicht) -> String? {
        guard let deadline = KursZustandRechner.abmeldenBis(
            startsAt: ansicht.startsAt, fristStunden: ansicht.fristStunden)
        else { return nil }
        return KursZeit.uhrzeit(deadline, zeitzone: ansicht.zeitzone)
    }

    /// Buchen und Stornieren behandeln `.decodingFailed` bereits selbst
    /// als Erfolg (KurseStore-Kommentar) -- hier gibt es dazu nichts zu
    /// tun.
    ///
    /// Beim BUCHEN gilt weiterhin: schlaegt es fehl, bleibt dieselbe,
    /// clientseitig erzeugte Buchungskennung im Store stehen
    /// (`KurseStore.buchungskennungen`); ein erneuter Tap auf denselben
    /// Knopf loest keine zweite Buchung aus, sondern denselben
    /// Wiederholungsversuch. Genau das sagt der Offline-Satz unten zu.
    ///
    /// Beim STORNIEREN gilt es seit M4 ausdruecklich NICHT mehr:
    /// `stornieren(...)` raeumt die Kennung auf, bevor es den Aufruf
    /// abschickt. Eine Stornierung beendet die Buchung, zu der die Kennung
    /// gehoert -- eine spaetere Anmeldung ist fachlich eine neue und
    /// bekommt deshalb eine frische. Bliebe die alte stehen, antwortete
    /// der Server dauerhaft mit `booking_id_reused`.
    private func ausfuehren(_ hauptaktion: KursDetailHauptaktion) async {
        aktionLaeuft = true
        fehlermeldung = nil
        do {
            if hauptaktion.istBuchen {
                try await kurse.buchen(sessionId: sessionId)
            } else {
                try await kurse.stornieren(sessionId: sessionId)
            }
        } catch {
            fehlermeldung = aktionsfehler(error, istBuchen: hauptaktion.istBuchen)
        }
        aktionLaeuft = false
    }

    /// Der Aktionspfad braucht fuer `.offline` eine eigene Formulierung,
    /// genau wie der Ladepfad sie hat -- und aus einem staerkeren Grund:
    /// hier weiss der Client NICHT, was gilt. `APIClient.execute` bildet
    /// jeden Transportfehler auf `.offline` ab, also auch die
    /// Zeitueberschreitung, bei der die Buchung beim Server laengst
    /// angelegt ist und nur die Antwort verloren ging. "Keine Verbindung."
    /// allein sagt dann, was nicht stimmt, aber nicht, was gilt (SS5) --
    /// und "fehlgeschlagen" waere eine Behauptung, die niemand pruefen
    /// konnte.
    ///
    /// Der Satz ueber die zweite Anmeldung ist die Zusicherung, die die
    /// clientseitig erzeugte Buchungskennung ueberhaupt erst gibt
    /// (KurseStore.buchungskennungen): ein Wiederholer schickt dieselbe
    /// Kennung, der Server erkennt sie und legt nichts zweites an.
    private func aktionsfehler(_ fehler: APIError, istBuchen: Bool) -> String {
        guard fehler == .offline else { return fehler.servertext }
        return istBuchen
            ? "Kein Empfang. Ob deine Anmeldung angekommen ist, wissen wir gerade nicht. Versuch es noch einmal, sobald du Empfang hast — eine zweite Anmeldung entsteht dabei nicht."
            : "Kein Empfang. Ob deine Abmeldung angekommen ist, wissen wir gerade nicht — dein Platz kann noch besetzt sein. Versuch es noch einmal, sobald du Empfang hast."
    }

    // MARK: - Kein Termin gefunden: laedt noch, oder das Laden ist gescheitert

    @ViewBuilder
    private var keineDatenInhalt: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                if case .fehlgeschlagen(let fehler) = kurse.ladeZustand {
                    if fehler == .offline {
                        offlineKarte
                    } else {
                        fehlerKarte(fehler.servertext)
                    }
                } else {
                    skelett
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
    }

    /// Reine Flaechen ohne Text/Zahl, wie `KurseWochenView.skelett` -- ein
    /// Ladezustand ist nie stumm (VoiceOver-Label statt Stille).
    private var skelett: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .frame(height: 96)
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .frame(height: 64)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kursdetails werden geladen")
    }

    /// Dieselbe Form wie `KurseWochenView.offlineKarte` (Aufgabenbrief,
    /// Hinweis 1: "Halt es genauso") -- "Kein Empfang", nie
    /// "fehlgeschlagen".
    private var offlineKarte: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text("Kein Empfang")
                    .font(.system(size: 15, weight: .semibold))
                Text("Dieser Kurs braucht Empfang, um geladen zu werden.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(DesignSystem.Color.danger)
        .padding(DesignSystem.Spacing.s12)
        .background(DesignSystem.Color.danger.opacity(0.1))
        // clipShape VOR overlay, siehe eckdaten.
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func fehlerKarte(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.danger)
            Text("Deine gespeicherten Kurse bleiben unverändert.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

}
