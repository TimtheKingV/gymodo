import SwiftUI

/// Die Onboarding-Screens, ein `NavigationStack`, ein Schreibweg.
///
/// Laeuft in zwei Rollen (R21): als Wurzel-Gate (`alsSheet == false`, vor
/// dem Studiobeitritt) und als Sheet -- die Nachholkarte auf Home (Aufgabe
/// 8), wenn das Onboarding auf dem Server bereits abgeschlossen ist.
/// Dieselben Screens, derselbe Schreibweg (`OnboardingSchreiber`); nur
/// `mitAbschluss` und was nach `.fertig` passiert unterscheiden sich.
///
/// Seit Etappe 3 haengt der Block "Dein Trainingsplan" (1.1-1.4) hinter den
/// Bestandsschritten; `umfang` waehlt, welcher Teil laeuft (Home-Karte 1.5:
/// `.nurPlan`/`.nurVorschau`, Anfaengerangebot: `.nurVorschau`).
///
/// Geschrieben wird an zwei Stellen: am Ende (Weiter auf dem letzten
/// Schritt, oder "Später") und VOR der Vorschau -- der Server braucht Ziel,
/// Tage und Trainingsprofil, bevor er einen Vorschlag erzeugen kann.
/// Nach "Plan übernehmen" laedt der Flow den Bootstrap selbst neu (ein
/// Schreibweg-Plan traegt keine Zaehler), in jeder Rolle.
struct OnboardingFlow: View {
    let apiClient: APIClient
    let alsSheet: Bool
    var umfang: OnboardingUmfang = .komplett
    let beiFertig: () -> Void

    @Environment(CatalogStore.self) private var catalogStore

    @State private var antworten = OnboardingAntworten()
    @State private var plan = PlanAntworten(profil: nil)
    /// Einmal je Flow aus dem Bootstrap vorbelegt (`.task`), nicht im init:
    /// dort gibt es die Umgebung noch nicht.
    @State private var planVorbelegt = false
    /// Schritte, die ein Sonderfall nachtraeglich braucht ("Ergänzen",
    /// "Beschwerden ändern", "Zeit oder Schwerpunkt ändern"), siehe
    /// `OnboardingAntworten.schritte(umfang:ergaenzt:)`.
    @State private var ergaenzt: [OnboardingSchritt] = []
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
    /// Der Stand des letzten GELUNGENEN Schreibversuchs. Ein zweiter (nach
    /// einem Umweg aus der Vorschau zurueck) schreibt nur, was sich seitdem
    /// geaendert hat (`OnboardingSchreiber.geaenderteVorgaenge`).
    @State private var geschrieben: (antworten: OnboardingAntworten, plan: PlanAntworten)?
    @State private var schreibtGerade = false
    /// Wohin es nach dem Schreiben geht -- auch nach einem Fehler: "Erneut
    /// versuchen" setzt fort, was der gescheiterte Versuch vorhatte (Ende
    /// nach "Später", Vorschau nach den Beschwerden).
    @State private var fortsetzung: Fortsetzung = .beenden

    private enum Fortsetzung {
        case beenden
        case schritt(Int)
    }

    private var schritte: [OnboardingSchritt] {
        antworten.schritte(umfang: umfang, ergaenzt: ergaenzt, mitKursen: kursFrageSichtbar)
    }

    /// Kurse gibt es nur in einem Studio. Der Bootstrap sagt nicht, ob ein
    /// Studio Kurse anbietet -- ein zugeordnetes Studio zaehlt deshalb als
    /// "mit Kursen" (wie der Plan-Tab, der Kurse ebenfalls an `studios`
    /// festmacht). Im Wurzel-Gate vor dem Beitritt entfaellt die Frage.
    private var kursFrageSichtbar: Bool {
        plan.kursFrageSichtbar(hatStudioMitKursen: !(catalogStore.bootstrap?.studios.isEmpty ?? true))
    }

    var body: some View {
        if umfang == .nurBeschwerden {
            // Eigener Ablauf: dort MUSS der Abruf der Beschwerden gelingen,
            // bevor gespeichert werden darf (siehe `BeschwerdenSitzung`) --
            // hier im Flow heisst ein gescheiterter Abruf nur "keine
            // Einwilligung bekannt".
            BeschwerdenSheet(apiClient: apiClient, beiFertig: beiFertig)
        } else {
            NavigationStack(path: $pfad) {
                schrittAnsicht(index: 0)
                    .navigationDestination(for: Int.self) { index in
                        schrittAnsicht(index: index)
                    }
            }
            .tint(DesignSystem.Color.accent)
            .task { await planVorbelegen() }
        }
    }

