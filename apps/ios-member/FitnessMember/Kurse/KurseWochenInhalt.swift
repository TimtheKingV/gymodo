import Foundation

/// Die beiden Texte, die der zusammengelegte Kurse-Screen neu braucht --
/// als reine Ableitungen, damit `KurseWochenInhaltTests` sie ohne UI
/// pruefen kann (dieselbe Aufteilung wie bei `KursDetailInhalt`).
enum KurseWochenInhalt {
    /// Die Ueberschrift ueber der Tagesliste.
    ///
    /// Sie trug frueher nur den Wochentag ("Heute · Donnerstag"), weil
    /// darueber eine Wochenleiste mit Datumsspanne stand. Die ist weg --
    /// gewischt wird jetzt auf den Tagesboxen selbst. Damit war der Monat
    /// nirgends mehr zu lesen, und nach zwei Wischern standen nur noch
    /// nackte Tagesnummern da. Deshalb steht das ausgeschriebene Datum
    /// jetzt hier.
    ///
    /// Format ueber `KursZeit.datumAusgeschrieben` ("ccc, d. MMMM"),
    /// nicht ueber ein eigenes: der Monatsname muss ausgeschrieben sein,
    /// weil die Zeile in Versalien gesetzt wird und "SEP." dort wie eine
    /// Abkuerzung fuer etwas anderes aussieht.
    static func tagesueberschrift(_ tag: KurseWochentag, zeitzone: String) -> String {
        let datum = KursZeit.datumAusgeschrieben(tag.datum, zeitzone: zeitzone)
        return tag.istHeute ? "Heute · \(datum)" : datum
    }

    /// Der Abmeldehinweis unter einer eigenen Anmeldung im Band.
    ///
    /// Fuer den bestaetigten Platz woertlich derselbe Satz wie im
    /// Kursdetail (`KursDetailInhalt.fusstext`) -- eine zweite Formulierung
    /// fuer dieselbe Frist waere zwei Wahrheiten ueber denselben Termin.
    ///
    /// Die Warteliste bekommt einen eigenen Satz, und der ist der Grund,
    /// warum diese Ableitung ueberhaupt existiert: fuer sie gilt die Frist
    /// NICHT. `0036_kurse_platzvergabe.sql` sagt es ausdruecklich -- die
    /// Stornofrist "trifft nur das Mitglied selbst, nur einen bestaetigten
    /// Platz und nur einen Termin, der stattfindet". Eine Uhrzeit zu
    /// nennen, bis zu der man von der Warteliste muesste, waere eine
    /// Falschaussage im Klartext.
    static func abmeldehinweis(
        fuer zustand: KursZustand, abmeldenBisUhrzeit: String?, abmeldefristVerstrichen: Bool
    ) -> String? {
        switch zustand {
        case .angemeldet:
            return KursDetailInhalt.fusstext(
                fuer: .angemeldet, abmeldenBisUhrzeit: abmeldenBisUhrzeit,
                abmeldefristVerstrichen: abmeldefristVerstrichen,
                wartelistenplatz: nil, belegungGilt: true)
        case .warteliste:
            return "Abmelden ist jederzeit möglich."
        case .frei, .voll, .vorbei, .abgesagt:
            return nil
        }
    }

    /// Ob neben dem Hinweis der Abmelden-Knopf steht.
    ///
    /// Die Warteliste kennt keine Frist (siehe oben), der Knopf bleibt
    /// dort also immer. Beim bestaetigten Platz verschwindet er mit der
    /// Frist -- und mit ihm der einzige Weg, einen Fehlerbanner wieder
    /// loszuwerden, weshalb auch der dann nicht mehr gezeigt wird.
    static func zeigtAbmeldenKnopf(fuer zustand: KursZustand, abmeldefristVerstrichen: Bool) -> Bool {
        switch zustand {
        case .angemeldet: return !abmeldefristVerstrichen
        case .warteliste: return true
        case .frei, .voll, .vorbei, .abgesagt: return false
        }
    }
}
