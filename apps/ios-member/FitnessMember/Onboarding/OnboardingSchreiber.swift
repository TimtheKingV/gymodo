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
}

extension APIClient: ProfilSchreibend {}

/// Die vier Schreibvorgaenge des Onboardings, in Sendereihenfolge.
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
    static func schreiben(
        _ antworten: OnboardingAntworten,
        mit client: some ProfilSchreibend,
        offen: [OnboardingSchreibvorgang]? = nil
    ) async -> OnboardingErgebnis {
        if mussLaufen(.profil, antworten: antworten, offen: offen) {
            let schreibvorgang = ProfilWrite(
                sex: antworten.geschlecht.map { .setzen($0.rawValue) },
                heightCm: antworten.groesseCm.map { .setzen($0) },
                ageBand: antworten.altersspanne.map { .setzen($0.rawValue) },
                trainingGoal: antworten.richtung.map { .setzen($0.rawValue) },
                onboardingDone: true
            )
            do {
                _ = try await client.updateProfile(schreibvorgang)
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .profil, antworten: antworten), fehler: error)
            }
        }

        if mussLaufen(.messwert, antworten: antworten, offen: offen) {
            do {
                _ = try await client.putMeasurement(MesswertWrite(measuredOn: heute(), weightKg: antworten.gewichtKg!))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .messwert, antworten: antworten), fehler: error)
            }
        }

        if mussLaufen(.wochenziel, antworten: antworten, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "weekly_days", targetValue: Double(antworten.tageProWoche!)))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .wochenziel, antworten: antworten), fehler: error)
            }
        }

        if mussLaufen(.zielgewicht, antworten: antworten, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "target_weight", targetValue: antworten.zielgewichtKg!))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .zielgewicht, antworten: antworten), fehler: error)
            }
        }

        return .fertig
    }

    /// Ob es fuer diesen Vorgang ueberhaupt etwas zu schreiben gibt.
    /// `.profil` laeuft immer -- er setzt `onboardingDone`, auch bei
    /// leeren Antworten. Die drei anderen nur, wenn ihr Feld gesetzt ist.
    private static func hatAntwort(_ vorgang: OnboardingSchreibvorgang, antworten: OnboardingAntworten) -> Bool {
        switch vorgang {
        case .profil: true
        case .messwert: antworten.gewichtKg != nil
        case .wochenziel: antworten.tageProWoche != nil
        case .zielgewicht: antworten.zielgewichtKg != nil
        }
    }

    /// Ob dieser Vorgang in diesem Versuch stattfinden soll.
    ///
    /// Erster Versuch (`offen == nil`): jeder Vorgang mit einer Antwort.
    /// Wiederholung (`offen` gesetzt): nur, wer darin steht -- `offen`
    /// benennt Schreibvorgaenge (R19), keine Screens, also keine
    /// Mehrdeutigkeit: ein erfolgreich geschriebenes Profil taucht in
    /// keinem spaeteren `offen` mehr auf (R18).
    private static func mussLaufen(_ vorgang: OnboardingSchreibvorgang, antworten: OnboardingAntworten, offen: [OnboardingSchreibvorgang]?) -> Bool {
        guard hatAntwort(vorgang, antworten: antworten) else { return false }
        guard let offen else { return true }
        return offen.contains(vorgang)
    }

    /// `offen` fuer einen Fehler bei `fehlerBei`: dieser Vorgang selbst,
    /// plus alle spaeteren mit einer Antwort -- die wurden nie versucht,
    /// weil beim ersten Fehler abgebrochen wird. In Schreibreihenfolge.
    private static func offeneVorgaenge(abFehlerBei fehlerBei: OnboardingSchreibvorgang, antworten: OnboardingAntworten) -> [OnboardingSchreibvorgang] {
        OnboardingSchreibvorgang.allCases
            .drop { $0 != fehlerBei }
            .filter { hatAntwort($0, antworten: antworten) }
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
