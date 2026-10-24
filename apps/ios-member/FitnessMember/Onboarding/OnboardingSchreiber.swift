import Foundation

/// Der Ausschnitt aus `APIClient`, den das Onboarding zum Schreiben
/// braucht -- als eigenes Protokoll, damit `OnboardingSchreiberTests` eine
/// Attrappe statt echter Netzwerkaufrufe einsetzen kann.
///
/// `Sendable` und `throws(APIError)` sind hier keine Zutat, sondern die
/// Voraussetzung dafuer, dass der Actor `APIClient` (siehe unten) ohne
/// Isolationsfehler konform gehen kann: ein `async throws`-Protokoll ohne
/// explizite Fehlerart wuerde `any Error` erwarten, `APIClient`s Methoden
/// werfen aber `APIError`.
protocol ProfilSchreibend: Sendable {
    func updateProfile(_ body: ProfilWrite) async throws(APIError) -> ProfilAntwort
    func putMeasurement(_ body: MesswertWrite) async throws(APIError) -> MesswertAntwort
    func setGoal(_ body: ZielWrite) async throws(APIError) -> Ziel
    func putTrainingProfile(_ profil: TrainingsplanProfil) async throws(APIError) -> TrainingsplanProfil
    func putTrainingLimits(areas: [String: String]) async throws(APIError)
    func deleteTrainingLimits() async throws(APIError)
    /// Fuer das Beschwerden-Sheet im Profil: ohne gelungenen Abruf kein
    /// Speichern (`BeschwerdenSitzung`). nil = 404, keine Einwilligung.
    func trainingLimits() async throws(APIError) -> [String: String]?
}

extension APIClient: ProfilSchreibend {}

/// Die Schreibvorgaenge des Onboardings, in Sendereihenfolge -- die vier
/// Bestandsvorgaenge, danach die zwei des Plan-Blocks (Etappe 3).
///
/// R19: `offen` merkt sich SCHREIBVORGAENGE, nicht Screens. `OnboardingSchritt`
/// (fuenf Screens) und diese vier Aufrufe faelen unterschiedlich fein --
/// `.profil` deckt allein drei Screens ab (ueberDich, die Groesse aus
/// koerper, ziel), waehrend `koerper` als Screen zugleich zur Messung
/// gehoert. Eine Wiederholung, die sich Screens merkt, kann diese
/// Ueberschneidung nicht auflösen (siehe Git-Historie dieser Datei); ein
/// Schreibvorgang ist dagegen genau ein API-Aufruf und eindeutig.
enum OnboardingSchreibvorgang: Equatable, Sendable, CaseIterable {
    case profil, messwert, wochenziel, zielgewicht
    /// PUT training-profile (Entwurf 1.1/1.2).
    case trainingsprofil
    /// PUT oder DELETE training-limits (Entwurf 1.3) -- welches von beiden,
    /// entscheidet `PlanAntworten.beschwerdenAktion`.
    case beschwerden
}

/// Das Ergebnis eines Schreibversuchs -- `offen` traegt genug, um einen
/// Wiederholungsversuch auf genau das zu beschraenken, was noch fehlt.
enum OnboardingErgebnis: Equatable {
    case fertig
    case teilweise(offen: [OnboardingSchreibvorgang], fehler: APIError)
}

