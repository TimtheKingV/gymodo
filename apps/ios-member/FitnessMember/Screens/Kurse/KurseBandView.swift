import SwiftUI

/// Das Band „Deine Kurse“ am Kopf des Kurse-Screens -- der frühere Screen
/// „Meine Kurse“, an die Stelle gerueckt, an der man ihn braucht.
///
/// Der Grund fuer die Zusammenlegung ist einfach: die eigenen Anmeldungen
/// waren hinter einem Textknopf oben rechts versteckt, und ein Wochenplan,
/// der nicht zeigt, wo man selbst eingetragen ist, beantwortet die
/// haeufigste Frage nicht. Jetzt steht sie oben, bevor der Plan beginnt.
///
/// Drei Abschnitte gibt es hier nicht mehr (`alleZeilen` statt
/// angemeldet/warteliste/spaeter): der Zustand steht auf der Karte selbst
/// -- Kontur, Marke, Abmeldehinweis -- und muss nicht noch einmal als
/// Ueberschrift darueber. Der naechste Kurs steht oben.
///
/// Das Band traegt als einzige Stelle den Abmelden-Knopf. Die Zeile im
/// Tagesplan darunter markiert dieselbe Anmeldung nur (Kontur und Haken);
/// stuende der rote Knopf zweimal auf einem Screen, waere nicht mehr
/// erkennbar, dass es dieselbe Handlung ist -- und die Zeile im Plan waere
/// um ihre Fusszeile hoeher als jede andere.
struct KurseBandView: View {
    let beiAuswahl: (String) -> Void
    /// Aus dem 60-Sekunden-Tick des Screens, nicht aus einem frischen
    /// `Date()`: sonst blieben Abmeldefrist und Zustand stehen, bis
    /// irgendein unabhaengiger Grund neu zeichnet.
    let jetzt: Date

    @Environment(KurseStore.self) private var kurse

    /// Eine MENGE laufender Abmeldungen, kein einzelner Wert: sonst
    /// erschiene die erste Zeile wieder als "bereit", sobald eine zweite
    /// startet, und liesse sich ein zweites Mal antippen (Review-Fund M2
    /// aus „Meine Kurse“ -- er gilt hier unveraendert weiter).
    @State private var stornierendeIds: Set<String> = []
    @State private var fehlermeldungen: [String: String] = [:]

