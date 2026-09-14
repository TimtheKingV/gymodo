import Foundation
import Testing
@testable import FitnessMember

/// Die Umschaltung zwischen „Angemeldet“ und „Alle Kurse“ auf dem
/// Kurse-Screen. Eine reine Ableitung aus zwei Angaben -- was das Mitglied
/// zuletzt angetippt hat (oder nichts) und ob es ueberhaupt eine offene
/// eigene Anmeldung gibt -- und genau deshalb hier ohne UI pruefbar.
///
/// Die drei tragenden Faelle stehen unten einzeln: die Vorauswahl, das
/// Stehenbleiben einer getroffenen Wahl, und der Rueckfall, wenn die
/// letzte Anmeldung waehrend der Anzeige wegfaellt.
struct KurseAnsichtTests {
    /// Ohne eine einzige Anmeldung gibt es keinen Umschalter -- und damit
    /// auch nichts zu waehlen. Der Screen zeigt direkt den Wochenplan.
    @Test func ohneAnmeldungenGiltAlleKurse() {
        #expect(KurseAnsicht.geltend(gewaehlt: nil, hatAnmeldungen: false) == .alle)
    }

    /// Bin ich irgendwo angemeldet, ist das die haeufigste Frage an diesen
    /// Screen -- also steht sie vorn, ohne dass jemand tippen muss.
    @Test func mitAnmeldungenStehtAngemeldetVorn() {
        #expect(KurseAnsicht.geltend(gewaehlt: nil, hatAnmeldungen: true) == .angemeldet)
    }

    /// Eine getippte Wahl schlaegt die Vorauswahl. Ohne das spraenge der
    /// Screen bei jedem Neuzeichnen (60-Sekunden-Tick, Tageswechsel im
    /// Kalender) auf „Angemeldet“ zurueck, waehrend jemand den Wochenplan
    /// liest.
    @Test func eineGetippteWahlBleibtStehen() {
        #expect(KurseAnsicht.geltend(gewaehlt: .alle, hatAnmeldungen: true) == .alle)
    }

    /// Der Rueckfall: meldet sich jemand vom letzten Kurs ab, waehrend
    /// „Angemeldet“ offen steht, verschwindet der Umschalter. Bliebe die
    /// Wahl trotzdem gelten, zeigte der Screen eine leere Liste ohne jeden
    /// Weg zurueck -- die Haelfte, die man antippen muesste, gibt es dann
    /// naemlich nicht mehr.
    @Test func faelltDieLetzteAnmeldungWegGiltWiederAlleKurse() {
        #expect(KurseAnsicht.geltend(gewaehlt: .angemeldet, hatAnmeldungen: false) == .alle)
    }

    /// Der Umschalter haengt an derselben einen Angabe wie die Ableitung
    /// darueber -- zwei getrennte Bedingungen koennten auseinanderlaufen
    /// und einen Umschalter zeigen, dessen linke Haelfte leer ist.
    @Test func derUmschalterHaengtAnDenAnmeldungen() {
        #expect(KurseAnsicht.zeigtUmschalter(hatAnmeldungen: true))
        #expect(!KurseAnsicht.zeigtUmschalter(hatAnmeldungen: false))
    }

    /// Die Beschriftung steht am Typ, nicht im View: sie ist zugleich das,
    /// was VoiceOver vorliest, und taucht in beiden Haelften auf.
    @Test func beideHaelftenTragenIhreBeschriftung() {
        #expect(KurseAnsicht.angemeldet.titel == "Angemeldet")
        #expect(KurseAnsicht.alle.titel == "Alle Kurse")
    }
}