    // MARK: - Eine Schrittansicht

    @ViewBuilder
    private func schrittAnsicht(index: Int) -> some View {
        // `schritte` kann waehrend des Flows schrumpfen (Gewicht in Schritt
        // 2 wieder geloescht -> Schritt 5 faellt weg). Ein bereits gepushter
        // Index faellt dann auf den letzten gueltigen zurueck, statt den
        // Array-Zugriff crashen zu lassen.
        let schritte = schritte
        let gueltigerIndex = min(index, schritte.count - 1)
        let schritt = schritte[gueltigerIndex]

        Group {
            if schritt == .planVorschau {
                vorschau(index: gueltigerIndex, gesamt: schritte.count)
            } else {
                // Auch "Deine Woche" laeuft als Frageschritt: Kopf, Weiter und
                // Fehlerbanner sind dieselben, nur der Inhalt laedt selbst.
                frageSchritt(schritt, index: gueltigerIndex, schritte: schritte)
            }
        }
        // Eine neue Identitaet je Schritt: ergaenzte Schritte koennen den
        // Schritt an einem Index austauschen (etwa die Wurzel), und die
        // Vorschau soll bei jedem Betreten einen neuen Vorschlag holen.
        .id(schritt)
        // Am Schritt selbst, nicht am NavigationStack: der Modifier stellt
        // den umgebenden Container ein, und die gepushten Schritte bekaemen
        // sonst eine System-Leiste mit Zurueck-Pfeil ueber der eigenen
        // Schrittzeile. Zurueck ist im Entwurf nicht vorgesehen.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func frageSchritt(_ schritt: OnboardingSchritt, index: Int, schritte: [OnboardingSchritt]) -> some View {
        let istLetzter = index == schritte.count - 1
        let kannWeiter = plan.kannWeiter(schritt)
        return OnboardingScreen(
            schrittNummer: index + 1,
            gesamtSchritte: schritte.count,
            titel: titel(fuer: schritt),
            lead: lead(fuer: schritt),
            fussnote: fussnote(fuer: schritt),
            primaryTitle: primaryTitle(istLetzter: istLetzter),
            primaryEnabled: !schreibtGerade && kannWeiter,
            primaryLoading: schreibtGerade,
            primaryDisabledHint: schreibtGerade ? "Schreibt gerade" : plan.weiterGesperrtHinweis(schritt),
            spaeterEnabled: !schreibtGerade,
            bereich: schritt.gehoertZumPlan ? "Dein Trainingsplan" : nil,
            spaeterTitel: Self.mitUeberspringen.contains(schritt) ? "Überspringen" : "Später",
            beiSpaeter: {
                Task {
                    if Self.mitUeberspringen.contains(schritt) {
                        await ueberspringen(schritt, index: index)
                    } else {
                        await spaeter()
                    }
                }
            },
            beiWeiter: { await primaryAktion(schritt: schritt, index: index) }
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                if case .teilweise(let offen, let fehler) = ergebnis {
                    InlineBanner(tone: .danger, message: OnboardingHinweis.hinweis(
                        offen: offen, fehler: fehler, mitBestand: umfang == .komplett))
                }
                inhalt(fuer: schritt)
            }
        }
    }

    private func vorschau(index: Int, gesamt: Int) -> some View {
        PlanVorschauSchritt(
            apiClient: apiClient,
            studioId: catalogStore.activeStudioId,
            schrittNummer: index + 1,
            gesamtSchritte: gesamt,
            beschwerden: plan.beschwerden,
            beiUebernommen: {
                await catalogStore.load()
                beiFertig()
            },
            beiSpaeter: { await beenden() },
            beiZeitOderSchwerpunkt: { springen(zu: [.planZeit, .planSchwerpunkt]) },
            beiSonderfall: { aktion in
                switch aktion {
                case .beschwerdenAendern: springen(zu: [.planBeschwerden])
                case .ergaenzen(let fehlend): springen(zu: fehlend)
                }
            }
        )
    }

    private func primaryTitle(istLetzter: Bool) -> String {
        guard case .teilweise = ergebnis else {
            return istLetzter ? "Los geht’s" : "Weiter"
        }
        return "Erneut versuchen"
    }

    // MARK: - Aktionen

    /// "Weiter"/"Los geht's": bestaetigt bei Bedarf eine Vorgabe (R16 fuer
    /// Schritt 4, dieselbe Regel fuer das Zielgewicht in Schritt 5) und
    /// geht dann einen Schritt weiter -- vor der Vorschau und am Ende erst
    /// nach dem Schreiben. Waehrend eines Wiederholungsversuchs
    /// (`.teilweise`) macht dieselbe Aktion nur noch das eine: erneut
    /// versuchen.
    private func primaryAktion(schritt: OnboardingSchritt, index: Int) async {
        if ergebnis == nil {
            switch schritt {
            case .wieOft where antworten.tageProWoche == nil:
                antworten.tageProWoche = OnboardingAntworten.tageVorgabe
            case .zielgewicht where antworten.zielgewichtKg == nil:
                antworten.zielgewichtKg = antworten.gewichtKg
            default:
                break
            }
        }
        await weiter(nach: index)
    }

    /// Der eine Weg nach vorn: zum naechsten Schritt, vor "Deine Woche",
    /// vor der Vorschau und am Ende mit Schreiben -- beide holen einen
    /// Vorschlag vom Server, der Kurs- und Cardio-Tage (und nach einem Tausch
    /// die Krafttage) schon kennen muss. Ein offener Fehler (`.teilweise`)
    /// wird immer zuerst wiederholt -- sonst stuende die Vorschau vor einem
    /// Profil, das der Server nicht hat.
    private func weiter(nach index: Int) async {
        if ergebnis == nil {
            let schritte = schritte
            let naechster = index + 1 < schritte.count ? schritte[index + 1] : nil
            if let naechster, naechster != .planVorschau, naechster != .planWoche {
                gehe(zu: index + 1)
                return
            }
            // Ein Tausch gehoert zu genau einem Vorschlag: vor einer neuen
            // Woche verteilt der Server die Krafttage wieder selbst.
            if naechster == .planWoche { plan.wocheNeuVorschlagen() }
            fortsetzung = naechster == nil ? .beenden : .schritt(index + 1)
        }
        guard await schreiben() else { return }
        switch fortsetzung {
        case .beenden: await beendenOhneSperre()
        case .schritt(let ziel): gehe(zu: ziel)
        }
    }

    /// Schritte, die statt "Später" ein "Überspringen" tragen (Entwurf 1.3,
    /// Leinwaende 2c/2c2): sie gehen weiter, ohne etwas zu aendern.
    private static let mitUeberspringen: Set<OnboardingSchritt> = [.planBeschwerden, .planKurse, .planCardio]

    /// "Überspringen": die Antworten dieses Schritts bleiben, wie der Server
    /// sie kennt -- bei 1.3 kein PUT, kein Widerruf; bei Kurs und Cardio der
    /// Stand aus dem Profil --, sonst wie "Weiter".
    private func ueberspringen(_ schritt: OnboardingSchritt, index: Int) async {
        switch schritt {
        case .planBeschwerden: plan.beschwerdenVerwerfen()
        case .planKurse: plan.kurseVerwerfen()
        case .planCardio: plan.cardioVerwerfen()
        default: break
        }
        await weiter(nach: index)
    }

    /// "Später": vor dem ersten Schreibversuch und solange das Profil
    /// offen ist ein Schreibversuch. Ist das Profil nach einem Teilerfolg
    /// geschrieben, beendet es ohne neuen Versuch
    /// (`OnboardingSchreiber.spaeterBeendet`) -- "Erneut versuchen" bleibt
    /// dafuer der Weg.
    ///
    /// Es setzt bewusst KEINE Vorgabe: wer auf Schritt 4 "Später" tippt,
    /// bevor er bestaetigt hat, bekommt kein Wochenziel (R16), und wer auf
    /// Schritt 5 "Später" tippt, kein Zielgewicht (Fussnote dieses Schritts).
    private func spaeter() async {
        if case .teilweise(let offen, _) = ergebnis, OnboardingSchreiber.spaeterBeendet(offen: offen) {
            await beenden()
            return
        }
        fortsetzung = .beenden
        guard await schreiben() else { return }
        await beendenOhneSperre()
    }

    /// Ein Schreibversuch mit allem, was bis hierher beantwortet ist --
    /// nie mit leeren Antworten. `true` = alles geschrieben.
    private func schreiben() async -> Bool {
        schreibtGerade = true
        defer { schreibtGerade = false }

        var offen: [OnboardingSchreibvorgang]?
        if let geschrieben {
            offen = OnboardingSchreiber.geaenderteVorgaenge(
                vorher: geschrieben.antworten, planVorher: geschrieben.plan, jetzt: antworten, planJetzt: plan)
        }
        if let offenNachFehler {
            // Die Plan-Vorgaenge immer mit: zwischen Fehler und Wiederholung
            // kann das Mitglied auf 1.1-1.3 weiter waehlen, und beide sind
            // idempotente Aufrufe (PUT/DELETE).
            offen = offenNachFehler + [.trainingsprofil, .beschwerden]
        }
        let neuesErgebnis = await OnboardingSchreiber.schreiben(
            antworten, plan: plan, mit: apiClient, mitAbschluss: !alsSheet, offen: offen
        )
        switch neuesErgebnis {
        case .fertig:
            ergebnis = nil
            offenNachFehler = nil
            plan.beschwerdenGeschrieben()
            geschrieben = (antworten, plan)
            return true
        case .teilweise(let offen, _):
            ergebnis = neuesErgebnis
            offenNachFehler = offen
            return false
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

    // MARK: - Navigation

    /// Index -> Pfad: der Stack zeigt Wurzel (0) plus je einen Push.
    private func gehe(zu index: Int) {
        pfad = index <= 0 ? [] : Array(1...index)
    }

    /// Zurueck (oder vor) zum ersten der genannten Schritte. Steht einer
    /// davon nicht im Flow (reine Vorschau, nur Plan), wird er ergaenzt.
    /// Ziel und Tage kommen dabei mit dem Stand aus dem Bootstrap vorbelegt,
    /// damit "Ändern" zeigt, was gilt, statt leer zu beginnen.
    private func springen(zu ziele: [OnboardingSchritt]) {
        let member = catalogStore.bootstrap?.member
        if ziele.contains(.ziel), antworten.richtung == nil {
            antworten.richtung = member?.trainingGoal.flatMap(Trainingsrichtung.init(rawValue:))
        }
        if ziele.contains(.wieOft), antworten.tageProWoche == nil {
            antworten.tageProWoche = member?.goals.weeklyDays.map { Int($0.targetValue) }
        }
        let fehlend = ziele.filter { !schritte.contains($0) }
        ergaenzt.append(contentsOf: fehlend)
        ergebnis = nil
        offenNachFehler = nil
        let neu = schritte
        guard let ziel = ziele.compactMap({ neu.firstIndex(of: $0) }).min() else { return }
        gehe(zu: ziel)
    }

    /// Trainingsprofil aus dem Bootstrap, Beschwerden aus dem eigenen Abruf
    /// (Gesundheitsdaten stehen nie im Bootstrap-Cache). Scheitert der Abruf,
    /// bleibt "keine Einwilligung bekannt" -- dann gibt es auch keinen
    /// Widerruf, nur ein bewusstes neues Einwilligen.
    private func planVorbelegen() async {
        guard !planVorbelegt else { return }
        planVorbelegt = true
        plan = PlanAntworten(profil: catalogStore.bootstrap?.member.trainingProfile)
        plan.wochenGefragt = schritte.contains(.planCardio)
        if !kursFrageSichtbar { plan.kurseOhneFrage() }
        let vorher = (plan.beschwerden, plan.einwilligung)
        guard let areas = try? await apiClient.trainingLimits() else { return }
        // Hat das Mitglied waehrend des Abrufs schon Beschwerden oder den
        // Haken gesetzt, gewinnt seine Wahl. Nur diese zwei zaehlen: ein
        // Tipp auf Minuten oder Schwerpunkt verwarf sonst den Abruf, und
        // ein spaeterer Widerruf liefe ins Leere (Review Task 10, m1).
        guard plan.beschwerden == vorher.0, plan.einwilligung == vorher.1 else { return }
        plan.beschwerdenUebernehmen(areas)
    }

    // MARK: - Texte je Schritt (verbatim aus gen.py bzw. den Plan-Entwuerfen, siehe R20 fuer die eine Ausnahme)

    private func titel(fuer schritt: OnboardingSchritt) -> String {
        switch schritt {
        case .ueberDich: "Über dich"
        case .koerper: "Dein Körper"
        case .ziel: "Dein Ziel"
        case .wieOft: "Wie oft?"
        case .zielgewicht: "Zielgewicht"
        case .planZeit: "Zeit und Erfahrung"
        case .planSchwerpunkt: "Wo soll mehr passieren?"
        case .planBeschwerden: "Was sollen wir schonen?"
        case .planKurse: "Gehst du in Kurse?"
        case .planCardio: "Machst du auch Cardio außerhalb?"
        case .planWoche: "Deine Woche"
        case .planVorschau: "Dein Plan"
        }
    }

    private func lead(fuer schritt: OnboardingSchritt) -> String? {
        switch schritt {
        case .ueberDich:
            // Nicht-verhandelbare Regel 2: Koerperdaten sieht niemand
            // ausser dem Mitglied -- dieser Satz sagt es woertlich.
            "Beides freiwillig. Nur du siehst es — dein Studio nicht."
        case .koerper:
            "Das Gewicht wird der erste Punkt deines Verlaufs."
        case .ziel:
            "Eine Richtung. Gymtavo gibt keine Empfehlung dazu — das Ziel ist deins."
        case .wieOft:
            // R20: das Artboard sagt "Die Serie auf Home zaehlt gegen
            // dieses Ziel" -- das widerspricht der Spec (die Serie ist vom
            // Wochenziel unabhaengig, nicht-verhandelbare Regel 1). Dieser
            // Satz ersetzt ihn, alles andere bleibt woertlich.
            "Trainingstage pro Woche. Auf Home steht es als eigene Zeile unter deiner Serie."
        case .zielgewicht:
            "Heute \(Zahlformat.gewichtMitEinheit(antworten.gewichtKg ?? 0)). Wohin soll es gehen?"
        // Entwurf 1.1 hat keinen Lead; 1.2 nur "Bis zu zwei." (Korrektur
        // Tim: keine Erklaerung im Schritt, die steht unter "Warum so?").
        case .planZeit: nil
        case .planSchwerpunkt: "Bis zu zwei."
        case .planBeschwerden:
            "Freiwillig. Wir lassen dann Übungen weg, die den Bereich stark belasten, oder wählen schonendere."
        case .planKurse:
            "In deinem Studio gibt es Kurse. Wenn du welche besuchst, plane ich sie mit ein, damit Einheiten und Kurse sich nicht ins Gehege kommen."
        case .planCardio:
            "Laufen, Radfahren, Schwimmen: Was nicht im Studio stattfindet, kommt als eigener Termin in deinen Plan und zählt als Trainingstag."
        case .planWoche:
            PlanWochenText.wochenLead(kurse: !plan.kursTage.isEmpty, cardio: !plan.cardioTage.isEmpty)
        case .planVorschau: nil
        }
    }

    private func fussnote(fuer schritt: OnboardingSchritt) -> String? {
        switch schritt {
        case .ueberDich: "Nichts gewählt heißt: keine Angabe."
        case .koerper: "Beides freiwillig. Änderbar und löschbar im Profil."
        case .ziel: nil
        case .wieOft: "Zwei Einheiten an einem Tag sind ein Tag. Erreichbar ist besser als ehrgeizig — du kannst es jederzeit im Profil verschieben."
        case .zielgewicht: "Braucht Verbindung. „Später“ beendet ohne Zielgewicht."
        case .planZeit, .planSchwerpunkt, .planBeschwerden, .planKurse, .planCardio, .planWoche, .planVorschau: nil
        }
    }

    /// "Muskeln aufbauen · 3 Tage pro Woche" fuer 1.1 -- die Antworten dieses
    /// Flows vor dem Stand im Bootstrap; nil, wenn beides fehlt.
    private var bestandsangaben: String? {
        let member = catalogStore.bootstrap?.member
        let richtung = antworten.richtung ?? member?.trainingGoal.flatMap(Trainingsrichtung.init(rawValue:))
        let tage = antworten.tageProWoche ?? member?.goals.weeklyDays.map { Int($0.targetValue) }
        let teile = [richtung?.wort, tage.map { $0 == 1 ? "1 Tag pro Woche" : "\($0) Tage pro Woche" }]
            .compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
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
        case .planZeit:
            PlanZeitSchritt(minuten: $plan.minuten, erfahrung: $plan.erfahrung, angaben: bestandsangaben) {
                springen(zu: [.ziel, .wieOft])
            }
        case .planSchwerpunkt:
            PlanSchwerpunktSchritt(plan: $plan)
        case .planBeschwerden:
            PlanBeschwerdenSchritt(plan: $plan)
        case .planKurse:
            PlanKursSchritt(plan: $plan)
        case .planCardio:
            PlanCardioSchritt(plan: $plan)
        case .planWoche:
            PlanWochenSchritt(apiClient: apiClient, studioId: catalogStore.activeStudioId, plan: $plan)
        case .planVorschau:
            // Steht nie hier: `schrittAnsicht` zeigt dafuer PlanVorschauSchritt.
            EmptyView()
        }
    }
}
