import Foundation

/// Die fuenf Onboarding-Screens (Spec 5.2) und die vier des Blocks "Dein
/// Trainingsplan" (Etappe 3, Entwuerfe 1.1-1.4). Die Reihenfolge der Faelle
/// ist die Reihenfolge im Flow -- `schritte(umfang:hatStudio:ergaenzt:)`
/// sortiert danach.
enum OnboardingSchritt: Hashable, CaseIterable {
    case ueberDich, koerper, ziel, wieOft, zielgewicht
    case planZeit, planSchwerpunkt, planBeschwerden, planVorschau

    var gehoertZumPlan: Bool {
        switch self {
        case .planZeit, .planSchwerpunkt, .planBeschwerden, .planVorschau: true
        default: false
        }
    }
}

/// Welcher Teil des Onboardings laeuft.
///
/// - `komplett`: Wurzel-Gate und Nachholkarte -- die Bestandsschritte und
///   danach der Plan-Block.
/// - `nurPlan`: die Home-Karte 1.5 ohne Trainingsprofil -- nur der Block.
/// - `nurVorschau`: Home-Karte mit Profil, spaeter das Anfaengerangebot
///   (Task 11) -- nur 1.4, ohne Schrittzeile.
/// - `nurBeschwerden`: die Zeile "Beschwerden" im Profil -- nur 1.3, damit
///   der Satz "Widerruf jederzeit im Profil" stimmt. Schreibt nur die
///   Beschwerden (`OnboardingSchreiber.vorgaenge(umfang:)`), keinen Plan.
enum OnboardingUmfang: Equatable {
    case komplett, nurPlan, nurVorschau, nurBeschwerden
}

/// "Schritt n von m" -- gezaehlt wird, was der Flow wirklich zeigt; bei nur
/// einem Schritt gibt es nichts zu zaehlen und keine Zeile.
enum OnboardingSchrittzeile {
    static func text(nummer: Int, gesamt: Int) -> String? {
        guard gesamt > 1 else { return nil }
        return "Schritt \(min(nummer, gesamt)) von \(gesamt)"
    }
}

/// Die Antworten des Onboardings -- ein reiner Wertetyp. "Spaeter" auf
/// einem Screen darf die Antworten der anderen Screens nicht zuruecksetzen;
/// mit lauter optionalen Feldern in einem Wertetyp passiert das von selbst,
/// ohne einen eigenen Reset-Pfad, den man vergessen koennte.
struct OnboardingAntworten: Equatable {
    /// Der Vorschlag, den Schritt 4 zeigt, bevor er bestaetigt oder
    /// geaendert wurde (`antworten.tageProWoche ?? tageVorgabe`, Aufgabe 7).
    /// KEIN Startwert von `tageProWoche` selbst: eine unveraenderte Vorgabe
    /// ist keine Antwort (siehe `istLeer`) -- sonst schriebe "fuenfmal
    /// Spaeter" ein Wochenziel, das niemand gewaehlt hat.
    static let tageVorgabe = 3

    var geschlecht: Geschlecht?
    var altersspanne: Altersspanne?
    var groesseCm: Int?
    var gewichtKg: Double?
    var richtung: Trainingsrichtung?
    var tageProWoche: Int?
    var zielgewichtKg: Double?

    /// Die Screens, die der Flow zeigt -- Schritt 5 (Zielgewicht) entfaellt
    /// ohne ein Gewicht aus Schritt 2 (Spec 5.2, Zeile 5: "nur wenn Schritt 2
    /// ein Gewicht hat, sonst uebersprungen").
    var schritte: [OnboardingSchritt] {
        var schritte: [OnboardingSchritt] = [.ueberDich, .koerper, .ziel, .wieOft]
        if gewichtKg != nil { schritte.append(.zielgewicht) }
        return schritte
    }

    /// Die Screens mit dem Plan-Block (Etappe 3).
    ///
    /// Die Vorschau (1.4) braucht ein Studio -- ein Plan gehoert einem
    /// Studio (F20), und im Wurzel-Gate ist ein neues Mitglied meist noch in
    /// keinem. Ohne Studio endet der Flow deshalb nach den Beschwerden.
    ///
    /// `ergaenzt`: Schritte, die ein Sonderfall nachtraeglich braucht
    /// ("Ergänzen" bei fehlenden Angaben, "Beschwerden ändern", "Zeit oder
    /// Schwerpunkt ändern" aus der reinen Vorschau). Sie reihen sich in die
    /// feste Reihenfolge ein, nichts steht doppelt.
    func schritte(umfang: OnboardingUmfang, hatStudio: Bool, ergaenzt: [OnboardingSchritt] = []) -> [OnboardingSchritt] {
        var basis: [OnboardingSchritt]
        switch umfang {
        case .komplett: basis = schritte + [.planZeit, .planSchwerpunkt, .planBeschwerden]
        case .nurPlan: basis = [.planZeit, .planSchwerpunkt, .planBeschwerden]
        case .nurVorschau: basis = []
        case .nurBeschwerden: basis = [.planBeschwerden]
        }
        if (hatStudio && umfang != .nurBeschwerden) || umfang == .nurVorschau { basis.append(.planVorschau) }
        // Zielgewicht nur mit Gewicht, auch als Ergaenzung (Spec 5.2).
        let zusatz = ergaenzt.filter { $0 != .zielgewicht || gewichtKg != nil }
        let alle = Set(basis).union(zusatz)
        return OnboardingSchritt.allCases.filter(alle.contains)
    }

    /// Wahr, wenn wirklich nichts beantwortet wurde -- nicht, wenn nur die
    /// Vorgabe fuer Schritt 4 stehen geblieben ist (R16): die Vorgabe lebt
    /// ausserhalb dieses Typs, `tageProWoche` ist `nil`, bis Schritt 4
    /// bestaetigt oder geaendert wurde.
    var istLeer: Bool {
        geschlecht == nil && altersspanne == nil && groesseCm == nil
            && gewichtKg == nil && richtung == nil && tageProWoche == nil
            && zielgewichtKg == nil
    }
}
