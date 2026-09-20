import Foundation

/// Die Rueckfrage vor dem Abmelden -- Titel und Erklaerung, an EINER
/// Stelle.
///
/// Bis zur Testsitzung vom 19. September (Eintrag 9) meldete ein Tipp auf
/// "Abmelden" sofort ab. Der Knopf steht im Band direkt neben der Karte
/// und im Detail als Hauptaktion; ein Fehlgriff kostete den Platz, und
/// zurueck geht es nur ueber eine neue Anmeldung -- die ins Leere laeuft,
/// wenn der Kurs inzwischen voll ist. Eine Rueckfrage ist hier kein
/// Misstrauen gegen den Tipp, sondern die einzige Umkehr, die es gibt.
///
/// **Zwei Faelle, zwei Saetze.** Ein bestaetigter Platz geht an den
/// Naechsten -- das ist die Folge, die man vorher wissen will. Ein
/// Wartelistenplatz kostet nur die Position; ihn mit demselben Satz zu
/// bewarnen waere eine Drohung ohne Deckung.
///
/// Warum die Texte hier und nicht in den beiden Views: sie sind in Band
/// und Detail wortgleich, und zwei Kopien laufen frueher oder spaeter
/// auseinander -- dann warnt die eine Stelle vor etwas, das die andere
/// verschweigt. Getrennt vom View, damit sie ohne SwiftUI pruefbar sind
/// (wie `KurseWochenInhalt`).
enum KurseAbmeldefrage {
    /// "Von Rückenfit abmelden?" bzw. "Warteliste für Rückenfit
    /// verlassen?" -- der Kursname steht darin, weil im Band mehrere
    /// Karten uebereinander liegen und der Dialog sagen muss, welche
    /// gemeint ist.
    static func titel(kursname: String, istWarteliste: Bool) -> String {
        istWarteliste
            ? "Warteliste für \(kursname) verlassen?"
            : "Von \(kursname) abmelden?"
    }

    /// Was danach gilt -- keine Ermahnung, keine Ruecknahme-Bitte
    /// (designsystem.md SS5: was falsch ist und was gilt).
    static func erklaerung(istWarteliste: Bool) -> String {
        istWarteliste
            ? "Deine Position auf der Warteliste ist danach weg. Du kannst dich neu eintragen, stehst dann aber hinten an."
            : "Dein Platz geht an den Nächsten. Ob du ihn zurückbekommst, hängt davon ab, ob der Kurs dann noch frei ist."
    }

}

// Die Beschriftung der bestaetigenden Taste steht bewusst NICHT hier: sie
// muss dasselbe Wort tragen wie der Knopf, der den Dialog geoeffnet hat,
// und die beiden Knoepfe heissen verschieden. Im Band steht immer
// "Abmelden", im Detail unterscheidet `KursDetailHauptaktion.titel`
// zwischen "Abmelden" und "Warteliste verlassen". Eine Ableitung aus
// `istWarteliste` waere an einer der beiden Stellen falsch -- und ein
// Dialog, der die Tat anders nennt als der Knopf davor, laesst zweifeln,
// ob er noch von derselben spricht. Jede Stelle reicht ihre eigene
// Beschriftung durch.
