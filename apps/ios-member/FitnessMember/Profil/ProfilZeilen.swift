import Foundation

/// Die reinen Ableitungen der zwei neuen Profil-Abschnitte ("ÜBER DICH",
/// "ZIELE", Aufgabe 10) -- getrennt von den Views, damit sie ohne SwiftUI
/// pruefbar bleiben (wie `HomeZeilen`/`HomeZiele`).
enum ProfilZeilen {
    /// "—" ohne Angabe -- UND bei einem Rohwert, den dieser Client nicht
    /// kennt (ein neuerer Server hat einen Enum-Wert ergaenzt): ein
    /// unbekannter Wert ist fuer diesen Screen dieselbe Leerstelle wie
    /// keine Angabe, nie ein Absturz.
    static let keineAngabe = "—"

    static func geschlechtText(_ sex: String?) -> String {
        guard let sex, let wert = Geschlecht(rawValue: sex) else { return keineAngabe }
        return wert.wort
    }

    static func altersspanneText(_ ageBand: String?) -> String {
        guard let ageBand, let wert = Altersspanne(rawValue: ageBand) else { return keineAngabe }
        return wert.wort
    }

    static func groesseText(_ heightCm: Int?) -> String {
        guard let heightCm else { return keineAngabe }
        return "\(heightCm) cm"
    }

    static func richtungText(_ trainingGoal: String?) -> String {
        guard let trainingGoal, let wert = Trainingsrichtung(rawValue: trainingGoal) else { return keineAngabe }
        return wert.wort
    }

    /// "3" -- ohne "Tage" dahinter, wie `Profil.dc.html`s
    /// `profil_zeile(u'Tage pro Woche', u'3')`.
    static func tageProWocheText(_ ziel: Ziel?) -> String {
        guard let ziel else { return keineAngabe }
        return "\(Int(ziel.targetValue))"
    }

    static func zielgewichtText(_ ziel: Ziel?) -> String {
        guard let ziel else { return keineAngabe }
        return Zahlformat.gewichtMitEinheit(ziel.targetValue)
    }

    /// "82,5 kg · gestern" -- die "Gewichtsverlauf"-Zeile im Profil, mit
    /// derselben Ortstag-Rechnung wie `HomeZeilen.tageHerVonTag` (Task 8,
    /// R26: der Messtag gehoert dem Geraet, nicht UTC). `nil` ohne
    /// Messwerte -- keine Angabe statt eines erfundenen "—" neben einem
    /// Chevron, der ohnehin zum (dann leeren) Verlauf fuehrt.
    static func gewichtsverlaufDetailText(
        _ letzterMesswert: Messwert?, jetzt: Date, zeitzone: TimeZone = .current
    ) -> String? {
        guard let letzterMesswert,
              let tage = HomeZeilen.tageHerVonTag(letzterMesswert.measuredOn, jetzt: jetzt, zeitzone: zeitzone)
        else { return nil }
        return "\(Zahlformat.gewichtMitEinheit(letzterMesswert.weightKg)) · \(HomeZeilen.tageHerText(tage))"
    }

    // MARK: - Vorgaben fuer ZielSheet (Ruling: Tage 3, Zielgewicht aktiv > letzter Messwert > 75,0)

    /// Die Vorgabe fuer `ZielSheet(.tageProWoche)`: der Wert des aktiven
    /// Ziels, sonst 3 -- wie `OnboardingAntworten.tageVorgabe`.
    static func tageProWocheVorgabe(aktiv: Ziel?) -> Int {
        aktiv.map { Int($0.targetValue) } ?? 3
    }

    /// Die Vorgabe fuer `ZielSheet(.zielgewicht)`: der Wert des aktiven
    /// Ziels, sonst der letzte eingetragene Messwert, sonst 75,0 -- wie
    /// `KoerperSchritt.gewichtswerte`s Startwert im Onboarding.
    static func zielgewichtVorgabe(aktiv: Ziel?, letzterMesswert: Messwert?) -> Double {
        aktiv?.targetValue ?? letzterMesswert?.weightKg ?? 75.0
    }
}
