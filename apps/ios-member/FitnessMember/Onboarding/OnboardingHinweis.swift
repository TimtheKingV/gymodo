import Foundation

/// Der Bannertext nach einem gescheiterten Schreibversuch (R22) -- eine
/// reine Funktion aus `offen` und dem Fehler, damit sie ohne View testbar
/// ist, wie `OnboardingSchreiber` selbst.
///
/// Zwei Faelle, weil `.profil` immer zuerst laeuft (siehe
/// `OnboardingSchreiber`): steht es noch in `offen`, ist NICHTS
/// gespeichert -- auch nicht die Antworten aus Schritt 1. Ist es
/// verschwunden, hat der Server das Profil bereits, und der Satz nennt nur
/// noch das, was danach scheiterte. designsystem.md SS5/SS10: nie
/// "fehlgeschlagen", kein Ausrufezeichen, offline heisst "gespeichert,
/// wird gesendet" bzw. hier "bleibt hier stehen" -- nie "Verbindung
/// fehlgeschlagen".
enum OnboardingHinweis {
    static func hinweis(offen: [OnboardingSchreibvorgang], fehler: APIError) -> String {
        guard !offen.contains(.profil) else {
            // `fehler.servertext` liefert fuer .offline bereits woertlich
            // "Keine Verbindung." -- ein zweiter Fall dafuer waere eine
            // zweite Abschrift desselben Satzes.
            return "\(fehler.servertext) Noch nichts gespeichert — deine Angaben bleiben hier stehen."
        }

        let liste = aufzaehlung(offen.compactMap(name))
        let grund = fehler == .offline ? "keine Verbindung" : fehler.servertext
        // `grund` traegt bei .offline keinen eigenen Punkt, `servertext`
        // dagegen schon (siehe APIError.servertext) -- ohne diese
        // Fallunterscheidung staende am Satzende entweder gar kein Punkt
        // oder einer zu viel.
        let satzende = grund.hasSuffix(".") ? grund : "\(grund)."
        return "Dein Profil ist gespeichert. \(liste) noch nicht — \(satzende)"
    }

    /// Der deutsche Name, wie ihn das Mitglied im Profil wiederfindet --
    /// `.profil` selbst taucht hier nie auf: dieser Zweig laeuft nur, wenn
    /// es schon geschrieben ist.
    private static func name(_ vorgang: OnboardingSchreibvorgang) -> String? {
        switch vorgang {
        case .profil: nil
        case .messwert: "Gewicht"
        case .wochenziel: "Wochenziel"
        case .zielgewicht: "Zielgewicht"
        }
    }

    /// "Gewicht" · "Gewicht und Wochenziel" · "Gewicht, Wochenziel und
    /// Zielgewicht" -- die uebliche deutsche Aufzaehlung, Komma zwischen
    /// allen bis auf die letzten zwei, die ein "und" verbindet.
    private static func aufzaehlung(_ teile: [String]) -> String {
        guard let erstes = teile.first else { return "" }
        guard teile.count > 1 else { return erstes }
        return teile.dropLast().joined(separator: ", ") + " und " + teile.last!
    }
}
