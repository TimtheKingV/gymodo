import SwiftUI

/// Eine eigene Anmeldung, angereichert um den bereits geparsten Beginn --
/// `KurseMeineEinteilung.bilden` parst `startsAt` ohnehin fuer die
/// Zustands- und Wochenzuordnung; das Ergebnis wird hier mitgegeben, damit
/// der View denselben Zeitpunkt nicht ein zweites Mal aus dem String
/// herstellen muss (und dafuer keinen `Date()`-Verlegenheitsfallback fuer
/// einen strukturell schon ausgeschlossenen Parse-Fehler braucht).
///
/// Nicht `private`: `KurseMeineEinteilungTests` prueft die Zuordnung ohne
/// UI und braucht dafuer Zugriff auf beide Typen, wie
/// `KursDetailInhaltTests` auf `KursDetailInhalt` in KursDetailView.swift.
struct KurseMeineZeile: Identifiable, Equatable {
    let termin: GespeicherterTermin
    let beginn: Date
    var id: String { termin.sessionId }
}

/// Ordnet die gespeicherten eigenen Termine (`KurseStore.eigene.termine`)
/// den drei Abschnitten des Artboards zu -- eine reine Ableitung, getestet
/// in `KurseMeineEinteilungTests`, ohne jede UI-Abhaengigkeit.
///
/// Reihenfolge der Auswertung:
/// 1. Zustand ueber `KursDetailOfflineZustand.zustand(fuer:jetzt:)` --
///    dieselbe schmale Ableitung wie in KursDetailView (Aufgabenbrief
///    Hinweis 3: keine neue Platzhalter-Ableitung fuer denselben Fall).
///    `.abgesagt` und `.vorbei` fallen komplett weg: ein abgesagter oder
///    bereits vergangener Termin ist keine offene eigene Anmeldung mehr,
///    um die sich dieser Screen kuemmert -- Wochenplan und Kursdetail
///    zeigen ihn weiterhin, solange er dort auffindbar ist.
/// 2. Von den verbleibenden (`.angemeldet`/`.warteliste`) landet ein
///    Termin, dessen Kalenderwoche (Montag, Studio-Zeitzone) NICHT die
///    Kalenderwoche von `jetzt` ist, unter "Nächste Woche" -- unabhaengig
///    vom eigenen Status. Das Artboard zeigt dort einen einzelnen,
///    aktionslosen Vorschau-Eintrag ohne Frist- oder Wartelisten-
///    Fusszeile; die Aufteilung nach Woche statt nach Status bildet genau
///    das nach. (Diese Regel steht nicht woertlich im Aufgabenbrief --
///    siehe Bericht.)
/// 3. Innerhalb der aktuellen Kalenderwoche entscheidet der eigene Status:
///    `.angemeldet` -> "Angemeldet", `.warteliste` -> "Auf der
///    Warteliste".
///
/// Ein unlesbarer Beginn (`KursZeitpunkt.parse` liefert `nil`) faellt ganz
/// weg: ohne lesbaren Beginn liesse sich weder der Zustand (vorbei?) noch
/// die Wochenzugehoerigkeit bestimmen, und ein erratener Abschnitt waere
/// schlimmer als ein fehlender Eintrag.
struct KurseMeineEinteilung {
    let angemeldet: [KurseMeineZeile]
    let warteliste: [KurseMeineZeile]
    let naechsteWoche: [KurseMeineZeile]

    var istLeer: Bool { angemeldet.isEmpty && warteliste.isEmpty && naechsteWoche.isEmpty }

    static func bilden(aus termine: [GespeicherterTermin], jetzt: Date, zeitzone: String) -> KurseMeineEinteilung {
        let heutigerMontag = KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone)
        let sortiert = termine.sorted {
            (KursZeitpunkt.parse($0.startsAt) ?? .distantPast)
                < (KursZeitpunkt.parse($1.startsAt) ?? .distantPast)
        }

        var angemeldet: [KurseMeineZeile] = []
        var warteliste: [KurseMeineZeile] = []
        var naechsteWoche: [KurseMeineZeile] = []

