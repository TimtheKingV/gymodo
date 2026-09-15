import SwiftUI

/// Die fuenf Onboarding-Screens, ein `NavigationStack`, ein Schreibweg.
///
/// Laeuft in zwei Rollen (R21): als Wurzel-Gate (`alsSheet == false`, vor
/// dem Studiobeitritt) und als Sheet -- die Nachholkarte auf Home (Aufgabe
/// 8), wenn das Onboarding auf dem Server bereits abgeschlossen ist.
/// Dieselben fuenf Screens, derselbe Schreibweg (`OnboardingSchreiber`);
/// nur `mitAbschluss` und was nach `.fertig` passiert unterscheiden sich.
struct OnboardingFlow: View {
    let apiClient: APIClient
    let alsSheet: Bool
    let beiFertig: () -> Void

    @Environment(CatalogStore.self) private var catalogStore

    @State private var antworten = OnboardingAntworten()
    /// Indizes, die der Stack ZUSAETZLICH zum Wurzelschritt (0) zeigt --
    /// ein echter Push je "Weiter", kein Zustandswechsel in derselben
    /// View. Reduce Motion braucht dafuer keinen Sonderfall: ein
    /// `NavigationStack`-Push ist System-Animation, die Reduce Motion
    /// bereits von sich aus respektiert (Brief).
    @State private var pfad: [Int] = []
    @State private var ergebnis: OnboardingErgebnis?
    /// Aus einem `.teilweise`-Ergebnis uebernommen: der naechste Versuch
    /// (per "Erneut versuchen", oder per "Später", solange das Profil offen
    /// ist) wiederholt NUR das hier Genannte (R19), nie einen kompletten
    /// Neuanfang.
    @State private var offenNachFehler: [OnboardingSchreibvorgang]?
    @State private var schreibtGerade = false

    var body: some View {
        NavigationStack(path: $pfad) {
            schrittAnsicht(index: 0)
                .navigationDestination(for: Int.self) { index in
                    schrittAnsicht(index: index)
                }
        }
        .tint(DesignSystem.Color.accent)
    }

    // MARK: - Eine Schrittansicht

