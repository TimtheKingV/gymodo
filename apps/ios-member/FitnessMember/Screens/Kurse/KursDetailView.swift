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
enum KursDetailInhalt {
    static func hauptaktion(fuer zustand: KursZustand) -> KursDetailHauptaktion? {
        switch zustand {
        case .abgesagt, .vorbei: nil
        case .angemeldet: .abmelden
        case .warteliste: .wartelisteVerlassen
        case .frei: .anmelden
        case .voll: .aufWarteliste
        }
    }

    /// Wortlaut exakt aus dem Aufgabenbrief (Spec Abschnitt 5.3), Ziffer
    /// fuer Ziffer. `.angemeldet` und `.frei` teilen sich denselben Satz --
    /// bei `.frei` ist das die Frist, "damit sie vor der Zusage bekannt
    /// ist" (Aufgabenbrief), nicht ein eigener Wortlaut.
    static func fusstext(
        fuer zustand: KursZustand, abmeldenBisUhrzeit: String?, wartelistenplatz: Int?
    ) -> String? {
        switch zustand {
        case .abgesagt:
            "Dein Studio hat diesen Termin abgesagt."
        case .vorbei:
            "Dieser Termin ist vorbei."
        case .angemeldet, .frei:
            abmeldenBisUhrzeit.map { "Abmelden ist bis \($0) möglich." }
        case .warteliste:
            wartelistenplatz.map { "Du stehst auf Platz \($0)." }
        case .voll:
            "Alle Plätze sind vergeben."
        }
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
struct KursDetailView: View {
    let sessionId: String

    @Environment(KurseStore.self) private var kurse
    @Environment(CatalogStore.self) private var katalog

    @State private var aktionLaeuft = false
    @State private var fehlermeldung: String?

    var body: some View {
        switch quelle {
        case .online(let ansicht):
            inhalt(ansicht, ohneEmpfang: false)
        case .offline(let ansicht):
            inhalt(ansicht, ohneEmpfang: true)
        case .keineDaten:
            keineDatenInhalt
        }
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

    private var quelle: Quelle {
        if let woche = kurse.woche, let termin = woche.sessions.first(where: { $0.sessionId == sessionId }) {
            return .online(ansicht(aus: termin, in: woche))
        }
        if let eigene = kurse.eigene, let termin = eigene.termine.first(where: { $0.sessionId == sessionId }) {
            return .offline(ansicht(aus: termin, in: eigene))
        }
        return .keineDaten
    }

    private func ansicht(aus termin: CourseWeekSession, in woche: CourseWeek) -> TerminAnsicht {
        TerminAnsicht(
            name: termin.name,
            description: termin.description,
            startsAt: termin.startsAt,
            durationMin: termin.durationMin,
            room: termin.room,
            instructorName: termin.instructorName,
            zustand: KursZustandRechner.zustand(fuer: termin, jetzt: Date()),
            zeitzone: woche.timezone,
            fristStunden: woche.cancellationDeadlineHours,
            belegung: (belegt: termin.bookedCount, kapazitaet: termin.capacity),
            wartelistenplatz: termin.ownWaitlistPosition)
    }

    private func ansicht(aus termin: GespeicherterTermin, in eigene: GespeicherteBuchungen) -> TerminAnsicht {
        TerminAnsicht(
            name: termin.name,
            description: termin.description,
            startsAt: termin.startsAt,
            durationMin: termin.durationMin,
            room: termin.room,
            instructorName: termin.instructorName,
            zustand: KursDetailOfflineZustand.zustand(fuer: termin, jetzt: Date()),
            zeitzone: eigene.timezone,
            fristStunden: eigene.cancellationDeadlineHours,
            belegung: nil,
            wartelistenplatz: nil)
    }

    // MARK: - Inhalt bei vorhandenen Daten

    private func inhalt(_ ansicht: TerminAnsicht, ohneEmpfang: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                if ohneEmpfang {
                    InlineBanner(tone: .muted, message: offlineHinweis, icon: "wifi.slash")
                }
                kopf(ansicht)
                eckdaten(ansicht)
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

    /// "Ohne Empfang" statt "fehlgeschlagen" (Aufgabenbrief, Hinweis 1) --
    /// mit Stand, sonst waere der Cache eine stille Behauptung (dieselbe
    /// Begruendung wie `KurseFileStore`/`GespeicherteBuchungen.stand`).
    private var offlineHinweis: String {
        guard let stand = kurse.eigene?.stand else {
            return "Ohne Empfang. Diese Angaben stammen vom letzten Abruf."
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Ohne Empfang. Stand: \(formatter.string(from: stand))."
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

    private func eckdaten(_ ansicht: TerminAnsicht) -> some View {
        let zeitraum = zeitraumText(ansicht)
        let platz = platzText(ansicht)
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
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
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
    private func platzText(_ ansicht: TerminAnsicht) -> String? {
        guard let belegung = ansicht.belegung else { return nil }
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
        let hauptaktion = KursDetailInhalt.hauptaktion(fuer: ansicht.zustand)
        let fusstext = KursDetailInhalt.fusstext(
            fuer: ansicht.zustand,
            abmeldenBisUhrzeit: abmeldenBisUhrzeit(ansicht),
            wartelistenplatz: ansicht.wartelistenplatz)

        return VStack(spacing: DesignSystem.Spacing.s8) {
            if let fehlermeldung {
                // Servertext woertlich -- nur der Server weiss, ob der
                // Platz gerade vergeben wurde oder die Frist vorbei ist
                // (Aufgabenbrief).
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
    /// tun. Bei jedem anderen Fehler bleibt dieselbe, clientseitig erzeugte
    /// Buchungskennung im Store stehen (`KurseStore.buchungskennungen`);
    /// ein erneuter Tap auf denselben Knopf loest keine zweite Buchung
    /// aus, sondern denselben Wiederholungsversuch.
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
            fehlermeldung = servertext(fuer: error)
        }
        aktionLaeuft = false
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
                        fehlerKarte(servertext(fuer: fehler))
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
            VStack(alignment: .leading, spacing: 2) {
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
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
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

    /// Servertext woertlich, wie `KurseWochenView.servertext(fuer:)` --
    /// dieselbe Formulierung fuer denselben `APIError`-Fall, ob beim
    /// Laden oder nach einem Buchen-/Stornieren-Versuch. `.offline` ist
    /// hier ausdruecklich NICHT "fehlgeschlagen".
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
}