        for termin in sortiert {
            let zustand = KursDetailOfflineZustand.zustand(fuer: termin, jetzt: jetzt)
            guard zustand == .angemeldet || zustand == .warteliste else { continue }
            guard let beginn = KursZeitpunkt.parse(termin.startsAt) else { continue }

            let zeile = KurseMeineZeile(termin: termin, beginn: beginn)
            if KurseWochenBerechnung.montag(enthaelt: beginn, zeitzone: zeitzone) != heutigerMontag {
                naechsteWoche.append(zeile)
            } else if zustand == .angemeldet {
                angemeldet.append(zeile)
            } else {
                warteliste.append(zeile)
            }
        }

        return KurseMeineEinteilung(angemeldet: angemeldet, warteliste: warteliste, naechsteWoche: naechsteWoche)
    }
}

/// "Meine Kurse" (`KurseMeine.dc.html`) -- die eigenen Anmeldungen, gelesen
/// AUSSCHLIESSLICH aus `KurseStore.eigene`, nie aus `KurseStore.woche`.
/// Das ist der Kern dieses Screens: `eigene` liegt auf Platte
/// (KurseFileStore) und ist deshalb da, bevor oder ganz ohne dass ein
/// Netzabruf gelingt -- waehrend der Wochenplan (KurseWochenView) ohne
/// Empfang nur eine Offline-Karte zeigt, hat dieser Screen dieselben
/// Zeilen wie sonst auch. Die eigene Anmeldung ist das, was man ohne Netz
/// wissen will.
///
/// `GespeicherterTermin` traegt bewusst keine Belegungszahlen und keine
/// `ownWaitlistPosition` (KurseFileStore-Kommentar) -- deshalb zeigt
/// dieser Screen nirgends eine Platzzahl und nirgends eine
/// Wartelistenposition, online wie offline gleichermassen: eine
/// Belegungszahl von vorhin waere eine Unwahrheit, und eine
/// Wartelistenposition aendert sich ohne Zutun des Mitglieds.
///
/// **Zwei Abweichungen vom Artboard (Spec Abschnitt 6), beide vorgegeben:**
/// 1. Der Wartelisten-Satz ("Rückt jemand ab, ...") steht in `textMuted`,
///    nicht im `textFaint` des Artboards -- er ist die tragende
///    Information des Abschnitts, und SS2 laesst `text-faint` nur fuer
///    nicht-tragenden Text zu.
/// 2. "Abmelden bis 16:00" ist im Artboard hartkodiert; hier kommt die
///    Frist aus `GespeicherteBuchungen.cancellationDeadlineHours`, als
///    Uhrzeit ueber `KursZustandRechner.abmeldenBis`, und wird gegen die
///    laufende Uhr geprueft (naechster Absatz) statt einmalig berechnet.
///
/// **Dritte, nicht im Artboard sichtbare Abweichung -- bitte im Review
/// pruefen:** Das Artboard zeigt bei "Auf der Warteliste" eine Platzzahl
/// ("3" / "PLATZ"). `GespeicherterTermin` traegt `ownWaitlistPosition`
/// bewusst NICHT (KurseFileStore-Kommentar: die Position aendert sich ohne
/// Zutun des Mitglieds und ist ohne frischen Abruf nicht haltbar). Diese
/// Datei zeigt deshalb keine Zahl -- ein Sanduhr-Symbol ersetzt den
/// Zahlenblock, der Wartelisten-Satz bleibt woertlich wie vorgegeben.
///
/// **Die Uhr laeuft mit, waehrend der Screen offen bleibt** (wie
/// KursDetailView, Aufgabe 10 Nachtrag): `body` ist in eine
/// `TimelineView(.periodic(from: .now, by: 60))` gefasst. Zwei
/// Ableitungen haengen an "jetzt": welcher Termin ueberhaupt noch als
/// `.angemeldet`/`.warteliste` gilt (KursDetailOfflineZustand -- ein
/// Termin kann waehrend einer offenen App-Sitzung "vorbei" werden), und ob
/// die Abmeldefrist schon verstrichen ist. Beides wird MIT `context.date`
/// neu berechnet, nicht mit einer beim ersten Aufbau eingefrorenen
/// `Date()`.
///
/// **Kein eigener Zurueck-Weg im leeren Zustand:** Die Signatur dieser
/// Aufgabe (`KurseMeineView { let beiAuswahl: (String) -> Void }`) gibt
/// keinen Ruecksprung-Callback zum Wochenplan her -- derselbe Grund, aus
/// dem KursDetailView keinen eigenen Zurueck-Chevron zeichnet. Der
/// naechste Schritt steht als Text; der Weg dorthin kommt kostenlos aus
/// der Navigation, die Aufgabe 12 um diesen Screen baut.
struct KurseMeineView: View {
    let beiAuswahl: (String) -> Void

