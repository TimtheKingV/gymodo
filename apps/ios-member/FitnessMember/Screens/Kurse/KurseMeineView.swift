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
///    Kalenderwoche von `jetzt` ist, unter "Später" -- unabhaengig
///    vom eigenen Status. Das Artboard zeigt dort einen einzelnen,
///    aktionslosen Vorschau-Eintrag ohne Frist- oder Wartelisten-
///    Fusszeile; die Aufteilung nach Woche statt nach Status bildet genau
///    das nach. (Diese Regel steht nicht woertlich im Aufgabenbrief --
///    siehe Bericht.) Der Abschnitt hiess bis zur Schlusswelle "Nächste
///    Woche"; seit das Ladefenster bis "jetzt plus 14 Tage" reicht, kann
///    er auch Termine der uebernaechsten Woche enthalten.
/// 3. Innerhalb der aktuellen Kalenderwoche entscheidet der eigene Status:
///    `.angemeldet` -> "Angemeldet", `.warteliste` -> "Auf der
///    Warteliste".
///
/// Ein unlesbarer Beginn (`Zeitpunkt.parse` liefert `nil`) faellt ganz
/// weg: ohne lesbaren Beginn liesse sich weder der Zustand (vorbei?) noch
/// die Wochenzugehoerigkeit bestimmen, und ein erratener Abschnitt waere
/// schlimmer als ein fehlender Eintrag.
struct KurseMeineEinteilung {
    let angemeldet: [KurseMeineZeile]
    let warteliste: [KurseMeineZeile]
    let spaeter: [KurseMeineZeile]

    var istLeer: Bool { angemeldet.isEmpty && warteliste.isEmpty && spaeter.isEmpty }

    static func bilden(aus termine: [GespeicherterTermin], jetzt: Date, zeitzone: String) -> KurseMeineEinteilung {
        let heutigerMontag = KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone)
        let sortiert = termine.sorted {
            (Zeitpunkt.parse($0.startsAt) ?? .distantPast)
                < (Zeitpunkt.parse($1.startsAt) ?? .distantPast)
        }

        var angemeldet: [KurseMeineZeile] = []
        var warteliste: [KurseMeineZeile] = []
        var spaeter: [KurseMeineZeile] = []

        for termin in sortiert {
            let zustand = KursDetailOfflineZustand.zustand(fuer: termin, jetzt: jetzt)
            guard zustand == .angemeldet || zustand == .warteliste else { continue }
            guard let beginn = Zeitpunkt.parse(termin.startsAt) else { continue }

            let zeile = KurseMeineZeile(termin: termin, beginn: beginn)
            if KurseWochenBerechnung.montag(enthaelt: beginn, zeitzone: zeitzone) != heutigerMontag {
                spaeter.append(zeile)
            } else if zustand == .angemeldet {
                angemeldet.append(zeile)
            } else {
                warteliste.append(zeile)
            }
        }

        return KurseMeineEinteilung(angemeldet: angemeldet, warteliste: warteliste, spaeter: spaeter)
    }
}

/// Der Zustand des "Abmelden"-Knopfs EINER Zeile -- eine reine Ableitung
/// aus der Menge gerade laufender Abmeldeversuche und den Fehlermeldungen
/// je sessionId, getestet in `KurseMeineAbmeldeZustandTests` ohne UI.
///
/// Review-Fund M2: ein einzelner `stornierendId`-Wert kann immer nur EINE
/// Zeile als "laeuft" fuehren. Beginnt eine zweite Zeile ihre Abmeldung,
/// waehrend die erste noch unterwegs ist, wuerde die erste wieder als
/// "bereit" erscheinen -- obwohl ihre Anfrage noch offen ist -- und liesse
/// sich ein zweites Mal antippen, mit einer zweiten, nebenlaeufigen
/// Anfrage fuer denselben Termin. Diese Ableitung nimmt stattdessen eine
/// `Set<String>` laufender sessionIds entgegen: jede Zeile fragt nur nach
/// ihrer EIGENEN sessionId und bleibt unabhaengig von jeder anderen
/// gesperrt, waehrend ihr eigener Versuch laeuft.
enum KurseMeineAbmeldeZustand: Equatable {
    case bereit
    case laeuft
    case fehlgeschlagen(String)