    @ViewBuilder
    private func schrittAnsicht(index: Int) -> some View {
        // `antworten.schritte` kann waehrend des Flows schrumpfen (Gewicht
        // in Schritt 2 wieder geloescht -> Schritt 5 faellt weg). Ein
        // bereits gepushter Index faellt dann auf den letzten gueltigen
        // zurueck, statt den Array-Zugriff crashen zu lassen.
        let schritte = antworten.schritte
        let gueltigerIndex = min(index, schritte.count - 1)
        let schritt = schritte[gueltigerIndex]
        let istLetzter = gueltigerIndex == schritte.count - 1

        OnboardingScreen(
            schrittNummer: gueltigerIndex + 1,
            gesamtSchritte: schritte.count,
            titel: titel(fuer: schritt),
            lead: lead(fuer: schritt),
            fussnote: fussnote(fuer: schritt),
            primaryTitle: primaryTitle(fuer: schritt, istLetzter: istLetzter),
            primaryEnabled: !schreibtGerade,
            primaryLoading: schreibtGerade,
            primaryDisabledHint: schreibtGerade ? "Schreibt gerade" : nil,
            spaeterEnabled: !schreibtGerade,
            beiSpaeter: { Task { await spaeter() } },
            beiWeiter: { await primaryAktion(schritt: schritt, istLetzter: istLetzter) }
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                if case .teilweise(let offen, let fehler) = ergebnis {
                    InlineBanner(tone: .danger, message: OnboardingHinweis.hinweis(offen: offen, fehler: fehler))
                }
                inhalt(fuer: schritt)
            }
        }
        // Am Schritt selbst, nicht am NavigationStack: der Modifier stellt
        // den umgebenden Container ein, und die gepushten Schritte bekaemen
        // sonst eine System-Leiste mit Zurueck-Pfeil ueber der eigenen
        // Schrittzeile. Zurueck ist im Entwurf nicht vorgesehen.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func primaryTitle(fuer schritt: OnboardingSchritt, istLetzter: Bool) -> String {
        guard case .teilweise = ergebnis else {
            return istLetzter ? "Los geht’s" : "Weiter"
        }
        return "Erneut versuchen"
    }

    /// "Weiter"/"Los geht's": bestaetigt bei Bedarf eine Vorgabe (R16 fuer
    /// Schritt 4, dieselbe Regel fuer das Zielgewicht in Schritt 5) und
    /// geht dann entweder einen Schritt weiter oder schliesst ab. Waehrend
    /// eines Wiederholungsversuchs (`.teilweise`) macht dieselbe Aktion
    /// nur noch das eine: erneut versuchen.
    private func primaryAktion(schritt: OnboardingSchritt, istLetzter: Bool) async {
        guard ergebnis == nil else {
            await abschliessen()
            return
        }
        switch schritt {
        case .wieOft where antworten.tageProWoche == nil:
            antworten.tageProWoche = OnboardingAntworten.tageVorgabe
        case .zielgewicht where antworten.zielgewichtKg == nil:
            antworten.zielgewichtKg = antworten.gewichtKg
        default:
            break
        }
        if istLetzter {
            await abschliessen()
        } else {
            pfad.append(pfad.count + 1)
        }
    }

    /// "Später": vor dem ersten Schreibversuch und solange das Profil
    /// offen ist ein Schreibversuch (`abschliessen`). Ist das Profil nach
    /// einem Teilerfolg geschrieben, beendet es ohne neuen Versuch
    /// (`OnboardingSchreiber.spaeterBeendet`) -- "Erneut versuchen" bleibt
    /// dafuer der Weg.
    private func spaeter() async {
        if case .teilweise(let offen, _) = ergebnis, OnboardingSchreiber.spaeterBeendet(offen: offen) {
            await beenden()
        } else {
            await abschliessen()
        }
    }

    /// "Später" ruft dies auf JEDEM Schritt auf, mit den bis dahin
    /// gesetzten Antworten -- nie mit leeren (Brief Step 1). Es setzt
    /// bewusst KEINE Vorgabe: wer auf Schritt 4 "Später" tippt, bevor er
    /// bestaetigt hat, bekommt kein Wochenziel (R16), und wer auf Schritt 5
    /// "Später" tippt, kein Zielgewicht (Fussnote dieses Schritts).
    private func abschliessen() async {
        schreibtGerade = true
        defer { schreibtGerade = false }

        let neuesErgebnis = await OnboardingSchreiber.schreiben(
            antworten, mit: apiClient, mitAbschluss: !alsSheet, offen: offenNachFehler
        )
        switch neuesErgebnis {
        case .fertig:
            ergebnis = nil
            offenNachFehler = nil
            await beendenOhneSperre()
        case .teilweise(let offen, _):
            ergebnis = neuesErgebnis
            offenNachFehler = offen
        }
    }

    private func beenden() async {
        schreibtGerade = true
        defer { schreibtGerade = false }
        await beendenOhneSperre()
    }

    /// Wurzel-Modus: der Bootstrap traegt jetzt onboardingCompletedAt, das
    /// Gate schliesst sich mit dem Neuladen von selbst. Sheet-Modus: der
    /// Aufrufer (Home) laedt selbst neu (Aufgabe 8).
    private func beendenOhneSperre() async {
        if !alsSheet { await catalogStore.load() }
        beiFertig()
    }

    // MARK: - Texte je Schritt (verbatim aus gen.py, siehe R20 fuer die eine Ausnahme)

    private func titel(fuer schritt: OnboardingSchritt) -> String {
        switch schritt {
        case .ueberDich: "Über dich"
        case .koerper: "Dein Körper"
        case .ziel: "Dein Ziel"
        case .wieOft: "Wie oft?"
        case .zielgewicht: "Zielgewicht"
        }
    }

    private func lead(fuer schritt: OnboardingSchritt) -> String {
        switch schritt {
        case .ueberDich:
            // Nicht-verhandelbare Regel 2: Koerperdaten sieht niemand
            // ausser dem Mitglied -- dieser Satz sagt es woertlich.
            "Beides freiwillig. Nur du siehst es — dein Studio nicht."
        case .koerper:
            "Das Gewicht wird der erste Punkt deines Verlaufs."
        case .ziel:
            "Eine Richtung. gymodo gibt keine Empfehlung dazu — das Ziel ist deins."
        case .wieOft:
            // R20: das Artboard sagt "Die Serie auf Home zaehlt gegen
            // dieses Ziel" -- das widerspricht der Spec (die Serie ist vom
            // Wochenziel unabhaengig, nicht-verhandelbare Regel 1). Dieser
            // Satz ersetzt ihn, alles andere bleibt woertlich.
            "Trainingstage pro Woche. Auf Home steht es als eigene Zeile unter deiner Serie."
        case .zielgewicht:
            "Heute \(Zahlformat.gewichtMitEinheit(antworten.gewichtKg ?? 0)). Wohin soll es gehen?"
        }
    }

    private func fussnote(fuer schritt: OnboardingSchritt) -> String? {
        switch schritt {
        case .ueberDich: "Nichts gewählt heißt: keine Angabe."
        case .koerper: "Beides freiwillig. Änderbar und löschbar im Profil."
        case .ziel: nil
        case .wieOft: "Zwei Einheiten an einem Tag sind ein Tag. Erreichbar ist besser als ehrgeizig — du kannst es jederzeit im Profil verschieben."
        case .zielgewicht: "Braucht Verbindung. „Später“ beendet ohne Zielgewicht."
        }
    }

    @ViewBuilder
    private func inhalt(fuer schritt: OnboardingSchritt) -> some View {
        switch schritt {
        case .ueberDich:
            UeberDichSchritt(geschlecht: $antworten.geschlecht, altersspanne: $antworten.altersspanne)
        case .koerper:
            KoerperSchritt(groesseCm: $antworten.groesseCm, gewichtKg: $antworten.gewichtKg)
        case .ziel:
            ZielSchritt(richtung: $antworten.richtung)
        case .wieOft:
            WieOftSchritt(tage: Binding(
                get: { antworten.tageProWoche ?? OnboardingAntworten.tageVorgabe },
                set: { antworten.tageProWoche = $0 }
            ))
        case .zielgewicht:
            ZielgewichtSchritt(
                gewichtKg: antworten.gewichtKg,
                zielgewichtKg: Binding(
                    get: { antworten.zielgewichtKg ?? antworten.gewichtKg ?? 75.0 },
                    set: { antworten.zielgewichtKg = $0 }
                )
            )
        }
    }
}