    @Environment(KurseStore.self) private var kurse

    /// Die sessionId, deren Abmelden-Versuch gerade laeuft -- verhindert
    /// nur einen zweiten Tap auf DIESELBE Zeile, waehrend deren eigener
    /// Versuch noch unterwegs ist (der Knopf zeigt statt Text einen
    /// ProgressView, also nie ein stummer deaktivierter Zustand). Andere
    /// Zeilen bleiben unabhaengig bedienbar -- KurseStore.stornieren traegt
    /// seine eigene Generation-Absicherung gegen ueberholte Antworten.
    @State private var stornierendId: String?
    /// Servertext je fehlgeschlagenem Abmelden-Versuch, keyed nach
    /// sessionId -- mehrere Zeilen koennen unabhaengig voneinander
    /// scheitern.
    @State private var fehlermeldungen: [String: String] = [:]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            screenInhalt(jetzt: context.date)
        }
    }

    private func screenInhalt(jetzt: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                titel
                if zeigtOfflineHinweis {
                    InlineBanner(tone: .muted, message: offlineHinweis, icon: "wifi.slash")
                }
                inhalt(jetzt: jetzt)
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
    }

    private var titel: some View {
        Text("MEINE KURSE")
            .font(DesignSystem.Typography.screentitel)
            .tracking(-0.8)
            .foregroundStyle(DesignSystem.Color.text)
    }

    // MARK: - Ohne Empfang: derselbe Inhalt, plus Stand

    /// `KurseMeineView` laedt selbst nichts nach -- `kurse.ladeZustand`
    /// spiegelt den letzten Ladeversuch, ausgeloest vom Wochenplan. Ein
    /// `.offline`-Fehlschlag dort heisst: was unten steht, ist der
    /// gespeicherte Stand, kein frischer Abruf. Ein Serverfehler
    /// (`.fehlgeschlagen` mit anderem Fall) betrifft diesen Screen nicht
    /// gesondert -- der zeigt ohnehin immer den Cache, online wie offline,
    /// und der Wochenplan meldet den Serverfehler bereits an seiner
    /// eigenen Stelle.
    private var zeigtOfflineHinweis: Bool {
        if case .fehlgeschlagen(let fehler) = kurse.ladeZustand, fehler == .offline { return true }
        return false
    }

    /// "Ohne Empfang" statt "fehlgeschlagen" (designsystem.md SS5) -- mit
    /// Stand, sonst waere der Cache eine stille Behauptung (dieselbe
    /// Begruendung wie KursDetailView.offlineHinweis).
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

    // MARK: - Inhalt: leer oder die drei Abschnitte

    @ViewBuilder
    private func inhalt(jetzt: Date) -> some View {
        if let eigene = kurse.eigene, !eigene.termine.isEmpty {
            let einteilung = KurseMeineEinteilung.bilden(
                aus: eigene.termine, jetzt: jetzt, zeitzone: eigene.timezone)
            if einteilung.istLeer {
                // Alle vorhandenen Datensaetze sind .abgesagt/.vorbei --
                // fachlich hat das Mitglied dann ebenfalls keine offene
                // Anmeldung mehr, auch wenn KurseFileStore noch Zeilen
                // haelt.
                leerZustand
            } else {
                abschnitte(einteilung, eigene: eigene, jetzt: jetzt)
            }
        } else {
            leerZustand
        }
    }

    private func abschnitte(_ einteilung: KurseMeineEinteilung, eigene: GespeicherteBuchungen, jetzt: Date) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            if !einteilung.angemeldet.isEmpty {
                abschnitt("Angemeldet") {
                    ForEach(einteilung.angemeldet) { zeile in
                        angemeldetKarte(zeile, eigene: eigene, jetzt: jetzt)
                    }
                }
            }
            if !einteilung.warteliste.isEmpty {
                abschnitt("Auf der Warteliste") {
                    ForEach(einteilung.warteliste) { zeile in
                        wartelisteKarte(zeile, zeitzone: eigene.timezone)
                    }
                }
            }
            if !einteilung.naechsteWoche.isEmpty {
                abschnitt("Nächste Woche") {
                    ForEach(einteilung.naechsteWoche) { zeile in
                        naechsteWocheKarte(zeile, zeitzone: eigene.timezone)
                    }
                }
            }
        }
    }

    private func abschnitt<Content: View>(_ titel: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(titel.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            VStack(spacing: DesignSystem.Spacing.s12) {
                content()
            }
        }
    }

    /// Ueberschrift plus naechster Schritt, keine leere Statistik
    /// (dieselbe Form wie KurseWochenView.leerZustand).
    private var leerZustand: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text("Du bist für keinen Kurs angemeldet.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            Text("Geh zurück zum Wochenplan, um dich für einen Kurs anzumelden.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Datumsblock (Wochentag kurz + Tag), gemeinsam fuer alle drei Karten

    private func datumsblock(kuerzel: String, tag: Int, farbe: Color) -> some View {
        VStack(spacing: 1) {
            Text(kuerzel)
                .font(DesignSystem.Typography.label)
                .foregroundStyle(farbe)
            Text("\(tag)")
                .font(.system(size: 19, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
        }
        .frame(width: 46)
        .padding(.vertical, 7)
        .background(DesignSystem.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    /// Wochentagskuerzel + Tagesnummer eines einzelnen Zeitpunkts in der
    /// Studio-Zeitzone -- anders als KurseWochenBerechnung.wochentage (das
    /// eine ganze Woche durchlaeuft) reicht hier ein einzelner Zeitpunkt,
    /// der schon als `Date` vorliegt (KurseMeineZeile.beginn).
    private func datumsblockWerte(_ zeitpunkt: Date, zeitzone: String) -> (kuerzel: String, tag: Int) {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = kalender.timeZone
        // "ccc" (stand-alone), nicht "EEE" -- wie KursZeit.datumAusgeschrieben
        // und KurseWochenBerechnung: liefert "Do" ohne Punkt.
        formatter.dateFormat = "ccc"
        return (formatter.string(from: zeitpunkt).uppercased(), kalender.component(.day, from: zeitpunkt))
    }

    private func zeitraumUndRaum(_ termin: GespeicherterTermin, beginn: Date, zeitzone: String) -> String {
        let ende = beginn.addingTimeInterval(Double(termin.durationMin) * 60)
        let zeitraum = "\(KursZeit.uhrzeit(beginn, zeitzone: zeitzone)) – \(KursZeit.uhrzeit(ende, zeitzone: zeitzone))"
        guard let room = termin.room else { return zeitraum }
        return "\(zeitraum) · \(room)"
    }

    // MARK: - "Angemeldet" -- die eine Akzentflaeche des Screens

    /// Randfarbe UND die Haken-Plakette tragen beide `accent` -- zusammen
    /// EINE Akzentflaeche (dieselbe Zaehlweise wie beim gewaehlten Tag in
    /// KurseWochenView: Hintergrund und Vordergrund eines einzigen
    /// markierten Elements zaehlen als eins, nicht als zwei). Das
    /// Artboard haelt die Ein-Akzent-Regel fuer diesen Screen bereits ein
    /// (Aufgabenbrief) -- diese Karte ist die einzige Stelle im Screen,
    /// die `accent` verwendet.
    private func angemeldetKarte(_ zeile: KurseMeineZeile, eigene: GespeicherteBuchungen, jetzt: Date) -> some View {
        let block = datumsblockWerte(zeile.beginn, zeitzone: eigene.timezone)
        let verstrichen = KursDetailInhalt.abmeldefristVerstrichen(
            startsAt: zeile.termin.startsAt, fristStunden: eigene.cancellationDeadlineHours, jetzt: jetzt)
        let uhrzeit = abmeldenBisUhrzeit(zeile.termin, fristStunden: eigene.cancellationDeadlineHours, zeitzone: eigene.timezone)
        let fusstext = KursDetailInhalt.fusstext(
            fuer: .angemeldet, abmeldenBisUhrzeit: uhrzeit, abmeldefristVerstrichen: verstrichen, wartelistenplatz: nil)

        return VStack(spacing: 0) {
            Button {
                beiAuswahl(zeile.termin.sessionId)
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
                    datumsblock(kuerzel: block.kuerzel, tag: block.tag, farbe: DesignSystem.Color.accent)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text(zeile.termin.name)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(zeitraumUndRaum(zeile.termin, beginn: zeile.beginn, zeitzone: eigene.timezone))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        if let trainer = zeile.termin.instructorName {
                            Text(trainer)
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Color.textFaint)
                        }
                    }
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().fill(DesignSystem.Color.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(DesignSystem.Color.onAccent)
                    }
                    .frame(width: 26, height: 26)
                }
                .padding(DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Öffnet die Kursdetails")

            Rectangle().fill(DesignSystem.Color.line).frame(height: 1)

            HStack(spacing: DesignSystem.Spacing.s8) {
                if let fusstext {
                    Text(fusstext)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                Spacer(minLength: 0)
                if !verstrichen {
                    abmeldenKnopf(zeile.termin.sessionId)
                }
            }
            .padding(DesignSystem.Spacing.s12)

            if let fehler = fehlermeldungen[zeile.termin.sessionId] {
                InlineBanner(tone: .danger, message: fehler)
                    .padding(.horizontal, DesignSystem.Spacing.s12)
                    .padding(.bottom, DesignSystem.Spacing.s12)
            }
        }
        .background(DesignSystem.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.accent, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    /// `KursZustandRechner.abmeldenBis` mit der Frist DIESES Studios
    /// (`cancellationDeadlineHours`), nicht der hartkodierten 16:00 aus
    /// dem Artboard -- formatiert in der Studio-Zeitzone. `nil` bei
    /// unlesbarem Beginn: eine erfundene Uhrzeit waere schlimmer als
    /// keine.
    private func abmeldenBisUhrzeit(_ termin: GespeicherterTermin, fristStunden: Int, zeitzone: String) -> String? {
        guard let deadline = KursZustandRechner.abmeldenBis(startsAt: termin.startsAt, fristStunden: fristStunden)
        else { return nil }
        return KursZeit.uhrzeit(deadline, zeitzone: zeitzone)
    }

    /// "Abmelden" als Nebenaktion (Aufgabenbrief) -- ruft
    /// `KurseStore.stornieren` direkt aus der Zeile heraus auf, ohne den
    /// Umweg ueber KursDetailView. Zeigt waehrend des eigenen Versuchs
    /// einen ProgressView statt Text (nie ein stummer deaktivierter
    /// Zustand).
    private func abmeldenKnopf(_ sessionId: String) -> some View {
        Button {
            Task { await abmelden(sessionId: sessionId) }
        } label: {
            Group {
                if stornierendId == sessionId {
                    ProgressView().tint(DesignSystem.Color.danger)
                } else {
                    Text("Abmelden")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.danger)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressButtonStyle())
        .disabled(stornierendId == sessionId)
    }

    /// Verhindert nur einen zweiten Tap auf DIESELBE Zeile, waehrend ihr
    /// eigener Versuch laeuft -- siehe stornierendId-Kommentar oben.
    private func abmelden(sessionId: String) async {
        guard stornierendId != sessionId else { return }
        stornierendId = sessionId
        fehlermeldungen[sessionId] = nil
        do {
            try await kurse.stornieren(sessionId: sessionId)
        } catch {
            // Servertext woertlich -- nur der Server weiss, ob der Platz
            // schon anderweitig vergeben wurde oder die Frist gerade eben
            // verstrichen ist (Aufgabenbrief Task 10, sinngemaess auch
            // hier).
            fehlermeldungen[sessionId] = servertext(fuer: error)
        }
        stornierendId = nil
    }

    // MARK: - "Auf der Warteliste"

    /// Randfarbe `warn`, ausschliesslich als Kontur (33 % Deckkraft, wie im
    /// Artboard) -- nie als Flaeche (designsystem.md SS2). Ersetzt die im
    /// Artboard gezeigte Wartelistenposition durch ein Sanduhr-Symbol:
    /// `GespeicherterTermin` traegt `ownWaitlistPosition` bewusst nicht
    /// (KurseFileStore-Kommentar), eine erfundene Zahl waere hier
    /// dieselbe Unwahrheit wie eine veraltete Belegungszahl.
    private func wartelisteKarte(_ zeile: KurseMeineZeile, zeitzone: String) -> some View {
        let block = datumsblockWerte(zeile.beginn, zeitzone: zeitzone)

        return VStack(spacing: 0) {
            Button {
                beiAuswahl(zeile.termin.sessionId)
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
                    datumsblock(kuerzel: block.kuerzel, tag: block.tag, farbe: DesignSystem.Color.warn)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text(zeile.termin.name)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(zeitraumUndRaum(zeile.termin, beginn: zeile.beginn, zeitzone: zeitzone))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        if let trainer = zeile.termin.instructorName {
                            Text(trainer)
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Color.textFaint)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "hourglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.warn)
                }
                .padding(DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Öffnet die Kursdetails")

            Rectangle().fill(DesignSystem.Color.line).frame(height: 1)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.s8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                // Woertlicher Satz aus dem Aufgabenbrief, in `textMuted`
                // statt `textFaint` -- er ist die tragende Information
                // dieses Abschnitts (SS2 laesst text-faint nur fuer
                // nicht-tragenden Text zu). Verspricht bewusst KEINE
                // Benachrichtigung: es gibt keine. Das Nachruecken
                // passiert serverseitig still und unter Zeilensperre; das
                // Mitglied erfaehrt es beim naechsten Oeffnen, genau wie
                // dieser Satz es sagt. Kein Wort daran aendern.
                Text("Rückt jemand ab, bekommst du den Platz automatisch. Du siehst es hier unter Meine Kurse. Bis dahin ist nichts reserviert.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
            }
            .padding(DesignSystem.Spacing.s12)
        }
        .background(DesignSystem.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.warn.opacity(0.33), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    // MARK: - "Nächste Woche" -- reiner Vorschau-Eintrag, keine Aktion

    private func naechsteWocheKarte(_ zeile: KurseMeineZeile, zeitzone: String) -> some View {
        let block = datumsblockWerte(zeile.beginn, zeitzone: zeitzone)

        return Button {
            beiAuswahl(zeile.termin.sessionId)
        } label: {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.s12) {
                datumsblock(kuerzel: block.kuerzel, tag: block.tag, farbe: DesignSystem.Color.textFaint)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(zeile.termin.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(zeitraumUndRaum(zeile.termin, beginn: zeile.beginn, zeitzone: zeitzone))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    if let trainer = zeile.termin.instructorName {
                        Text(trainer)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(minHeight: 44)
        }
        .buttonStyle(PressButtonStyle())
        .background(DesignSystem.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Kursdetails")
    }

    // MARK: - Servertext

    /// Wie KurseWochenView.servertext(fuer:)/KursDetailView.servertext(fuer:)
    /// -- dieselbe Formulierung fuer denselben APIError-Fall, hier fuer
    /// einen fehlgeschlagenen Abmelden-Versuch aus der Zeile heraus.
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
