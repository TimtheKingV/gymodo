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

    // MARK: - Der Tag-Tipp (Testnotiz 19. September, Eintrag 8)

    /// Der Fund: in „Angemeldet“ zeigt das Band alle eigenen Anmeldungen,
    /// egal welcher Tag gewaehlt ist. Ein Tipp auf einen Tag ohne eigenen
    /// Platz liess das Band stehen -- und es sah aus, als faende dieser
    /// Kurs an diesem Tag statt.
    @Test func einTagOhneEigenenPlatzSchaltetAufAlleKurse() {
        #expect(KurseAnsicht.nachTagwahl(bisher: .angemeldet, indikator: .kurse) == .alle)
        #expect(KurseAnsicht.nachTagwahl(bisher: .angemeldet, indikator: .keiner) == .alle)
    }

    /// Ein Tag MIT eigenem Platz laesst die Haelfte stehen: was man
    /// angetippt hat, steht dort schon.
    @Test func einTagMitEigenemPlatzLaesstAngemeldetStehen() {
        #expect(KurseAnsicht.nachTagwahl(bisher: .angemeldet, indikator: .angemeldet) == .angemeldet)
    }

    /// Aus „Alle Kurse“ heraus aendert ein Tipp nie etwas -- dort filtert
    /// der Kalender bereits, und ein Sprung nach „Angemeldet“ waere genau
    /// die Verwirrung, die dieser Fall beheben soll, nur andersherum.
    @Test func ausAlleKurseHerausAendertEinTagNichts() {
        for indikator: KurseTagesindikator in [.keiner, .kurse, .angemeldet] {
            #expect(KurseAnsicht.nachTagwahl(bisher: .alle, indikator: indikator) == .alle)
        }
    }

    /// Der Grund, warum der Screen das Ergebnis nur bei einer echten
    /// Aenderung schreibt: `nil` in `gewaehlteAnsicht` heisst "hat den
    /// Umschalter noch nie angefasst", und `geltend` macht daraus
    /// `.angemeldet`, sobald es Anmeldungen gibt. Wuerde jeder Tag-Tipp
    /// das Ergebnis blind zurueckschreiben, haette sich ein Mitglied ohne
    /// Anmeldungen mit einem Tag-Tipp stillschweigend auf `.alle`
    /// festgelegt -- und faende nach seiner ersten Buchung den Wochenplan
    /// statt seiner Anmeldungen vor.
    ///
    /// Die Funktion gibt in diesen Faellen `bisher` unveraendert zurueck;
    /// dass daraus kein Schreibvorgang wird, entscheidet der Screen.
    @Test func inDenNichtstunFaellenKommtDieAusgangsansichtUnveraendertZurueck() {
        #expect(KurseAnsicht.nachTagwahl(bisher: .alle, indikator: .kurse) == .alle)
        #expect(
            KurseAnsicht.nachTagwahl(bisher: .angemeldet, indikator: .angemeldet) == .angemeldet)
    }
}

/// Die Rueckfrage vor dem Abmelden (Testnotiz 19. September, Eintrag 9).
///
/// Geprueft wird hier nur, dass die beiden Faelle verschiedene Saetze
/// bekommen und der Kursname im Titel steht -- beides ist der Grund,
/// warum die Texte ueberhaupt aus dem View heraus an eine gemeinsame
/// Stelle gewandert sind.
struct KurseAbmeldefrageTests {
    @Test func derTitelNenntDenKurs() {
        #expect(
            KurseAbmeldefrage.titel(kursname: "Rückenfit", istWarteliste: false)
                == "Von Rückenfit abmelden?")
        #expect(
            KurseAbmeldefrage.titel(kursname: "Rückenfit", istWarteliste: true)
                == "Warteliste für Rückenfit verlassen?")
    }

    /// Ein bestaetigter Platz geht an den Naechsten -- das ist die Folge,
    /// die man vor dem Tippen wissen will. Ein Wartelistenplatz kostet nur
    /// die Position; derselbe Satz waere dort eine Drohung ohne Deckung.
    @Test func beideFaelleSagenVerschiedenesUndKeinerDrohtOhneDeckung() {
        let platz = KurseAbmeldefrage.erklaerung(istWarteliste: false)
        let warteliste = KurseAbmeldefrage.erklaerung(istWarteliste: true)

        #expect(platz != warteliste)
        #expect(platz.contains("Nächsten"))
        #expect(warteliste.contains("Warteliste"))
        #expect(!warteliste.contains("Nächsten"))
    }
}