    var body: some View {
        if let eigene = kurse.eigene {
            let einteilung = KurseMeineEinteilung.bilden(
                aus: eigene.termine, jetzt: jetzt, zeitzone: eigene.timezone)
            if !einteilung.istLeer {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                    Text("DEINE KURSE")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    ForEach(einteilung.alleZeilen) { zeile in
                        karte(zeile, eigene: eigene)
                    }
                }
            }
        }
    }

    // MARK: - Eine Karte je Anmeldung

    /// EINE Karte fuer beide Zustaende, nicht zwei fast gleiche.
    /// Bestaetigter Platz und Warteliste unterscheiden sich in genau drei
    /// Werten -- Kontur, Marke rechts, Hinweistext -, und die kommen alle
    /// aus getesteten Ableitungen.
    private func karte(_ zeile: KurseMeineZeile, eigene: GespeicherteBuchungen) -> some View {
        let zustand = KursDetailOfflineZustand.zustand(fuer: zeile.termin, jetzt: jetzt)
        let verstrichen = KursDetailInhalt.abmeldefristVerstrichen(
            startsAt: zeile.termin.startsAt,
            fristStunden: eigene.cancellationDeadlineHours, jetzt: jetzt)
        let hinweis = KurseWochenInhalt.abmeldehinweis(
            fuer: zustand,
            abmeldenBisUhrzeit: abmeldenBisUhrzeit(
                zeile.termin, fristStunden: eigene.cancellationDeadlineHours,
                zeitzone: eigene.timezone),
            abmeldefristVerstrichen: verstrichen)
        let zeigtKnopf = KurseWochenInhalt.zeigtAbmeldenKnopf(
            fuer: zustand, abmeldefristVerstrichen: verstrichen)
        let farbe = zustand == .warteliste ? DesignSystem.Color.warn : DesignSystem.Color.accent

        return VStack(spacing: 0) {
            Button {
                beiAuswahl(zeile.termin.sessionId)
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
                    datumsblock(zeile, zeitzone: eigene.timezone, farbe: farbe)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text(zeile.termin.name)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(zeitraumUndRaum(zeile, zeitzone: eigene.timezone))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        if let trainer = zeile.termin.instructorName {
                            Text(trainer)
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Color.textMuted)
                        }
                    }
                    Spacer(minLength: 0)
                    marke(zustand)
                }
                .padding(DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Öffnet die Kursdetails")

            if hinweis != nil || zeigtKnopf {
                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                HStack(spacing: DesignSystem.Spacing.s8) {
                    if let hinweis {
                        Text(hinweis)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                    Spacer(minLength: 0)
                    if zeigtKnopf {
                        abmeldenKnopf(zeile.termin.sessionId)
                    }
                }
                .padding(DesignSystem.Spacing.s12)
            }

            if zustand == .warteliste {
                wartelistenErklaerung
            }

            // Der Fehler haengt an DIESER sessionId -- eine Karte zeigt nur
            // ihren eigenen Fehler, nie den einer anderen. Und nur solange
            // der Knopf da ist: sonst stuende ein Fehler ohne jeden Weg,
            // ihn wieder loszuwerden.
            if zeigtKnopf, case .fehlgeschlagen(let fehler) = abmeldeZustand(zeile.termin.sessionId) {
                InlineBanner(tone: .danger, message: fehler)
                    .padding(.horizontal, DesignSystem.Spacing.s12)
                    .padding(.bottom, DesignSystem.Spacing.s12)
            }
        }
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(
                    zustand == .warteliste ? DesignSystem.Color.warn.opacity(0.33) : DesignSystem.Color.accent,
                    lineWidth: zustand == .warteliste ? 1 : 1.5))
    }

    /// Was eine Warteliste eigentlich bedeutet -- der Satz stand frueher
    /// auf der Wartelistenkarte in „Meine Kurse“ und waere mit dem Screen
    /// verschwunden. Er verspricht bewusst KEINE Benachrichtigung: es gibt
    /// keine. Das Nachruecken passiert serverseitig still und unter
    /// Zeilensperre; das Mitglied erfaehrt es beim naechsten Oeffnen, genau
    /// wie der Satz es sagt.
    ///
    /// Woertlich uebernommen bis auf zwei Woerter: „unter Meine Kurse“ ist
    /// „unter Deine Kurse“ geworden, weil der Satz sonst auf einen Screen
    /// zeigte, den es nicht mehr gibt.
    private var wartelistenErklaerung: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
            // textMuted statt textFaint: der Satz ist die tragende
            // Information dieser Karte (designsystem.md SS2 laesst
            // textFaint nur fuer nicht tragenden Text zu).
            Text("Rückt jemand ab, bekommst du den Platz automatisch. Du siehst es hier unter Deine Kurse. Bis dahin ist nichts reserviert.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineSpacing(3)
        }
        .padding(.horizontal, DesignSystem.Spacing.s12)
        .padding(.bottom, DesignSystem.Spacing.s12)
    }

    /// Die Marke rechts oben. Sie traegt den Zustand als FORM, nicht nur
    /// als Farbe -- Haken gegen Sanduhr -, und ihr `accessibilityLabel`
    /// bringt das Wort in die kombinierte Vorlesung der Karte.
    ///
    /// Keine Wartelistenposition: `GespeicherterTermin` traegt sie
    /// bewusst nicht (KurseFileStore). Sie aendert sich ohne Zutun des
    /// Mitglieds, und eine Zahl von vorhin koennte jemanden dazu bringen,
    /// eine Warteliste zu verlassen, auf der er laengst nachgerueckt ist.
    @ViewBuilder
    private func marke(_ zustand: KursZustand) -> some View {
        if zustand == .warteliste {
            Image(systemName: "hourglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.warn)
                .accessibilityLabel("Auf der Warteliste")
        } else {
            ZStack {
                Circle().fill(DesignSystem.Color.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DesignSystem.Color.onAccent)
            }
            .frame(width: 26, height: 26)
            .accessibilityLabel("Angemeldet")
        }
    }

    private func datumsblock(_ zeile: KurseMeineZeile, zeitzone: String, farbe: Color) -> some View {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = kalender.timeZone
        // "ccc" (stand-alone), nicht "EEE" -- liefert "Do" ohne Punkt.
        formatter.dateFormat = "ccc"

        return VStack(spacing: DesignSystem.Spacing.s4) {
            Text(formatter.string(from: zeile.beginn).uppercased())
                .font(DesignSystem.Typography.label)
                .foregroundStyle(farbe)
            Text("\(kalender.component(.day, from: zeile.beginn))")
                .font(.system(size: 19, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
        }
        .frame(width: 46)
        .padding(.vertical, DesignSystem.Spacing.s8)
        .background(DesignSystem.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func zeitraumUndRaum(_ zeile: KurseMeineZeile, zeitzone: String) -> String {
        let ende = zeile.beginn.addingTimeInterval(Double(zeile.termin.durationMin) * 60)
        let zeitraum = "\(KursZeit.uhrzeit(zeile.beginn, zeitzone: zeitzone)) – \(KursZeit.uhrzeit(ende, zeitzone: zeitzone))"
        guard let room = zeile.termin.room else { return zeitraum }
        return "\(zeitraum) · \(room)"
    }

    /// Die Frist DIESES Studios (`cancellationDeadlineHours`), formatiert
    /// in der Studio-Zeitzone. `nil` bei unlesbarem Beginn: eine erfundene
    /// Uhrzeit waere schlimmer als keine.
    private func abmeldenBisUhrzeit(
        _ termin: GespeicherterTermin, fristStunden: Int, zeitzone: String
    ) -> String? {
        guard let deadline = KursZustandRechner.abmeldenBis(
            startsAt: termin.startsAt, fristStunden: fristStunden) else { return nil }
        return KursZeit.uhrzeit(deadline, zeitzone: zeitzone)
    }

    // MARK: - Abmelden

    private func abmeldeZustand(_ sessionId: String) -> KurseMeineAbmeldeZustand {
        KurseMeineAbmeldeZustand.fuer(
            sessionId: sessionId, laufende: stornierendeIds, fehlermeldungen: fehlermeldungen)
    }

    /// Zeigt waehrend des eigenen Versuchs einen ProgressView statt Text --
    /// nie ein stummer deaktivierter Zustand -, und nur DIESE Karte ist
    /// gesperrt, jede andere bleibt unabhaengig bedienbar.
    private func abmeldenKnopf(_ sessionId: String) -> some View {
        let laeuft = abmeldeZustand(sessionId) == .laeuft
        return Button {
            Task { await abmelden(sessionId: sessionId) }
        } label: {
            Group {
                if laeuft {
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
        .disabled(laeuft)
        .accessibilityLabel(laeuft ? "Abmelden, wird bearbeitet" : "Abmelden")
    }

    private func abmelden(sessionId: String) async {
        guard !stornierendeIds.contains(sessionId) else { return }
        stornierendeIds.insert(sessionId)
        fehlermeldungen[sessionId] = nil
        do {
            try await kurse.stornieren(sessionId: sessionId)
        } catch {
            fehlermeldungen[sessionId] = abmeldeFehler(error)
        }
        stornierendeIds.remove(sessionId)
    }

    /// Servertext woertlich -- nur der Server weiss, ob der Platz schon
    /// anderweitig vergeben wurde oder die Frist gerade eben verstrichen
    /// ist. Ausnahme `.offline`: eine Abmeldung, die nie losgeflogen ist,
    /// darf nicht als Fehlschlag durchgehen, sonst glaubt das Mitglied, es
    /// sei abgemeldet.
    private func abmeldeFehler(_ fehler: APIError) -> String {
        fehler == .offline
            ? "Kein Empfang. Ob deine Abmeldung angekommen ist, wissen wir gerade nicht — dein Platz kann noch besetzt sein. Versuch es noch einmal, sobald du Empfang hast."
            : fehler.servertext
    }
}
