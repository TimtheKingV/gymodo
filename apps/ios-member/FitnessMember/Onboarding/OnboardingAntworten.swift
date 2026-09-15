import Foundation

/// Die fuenf Onboarding-Screens (Spec 5.2). Dient zugleich als Schluessel
/// fuer "was ist nach einem gescheiterten Schreibvorgang noch offen"
/// (`OnboardingErgebnis.teilweise`, siehe OnboardingSchreiber).
enum OnboardingSchritt: Equatable {
    case ueberDich, koerper, ziel, wieOft, zielgewicht
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