/// Ordnet die Schreibvorgaenge des Onboardings -- eine `enum` mit einer
/// statischen Funktion, kein Store: sie haelt keinen Zustand, der
/// Aufrufer reicht `offen` selbst von einem Versuch zum naechsten weiter.
///
/// Profil zuerst, weil `onboardingDone` das Gate schliesst -- scheitern
/// die Ziele danach, oeffnet sich das Gate nicht mehr, aber Home zeigt die
/// Nachholkarte, und die traegt dieselben Antworten (Spec 5.2).
enum OnboardingSchreiber {
    /// `mitAbschluss` unterscheidet die zwei Laeufe desselben Flows (R21):
    /// als Wurzel-Gate (Vorgabe `true`) setzt das Profil-PUT
    /// `onboardingDone`, und laeuft deshalb immer mit, auch bei leeren
    /// Antworten -- irgendetwas muss das Gate schliessen. Als Sheet
    /// (Nachholkarte auf Home, Aufgabe 8) ist das Onboarding auf dem
    /// Server bereits abgeschlossen: ein zweites `onboardingDone` gaebe es
    /// nicht, und das Profil-PUT liefe nur noch fuer eigene Antworten mit.
    ///
    /// `plan` ist nil, solange der Flow den Plan-Block nicht zeigt (dann
    /// bleibt alles wie vor Etappe 3). Der Block laeuft NACH den
    /// Bestandsvorgaengen: der Plan braucht Ziel und Wochentage aus dem
    /// Profil, und ein Profil ohne `onboardingDone` liesse das Gate offen.
    static func schreiben(
        _ antworten: OnboardingAntworten,
        plan: PlanAntworten? = nil,
        mit client: some ProfilSchreibend,
        mitAbschluss: Bool = true,
        offen: [OnboardingSchreibvorgang]? = nil
    ) async -> OnboardingErgebnis {
        if mussLaufen(.profil, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss, offen: offen) {
            let schreibvorgang = ProfilWrite(
                sex: antworten.geschlecht.map { .setzen($0.rawValue) },
                heightCm: antworten.groesseCm.map { .setzen($0) },
                ageBand: antworten.altersspanne.map { .setzen($0.rawValue) },
                trainingGoal: antworten.richtung.map { .setzen($0.rawValue) },
                // nil statt false im Sheet-Modus: die Eigenschaft heisst
                // "nicht gesendet" (siehe ProfilWrite.encode), kein
                // zweiter Weg, dasselbe zu sagen.
                onboardingDone: mitAbschluss ? true : nil
            )
            do {
                _ = try await client.updateProfile(schreibvorgang)
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .profil, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.messwert, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss, offen: offen) {
            do {
                _ = try await client.putMeasurement(MesswertWrite(measuredOn: heute(), weightKg: antworten.gewichtKg!))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .messwert, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.wochenziel, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "weekly_days", targetValue: Double(antworten.tageProWoche!)))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .wochenziel, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.zielgewicht, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "target_weight", targetValue: antworten.zielgewichtKg!))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .zielgewicht, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.trainingsprofil, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss, offen: offen),
           let profil = plan?.trainingsprofil {
            do {
                _ = try await client.putTrainingProfile(profil)
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .trainingsprofil, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.beschwerden, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss, offen: offen),
           let aktion = plan?.beschwerdenAktion {
            do {
                switch aktion {
                case .keine: break
                // Nur mit `einwilligung == true` erreichbar (siehe
                // `beschwerdenAktion`); die Bereiche selbst landen in keinem
                // Log und keiner Ablage (DSGVO Art. 9).
                case .speichern(let areas): try await client.putTrainingLimits(areas: areas)
                case .widerrufen: try await client.deleteTrainingLimits()
                }
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .beschwerden, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        return .fertig
    }

    /// Die Vorgaenge, auf die ein Umfang beschraenkt ist; nil = alle mit
    /// einer Antwort. Die Profilzeile "Beschwerden" (`nurBeschwerden`)
    /// schreibt nur die Beschwerden -- ein vorbelegtes Trainingsprofil ginge
    /// sonst ungefragt mit.
    static func vorgaenge(umfang: OnboardingUmfang) -> [OnboardingSchreibvorgang]? {
        umfang == .nurBeschwerden ? [.beschwerden] : nil
    }

    /// Was nach einem GELUNGENEN Versuch noch einmal laufen muss, wenn der
    /// Flow erneut schreibt (etwa nach "Zeit oder Schwerpunkt ändern" aus
    /// der Vorschau): nur, was sich seitdem geaendert hat. Sonst setzte
    /// jeder Umweg ueber die Vorschau Wochenziel und Gewicht ein zweites
    /// Mal. `.beschwerden` steht immer darin -- ob dort etwas zu tun ist,
    /// sagt `beschwerdenAktion` selbst (nach dem Schreiben ist sie `.keine`).
    static func geaenderteVorgaenge(
        vorher: OnboardingAntworten, planVorher: PlanAntworten?,
        jetzt: OnboardingAntworten, planJetzt: PlanAntworten?
    ) -> [OnboardingSchreibvorgang] {
        OnboardingSchreibvorgang.allCases.filter { vorgang in
            switch vorgang {
            case .profil:
                vorher.geschlecht != jetzt.geschlecht || vorher.altersspanne != jetzt.altersspanne
                    || vorher.groesseCm != jetzt.groesseCm || vorher.richtung != jetzt.richtung
            case .messwert: vorher.gewichtKg != jetzt.gewichtKg
            case .wochenziel: vorher.tageProWoche != jetzt.tageProWoche
            case .zielgewicht: vorher.zielgewichtKg != jetzt.zielgewichtKg
            case .trainingsprofil: planVorher?.trainingsprofil != planJetzt?.trainingsprofil
            case .beschwerden: true
            }
        }
    }

    /// Ob "Später" nach einem Teilerfolg (`.teilweise(offen:)`) den Flow
    /// beendet, statt nur erneut zu versuchen.
    ///
    /// Steht `.profil` nicht mehr in `offen`, traegt der Server
    /// `onboardingDone` bereits -- ab da uebernimmt die Nachholkarte auf
    /// Home (Spec 5.2), und ein Vorgang, der dauerhaft scheitert, darf das
    /// Mitglied nicht im Onboarding festhalten. Steht `.profil` noch drin,
    /// ist nichts gespeichert: im Wurzel-Modus koennte sich das Gate gar
    /// nicht schliessen, also bleibt "Später" dort ein neuer Versuch.
    static func spaeterBeendet(offen: [OnboardingSchreibvorgang]) -> Bool {
        !offen.contains(.profil)
    }

    /// Ob es fuer diesen Vorgang ueberhaupt etwas zu schreiben gibt.
    ///
    /// `.profil` laeuft im Wurzel-Modus (`mitAbschluss == true`) immer --
    /// er setzt `onboardingDone`, auch bei leeren Antworten. Im
    /// Sheet-Modus gibt es kein Gate zu schliessen, also laeuft er nur mit
    /// einer eigenen Antwort: einem der vier Stammdatenfelder. Gewicht,
    /// Wochentage und Zielgewicht gehoeren zu den anderen drei Vorgaengen
    /// und zaehlen hier nicht mit.
    private static func hatAntwort(_ vorgang: OnboardingSchreibvorgang, antworten: OnboardingAntworten, plan: PlanAntworten?, mitAbschluss: Bool) -> Bool {
        switch vorgang {
        case .profil:
            mitAbschluss
                || antworten.geschlecht != nil || antworten.altersspanne != nil
                || antworten.groesseCm != nil || antworten.richtung != nil
        case .messwert: antworten.gewichtKg != nil
        case .wochenziel: antworten.tageProWoche != nil
        case .zielgewicht: antworten.zielgewichtKg != nil
        // Ohne Minuten und Erfahrung kein Aufruf: ein vorhandenes Profil
        // bliebe sonst nicht unberuehrt, und der Server lehnte ein halbes ab.
        case .trainingsprofil: plan?.trainingsprofil != nil
        case .beschwerden: plan.map { $0.beschwerdenAktion != .keine } ?? false
        }
    }

    /// Ob dieser Vorgang in diesem Versuch stattfinden soll.
    ///
    /// Erster Versuch (`offen == nil`): jeder Vorgang mit einer Antwort.
    /// Wiederholung (`offen` gesetzt): nur, wer darin steht -- `offen`
    /// benennt Schreibvorgaenge (R19), keine Screens, also keine
    /// Mehrdeutigkeit: ein erfolgreich geschriebenes Profil taucht in
    /// keinem spaeteren `offen` mehr auf (R18).
    private static func mussLaufen(_ vorgang: OnboardingSchreibvorgang, antworten: OnboardingAntworten, plan: PlanAntworten?, mitAbschluss: Bool, offen: [OnboardingSchreibvorgang]?) -> Bool {
        guard hatAntwort(vorgang, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss) else { return false }
        guard let offen else { return true }
        return offen.contains(vorgang)
    }

    /// `offen` fuer einen Fehler bei `fehlerBei`: dieser Vorgang selbst,
    /// plus alle spaeteren mit einer Antwort -- die wurden nie versucht,
    /// weil beim ersten Fehler abgebrochen wird. In Schreibreihenfolge.
    private static func offeneVorgaenge(abFehlerBei fehlerBei: OnboardingSchreibvorgang, antworten: OnboardingAntworten, plan: PlanAntworten?, mitAbschluss: Bool) -> [OnboardingSchreibvorgang] {
        OnboardingSchreibvorgang.allCases
            .drop { $0 != fehlerBei }
            .filter { hatAntwort($0, antworten: antworten, plan: plan, mitAbschluss: mitAbschluss) }
    }

    /// Das Ortsdatum des Geraets fuer den Gewichtseintrag -- das
    /// Onboarding fragt kein Datum ab, Schritt 2 traegt "heute" ein, wie
    /// die "Eintragen"-Aktion auf Home (Spec 5.3).
    private static func heute() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
