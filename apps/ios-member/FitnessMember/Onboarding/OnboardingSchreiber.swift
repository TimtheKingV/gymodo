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

/// Das Ergebnis eines Schreibversuchs -- `offen` traegt genug, um einen
/// Wiederholungsversuch auf genau das zu beschraenken, was noch fehlt.
enum OnboardingErgebnis: Equatable {
    case fertig
    case teilweise(offen: [OnboardingSchritt], fehler: APIError)
}

/// Ordnet die Schreibvorgaenge des Onboardings -- eine `enum` mit einer
/// statischen Funktion, kein Store: sie haelt keinen Zustand, der
/// Aufrufer reicht `offen` selbst von einem Versuch zum naechsten weiter.
///
/// Profil zuerst, weil `onboardingDone` das Gate schliesst -- scheitern
/// die Ziele danach, oeffnet sich das Gate nicht mehr, aber Home zeigt die
/// Nachholkarte, und die traegt dieselben Antworten (Spec 5.2).
enum OnboardingSchreiber {
    /// Die vier Schreibvorgaenge in Sendereihenfolge. `.profil` deckt drei
    /// Screens auf einmal ab (ueberDich, die Groesse aus koerper, ziel) --
    /// ein einzelnes `PUT /me/profile`, kein Screen fuer sich.
    private enum Aufruf: Int, CaseIterable {
        case profil, messung, wochenziel, zielgewicht
    }

    static func schreiben(
        _ antworten: OnboardingAntworten,
        mit client: some ProfilSchreibend,
        offen: [OnboardingSchritt]? = nil
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
                return .teilweise(offen: offeneSchritte(abFehlerBei: .profil, antworten: antworten), fehler: error)
            }
        }

        if mussLaufen(.messung, antworten: antworten, offen: offen) {
            do {
                _ = try await client.putMeasurement(MesswertWrite(measuredOn: heute(), weightKg: antworten.gewichtKg!))
            } catch {
                return .teilweise(offen: offeneSchritte(abFehlerBei: .messung, antworten: antworten), fehler: error)
            }
        }

        if mussLaufen(.wochenziel, antworten: antworten, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "weekly_days", targetValue: Double(antworten.tageProWoche!)))
            } catch {
                return .teilweise(offen: offeneSchritte(abFehlerBei: .wochenziel, antworten: antworten), fehler: error)
            }
        }

        if mussLaufen(.zielgewicht, antworten: antworten, offen: offen) {
            do {
                _ = try await client.setGoal(ZielWrite(kind: "target_weight", targetValue: antworten.zielgewichtKg!))
            } catch {
                return .teilweise(offen: offeneSchritte(abFehlerBei: .zielgewicht, antworten: antworten), fehler: error)
            }
        }

        return .fertig
    }

    /// Ob dieser Aufruf in diesem Versuch stattfinden soll.
    ///
    /// Erster Versuch (`offen == nil`): das Profil laeuft immer -- es
    /// setzt `onboardingDone`, auch bei leeren Antworten. Die drei
    /// anderen laufen nur, wenn es dafuer etwas zu schreiben gibt.
    ///
    /// Wiederholung (`offen` gesetzt): `.koerper` ist zweideutig -- es
    /// steht sowohl fuer die Groesse (Teil des Profils) als auch fuer das
    /// Gewicht (die Messung). Ein erfolgreich geschriebenes Profil darf
    /// dadurch kein zweites Mal laufen (R18, kein zweites
    /// `onboardingDone`); `.koerper` zaehlt fuer das Profil deshalb nur,
    /// wenn gar kein Gewicht ansteht -- dann kann `.koerper` nur von der
    /// Groesse stammen, nie von einer Messung, die es nicht gibt.
    private static func mussLaufen(_ aufruf: Aufruf, antworten: OnboardingAntworten, offen: [OnboardingSchritt]?) -> Bool {
        switch aufruf {
        case .profil:
            guard let offen else { return true }
            return offen.contains(.ueberDich) || offen.contains(.ziel)
                || (offen.contains(.koerper) && antworten.gewichtKg == nil)
        case .messung:
            guard antworten.gewichtKg != nil else { return false }
            guard let offen else { return true }
            return offen.contains(.koerper)
        case .wochenziel:
            guard antworten.tageProWoche != nil else { return false }
            guard let offen else { return true }
            return offen.contains(.wieOft)
        case .zielgewicht:
            guard antworten.zielgewichtKg != nil else { return false }
            guard let offen else { return true }
            return offen.contains(.zielgewicht)
        }
    }

    /// Die Schritte, die der jeweilige Aufruf beantwortet -- leer, wenn er
    /// mangels Antwort gar nicht laeuft. Das Profil faellt auf `.ueberDich`
    /// als alleinigen Platzhalter zurueck, wenn keins seiner drei Felder
    /// etwas zu sagen hat: der Aufruf findet trotzdem statt (wegen
    /// `onboardingDone`) und braucht bei einem Fehler eine gemeldete Stelle.
    private static func schritte(fuer aufruf: Aufruf, antworten: OnboardingAntworten) -> [OnboardingSchritt] {
        switch aufruf {
        case .profil:
            var schritte: [OnboardingSchritt] = []
            if antworten.geschlecht != nil || antworten.altersspanne != nil { schritte.append(.ueberDich) }
            if antworten.groesseCm != nil { schritte.append(.koerper) }
            if antworten.richtung != nil { schritte.append(.ziel) }
            return schritte.isEmpty ? [.ueberDich] : schritte
        case .messung:
            return antworten.gewichtKg != nil ? [.koerper] : []
        case .wochenziel:
            return antworten.tageProWoche != nil ? [.wieOft] : []
        case .zielgewicht:
            return antworten.zielgewichtKg != nil ? [.zielgewicht] : []
        }
    }

    /// `offen` fuer einen Fehler bei `fehlerBei`: dessen eigene Schritte,
    /// plus die aller spaeteren Aufrufe -- die wurden ja nie versucht,
    /// weil beim ersten Fehler abgebrochen wird. In Schreibreihenfolge,
    /// ohne Dopplung (siehe `schritte(fuer:)`, `.koerper` kann zweimal
    /// auftauchen).
    private static func offeneSchritte(abFehlerBei fehlerBei: Aufruf, antworten: OnboardingAntworten) -> [OnboardingSchritt] {
        var ergebnis: [OnboardingSchritt] = []
        for aufruf in Aufruf.allCases where aufruf.rawValue >= fehlerBei.rawValue {
            for schritt in schritte(fuer: aufruf, antworten: antworten) where !ergebnis.contains(schritt) {
                ergebnis.append(schritt)
            }
        }
        return ergebnis
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
