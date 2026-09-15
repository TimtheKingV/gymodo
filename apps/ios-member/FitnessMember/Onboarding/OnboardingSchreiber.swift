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
    /// `mitAbschluss` unterscheidet die zwei Laeufe desselben Flows (R21):
    /// als Wurzel-Gate (Vorgabe `true`) setzt das Profil-PUT
    /// `onboardingDone`, und laeuft deshalb immer mit, auch bei leeren
    /// Antworten -- irgendetwas muss das Gate schliessen. Als Sheet
    /// (Nachholkarte auf Home, Aufgabe 8) ist das Onboarding auf dem
    /// Server bereits abgeschlossen: ein zweites `onboardingDone` gaebe es
    /// nicht, und das Profil-PUT liefe nur noch fuer eigene Antworten mit.
    static func schreiben(
        _ antworten: OnboardingAntworten,
        mit client: some ProfilSchreibend,
        mitAbschluss: Bool = true,
        offen: [OnboardingSchreibvorgang]? = nil
    ) async -> OnboardingErgebnis {
        if mussLaufen(.profil, antworten: antworten, mitAbschluss: mitAbschluss, offen: offen) {
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
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .profil, antworten: antworten, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.messwert, antworten: antworten, mitAbschluss: mitAbschluss, offen: offen) {
            do {
                _ = try await client.putMeasurement(MesswertWrite(measuredOn: heute(), weightKg: antworten.gewichtKg!))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .messwert, antworten: antworten, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.wochenziel, antworten: antworten, mitAbschluss: mitAbschluss, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "weekly_days", targetValue: Double(antworten.tageProWoche!)))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .wochenziel, antworten: antworten, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        if mussLaufen(.zielgewicht, antworten: antworten, mitAbschluss: mitAbschluss, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "target_weight", targetValue: antworten.zielgewichtKg!))
            } catch {
                return .teilweise(offen: offeneVorgaenge(abFehlerBei: .zielgewicht, antworten: antworten, mitAbschluss: mitAbschluss), fehler: error)
            }
        }

        return .fertig
    }

    /// Ob es fuer diesen Vorgang ueberhaupt etwas zu schreiben gibt.
    ///
    /// `.profil` laeuft im Wurzel-Modus (`mitAbschluss == true`) immer --
    /// er setzt `onboardingDone`, auch bei leeren Antworten. Im
    /// Sheet-Modus gibt es kein Gate zu schliessen, also laeuft er nur mit
    /// einer eigenen Antwort: einem der vier Stammdatenfelder. Gewicht,
    /// Wochentage und Zielgewicht gehoeren zu den anderen drei Vorgaengen
    /// und zaehlen hier nicht mit.
    private static func hatAntwort(_ vorgang: OnboardingSchreibvorgang, antworten: OnboardingAntworten, mitAbschluss: Bool) -> Bool {
        switch vorgang {
        case .profil:
            mitAbschluss
                || antworten.geschlecht != nil || antworten.altersspanne != nil
                || antworten.groesseCm != nil || antworten.richtung != nil
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
    private static func mussLaufen(_ vorgang: OnboardingSchreibvorgang, antworten: OnboardingAntworten, mitAbschluss: Bool, offen: [OnboardingSchreibvorgang]?) -> Bool {
        guard hatAntwort(vorgang, antworten: antworten, mitAbschluss: mitAbschluss) else { return false }
        guard let offen else { return true }
        return offen.contains(vorgang)
    }

    /// `offen` fuer einen Fehler bei `fehlerBei`: dieser Vorgang selbst,
    /// plus alle spaeteren mit einer Antwort -- die wurden nie versucht,
    /// weil beim ersten Fehler abgebrochen wird. In Schreibreihenfolge.
    private static func offeneVorgaenge(abFehlerBei fehlerBei: OnboardingSchreibvorgang, antworten: OnboardingAntworten, mitAbschluss: Bool) -> [OnboardingSchreibvorgang] {
        OnboardingSchreibvorgang.allCases
            .drop { $0 != fehlerBei }
            .filter { hatAntwort($0, antworten: antworten, mitAbschluss: mitAbschluss) }
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