    static func fuer(sessionId: String, laufende: Set<String>, fehlermeldungen: [String: String]) -> KurseMeineAbmeldeZustand {
        if laufende.contains(sessionId) { return .laeuft }
        if let fehler = fehlermeldungen[sessionId] { return .fehlgeschlagen(fehler) }
        return .bereit
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
///
/// **Review-Fund M1: "noch nie geladen" ist nicht "keine Anmeldungen".**
/// Ohne Cache (`kurse.eigene == nil`) UND ohne einen Ladeversuch, der das
/// tatsaechlich bestaetigt hat, weiss dieser Screen schlicht nichts --
/// gerade eine Erstinstallation ohne Netz waere sonst der Fall, in dem er
/// faelschlich "Du bist für keinen Kurs angemeldet." behauptet, obwohl nie
/// ein Abruf gelungen ist. `kurse.ladeZustand` unterscheidet die Faelle:
/// `.geladen` bestaetigt eine echte Leere (KurseStore.laden setzt `eigene`
/// bei einem erfolgreichen Abruf ohne eigene Termine ausdruecklich auf
/// `nil`, nie stumm); `.bereit`/`.laedt` heisst "noch unterwegs, noch
/// nichts bekannt"; `.fehlgeschlagen(.offline)` heisst "kein Empfang,
/// nichts bekannt" -- ausdruecklich NICHT "fehlgeschlagen" formuliert
/// (designsystem.md SS5); jeder andere `.fehlgeschlagen`-Fall zeigt den
/// Servertext. Siehe `ungeladenerZustand` unten.
struct KurseMeineView: View {
    let beiAuswahl: (String) -> Void

    @Environment(KurseStore.self) private var kurse

    /// Die sessionIds, deren Abmelden-Versuch gerade laeuft -- eine Menge,
    /// nicht ein einzelner Wert (Review-Fund M2): mehrere Zeilen koennen
    /// gleichzeitig unterwegs sein, jede bleibt nur fuer ihre EIGENE
    /// sessionId gesperrt (der Knopf zeigt waehrenddessen statt Text einen
    /// ProgressView, also nie ein stummer deaktivierter Zustand). Andere
    /// Zeilen bleiben unabhaengig bedienbar -- KurseStore.stornieren traegt
    /// seine eigene Generation-Absicherung gegen ueberholte Antworten.
    @State private var stornierendeIds: Set<String> = []
    /// Servertext je fehlgeschlagenem Abmelden-Versuch, keyed nach
    /// sessionId -- mehrere Zeilen koennen unabhaengig voneinander
    /// scheitern, und der Fehler bleibt an der Zeile sichtbar, zu der er
    /// gehoert.
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
                let herkunft = herkunft(jetzt: jetzt)
                if kurse.eigene != nil,
                   let hinweis = herkunft.satz(stand: kurse.eigene?.stand) {
                    InlineBanner(tone: .muted, message: hinweis, icon: herkunft.symbol)
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
    /// spiegelt den letzten Ladeversuch, ausgeloest vom Wochenplan.
    ///
    /// Dieselbe Ableitung wie in den beiden anderen Kurse-Screens (siehe
    /// KurseHerkunft). Vorher stand der Hinweis hier ausschliesslich bei
    /// `.offline`; ein Serverfehler ergab gar keinen, und die Karten aus
    /// dem Cache standen OHNE jede Altersangabe da, als waeren sie frisch.
    /// Begruendet war das mit "der Wochenplan meldet den Serverfehler
    /// bereits an seiner eigenen Stelle" -- das Mitglied ist in diesem
    /// Moment aber nicht auf dem Wochenplan.
    ///
    /// Der "Plaetze weg"-Zusatz entfaellt hier: dieser Screen zeigt
    /// ohnehin nirgends eine Belegungszahl (GespeicherterTermin traegt
    /// keine), es faellt also nichts weg, was zu erklaeren waere.
    private func herkunft(jetzt: Date) -> KurseHerkunft {
        KurseHerkunft.bilden(
            ladeZustand: kurse.ladeZustand, wocheStand: kurse.wocheStand, jetzt: jetzt)
    }

    // MARK: - Inhalt: bestaetigt leer, ungeladen, oder die drei Abschnitte

    @ViewBuilder
    private func inhalt(jetzt: Date) -> some View {
        if let eigene = kurse.eigene, !eigene.termine.isEmpty {
            let einteilung = KurseMeineEinteilung.bilden(
                aus: eigene.termine, jetzt: jetzt, zeitzone: eigene.timezone)
            if einteilung.istLeer {
                // Alle vorhandenen Datensaetze sind .abgesagt/.vorbei --
                // ein echter Cache hat das bestaetigt, fachlich hat das
                // Mitglied dann ebenfalls keine offene Anmeldung mehr.
                bestaetigtLeererZustand
            } else {
                abschnitte(einteilung, eigene: eigene, jetzt: jetzt)
            }
        } else {
            // Kein Cache -- ob "keine Anmeldungen" gilt, ist damit noch
            // NICHT entschieden (Review-Fund M1). Siehe dort.
            ungeladenerZustand
        }
    }

    /// Ein Ladeversuch hat tatsaechlich bestaetigt: keine eigenen
    /// Anmeldungen. Ueberschrift plus naechster Schritt, keine leere
    /// Statistik (dieselbe Form wie KurseWochenView.leerZustand).
    private var bestaetigtLeererZustand: some View {
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

    /// Kein Cache, und kein Ladeversuch hat bislang irgendetwas bestaetigt
    /// -- Review-Fund M1. `kurse.ladeZustand` traegt genug, um ehrlich zu
    /// sagen, was gilt: `.geladen` bestaetigt eine echte Leere (siehe
    /// unten), `.bereit`/`.laedt` heisst "noch unterwegs", und
    /// `.fehlgeschlagen` unterscheidet Empfangslosigkeit von einem
    /// tatsaechlichen Serverfehler.
    @ViewBuilder
    private var ungeladenerZustand: some View {
        switch kurse.ladeZustand {
        case .geladen:
            // Ein erfolgreicher Abruf OHNE eigene Termine setzt
            // `kurse.eigene` ausdruecklich auf `nil` (KurseStore.laden) --
            // das ist eine bestaetigte Leere, keine offene Frage.
            bestaetigtLeererZustand
        case .fehlgeschlagen(let fehler) where fehler == .offline:
            ohneEmpfangUnbekannterZustand
        case .fehlgeschlagen(let fehler):
            fehlerUnbekannterZustand(fehler)
        case .bereit:
            nochNichtGeladenerZustand
        case .laedt:
            ladeSkelett
        }
    }

    /// Kein Cache, ohne Empfang -- der Screen weiss nichts, und das sagt
    /// er auch so: nicht "fehlgeschlagen" (designsystem.md SS5), sondern
    /// "kein Empfang" plus der naechste Schritt. Dieselbe Kartenform wie
    /// KurseWochenView.offlineKarte/KursDetailView.offlineKarte -- Halt es
    /// genauso.
    private var ohneEmpfangUnbekannterZustand: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text("Kein Empfang")
                    .font(.system(size: 15, weight: .semibold))
                Text("Deine Anmeldungen sind noch nicht bekannt. Verbinde dich mit dem Internet und öffne den Wochenplan, damit sie geladen werden.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(DesignSystem.Color.danger)
        .padding(DesignSystem.Spacing.s12)
        .background(DesignSystem.Color.danger.opacity(0.1))
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der 1pt-Kontur weg. Vorlage ist InlineBanner,
        // das es als einziges schon richtig hatte -- hier und in
        // KurseWochenView/KursDetailView/ProblemSheet/TrainingRootView/
        // TrainingAbschlussView jetzt einheitlich.
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Kein Cache, ein Serverfehler statt Empfangs -- Servertext woertlich
    /// plus was trotzdem gilt (designsystem.md SS5), wie
    /// KursDetailView.fehlerKarte.
    private func fehlerUnbekannterZustand(_ fehler: APIError) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text(fehler.servertext)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.danger)
            Text("Deine Anmeldungen sind noch nicht bekannt.")
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

    /// Kein Cache, noch kein Ladeversuch dieser Sitzung (`.bereit`) --
    /// etwa wenn noch kein aktives Studio gewaehlt ist und der Wochenplan
    /// deshalb noch nie geladen hat. Weder "keine Anmeldungen" noch ein
    /// Ladebalken (es laedt ja gerade nichts) -- nur die ehrliche Aussage
    /// plus naechster Schritt.
    private var nochNichtGeladenerZustand: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text("Deine Anmeldungen sind noch nicht geladen.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            Text("Öffne den Wochenplan, damit sie geladen werden.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .accessibilityElement(children: .combine)
    }

    /// Ein Ladeversuch laeuft gerade (`.laedt`) -- reine Flaechen ohne
    /// Text/Zahl, wie KurseWochenView.skelett: ein Ladezustand ist nie
    /// stumm (VoiceOver-Label statt Stille).
    private var ladeSkelett: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .frame(height: 76)
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .frame(height: 76)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Deine Anmeldungen werden geladen")
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
            if !einteilung.spaeter.isEmpty {
                // "Später", nicht "Nächste Woche": das Ladefenster
                // reicht seit Spec 5.1 bis "jetzt plus 14 Tage" und damit
                // je nach Wochentag bis zu sechs Tage in die
                // UEBERnaechste Woche hinein. Eine Anmeldung von dort
                // unter "Nächste Woche" zu fuehren waere eine Aussage
                // ueber ein Datum, die die Daten nicht hergeben -- auf dem
                // Screen, dessen ganzer Zweck es ist, die eigenen
                // Anmeldungen richtig wiederzugeben. Der Datumsblock jeder
                // Zeile nennt den Tag ohnehin.
                abschnitt("Später") {
                    ForEach(einteilung.spaeter) { zeile in
                        spaeterKarte(zeile, zeitzone: eigene.timezone)
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

    // MARK: - Datumsblock (Wochentag kurz + Tag), gemeinsam fuer alle drei Karten

    private func datumsblock(kuerzel: String, tag: Int, farbe: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.s4) {
            Text(kuerzel)
                .font(DesignSystem.Typography.label)
                .foregroundStyle(farbe)
            Text("\(tag)")
                .font(.system(size: 19, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
        }
        .frame(width: 46)
        .padding(.vertical, DesignSystem.Spacing.s8)
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
        // belegungGilt: true ohne Bedeutung -- `.angemeldet` haengt an
        // ownStatus, nicht an freeSeats, und dieser Screen zeigt ohnehin
        // nirgends eine Belegungszahl.
        let fusstext = KursDetailInhalt.fusstext(
            fuer: .angemeldet, abmeldenBisUhrzeit: uhrzeit, abmeldefristVerstrichen: verstrichen,
            wartelistenplatz: nil, belegungGilt: true)

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
                                .foregroundStyle(DesignSystem.Color.textMuted)
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

            // Der Fehler haengt an DIESER sessionId -- eine Zeile zeigt nur
            // ihren eigenen Fehler, nie den einer anderen (Review-Fund M2:
            // "muss erkennbar sein, zu welcher Zeile er gehoert").
            //
            // `!verstrichen` als zweite Bedingung: mit der Frist
            // verschwindet der Abmelden-Knopf, und mit ihm der einzige
            // Weg, den Banner wieder loszuwerden (er wird erst beim
            // naechsten Versuch geloescht). Sonst stuenden auf derselben
            // Karte gleichzeitig "Der Platz ist inzwischen vergeben." und
            // der Fusstext "Die Abmeldefrist ist verstrichen. Dein Platz
            // bleibt reserviert." -- gegenstandslos und widerspruechlich.
            if !verstrichen, case .fehlgeschlagen(let fehler) = abmeldeZustand(zeile.termin.sessionId) {
                InlineBanner(tone: .danger, message: fehler)
                    .padding(.horizontal, DesignSystem.Spacing.s12)
                    .padding(.bottom, DesignSystem.Spacing.s12)
            }
        }
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.accent, lineWidth: 1.5)
        )
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

    /// Der Abmelde-Zustand DIESER Zeile -- reine Ableitung
    /// (`KurseMeineAbmeldeZustand.fuer`) aus der Menge laufender Versuche
    /// und den Fehlermeldungen, damit Knopf und Fehlerbanner derselben
    /// Zeile konsistent bleiben.
    private func abmeldeZustand(_ sessionId: String) -> KurseMeineAbmeldeZustand {
        KurseMeineAbmeldeZustand.fuer(sessionId: sessionId, laufende: stornierendeIds, fehlermeldungen: fehlermeldungen)
    }

    /// "Abmelden" als Nebenaktion (Aufgabenbrief) -- ruft
    /// `KurseStore.stornieren` direkt aus der Zeile heraus auf, ohne den
    /// Umweg ueber KursDetailView. Zeigt waehrend des eigenen Versuchs
    /// einen ProgressView statt Text -- nie ein stummer deaktivierter
    /// Zustand (Review-Fund M2), und nur DIESE Zeile ist gesperrt, jede
    /// andere bleibt unabhaengig bedienbar.
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

    /// Verhindert nur einen zweiten Tap auf DIESELBE Zeile, waehrend ihr
    /// eigener Versuch laeuft -- `stornierendeIds` ist eine Menge
    /// (Review-Fund M2), jede andere Zeile bleibt unabhaengig unterwegs
    /// bedienbar.
    private func abmelden(sessionId: String) async {
        guard !stornierendeIds.contains(sessionId) else { return }
        stornierendeIds.insert(sessionId)
        fehlermeldungen[sessionId] = nil
        do {
            try await kurse.stornieren(sessionId: sessionId)
        } catch {
            // Servertext woertlich -- nur der Server weiss, ob der Platz
            // schon anderweitig vergeben wurde oder die Frist gerade eben
            // verstrichen ist (Aufgabenbrief Task 10, sinngemaess auch
            // hier). Ausnahme: `.offline`, siehe abmeldeFehler(_:).
            fehlermeldungen[sessionId] = abmeldeFehler(error)
        }
        stornierendeIds.remove(sessionId)
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
                                .foregroundStyle(DesignSystem.Color.textMuted)
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.warn.opacity(0.33), lineWidth: 1)
        )
    }

    // MARK: - "Später" -- reiner Vorschau-Eintrag, keine Aktion

    private func spaeterKarte(_ zeile: KurseMeineZeile, zeitzone: String) -> some View {
        let block = datumsblockWerte(zeile.beginn, zeitzone: zeitzone)

        return Button {
            beiAuswahl(zeile.termin.sessionId)
        } label: {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.s12) {
                // textMuted, nicht textFaint: das Kuerzel steht bei 11pt
                // (Typography.label) und ist tragend -- textFaint ist erst
                // ab 15pt oder fuer nicht tragenden Text zugelassen
                // (designsystem.md SS2).
                datumsblock(kuerzel: block.kuerzel, tag: block.tag, farbe: DesignSystem.Color.textMuted)
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
                            .foregroundStyle(DesignSystem.Color.textMuted)
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Kursdetails")
    }

    // MARK: - Fehlertext des Aktionspfads

    /// `.offline` gehoert im Aktionspfad nicht in dieselbe Funktion wie
    /// die Servertexte -- genauso, wie es im Ladepfad herausgezogen ist.
    /// "Keine Verbindung." sagt, was nicht stimmt, aber nicht, was gilt
    /// (SS5), und ausgerechnet hier weiss der Client es nicht: jeder
    /// Transportfehler wird zu `.offline`, auch die Zeitueberschreitung,
    /// bei der die Abmeldung beim Server laengst durch ist. Auf dem
    /// Screen, dessen ganzer Zweck es ist, den eigenen Platz ohne Empfang
    /// zu kennen, ist das der wichtigste Satz ueberhaupt.
    private func abmeldeFehler(_ fehler: APIError) -> String {
        guard fehler == .offline else { return fehler.servertext }
        return "Kein Empfang. Ob deine Abmeldung angekommen ist, wissen wir gerade nicht — dein Platz kann noch besetzt sein. Versuch es noch einmal, sobald du Empfang hast."
    }

}
