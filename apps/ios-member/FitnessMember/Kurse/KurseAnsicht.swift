import Foundation

/// Die beiden Haelften des Umschalters unter dem Kalender auf dem
/// Kurse-Screen -- und die eine Regel, die entscheidet, welche gilt.
///
/// Der Screen zeigt seit dem Umbau EINEN Kalender ganz oben und darunter
/// entweder die eigenen Anmeldungen oder den Wochenplan des gewaehlten
/// Tages. Frueher standen beide Listen untereinander; wer angemeldet war,
/// musste an seinen eigenen Kursen vorbeiscrollen, um den Plan zu sehen,
/// und wer es nicht war, las eine Ueberschrift ohne Inhalt.
///
/// Der Kalender wirkt dabei NUR auf „Alle Kurse“. „Angemeldet“ zeigt alle
/// kommenden Anmeldungen des Ladefensters, naechste zuerst -- tagesweise
/// gefiltert waere diese Haelfte an den meisten Tagen leer, und der
/// Umschalter zeigte auf nichts. Die Punkte unter den Tageszellen sagen
/// weiterhin, an welchen Tagen ein eigener Platz steht
/// (`KurseTagesindikator`).
enum KurseAnsicht: Hashable, CaseIterable {
    case angemeldet
    case alle

    /// Die Beschriftung der Haelfte -- zugleich das, was VoiceOver
    /// vorliest. Sie steht am Typ und nicht im View, damit Knopf und
    /// Vorlesung nicht auseinanderlaufen koennen.
    var titel: String {
        switch self {
        case .angemeldet: "Angemeldet"
        case .alle: "Alle Kurse"
        }
    }

    /// Der Umschalter erscheint nur, wenn es eine offene eigene Anmeldung
    /// gibt. Ohne sie waere seine linke Haelfte leer, und ein Knopf, der
    /// auf nichts zeigt, ist schlimmer als kein Knopf: der Screen faengt
    /// dann direkt mit dem Wochenplan an.
    static func zeigtUmschalter(hatAnmeldungen: Bool) -> Bool { hatAnmeldungen }

    /// Die geltende Ansicht -- die getippte, sofern es sie gibt und sie
    /// noch erreichbar ist, sonst die Vorauswahl.
    ///
    /// `gewaehlt` ist `nil`, solange niemand den Umschalter angefasst hat.
    /// Dasselbe Muster wie `gewaehlterTagId` im Screen und aus demselben
    /// Grund: eine rein abgeleitete Vorauswahl bleibt auch dann richtig,
    /// wenn sich die Daten unter der offenen App aendern -- der Screen
    /// zeichnet im 60-Sekunden-Takt neu, und bei jedem Neuzeichnen kann
    /// die letzte Anmeldung vorbei oder abgemeldet sein.
    ///
    /// Ohne Anmeldungen gewinnt `.alle` gegen JEDE getippte Wahl: mit der
    /// letzten Anmeldung verschwindet der Umschalter, und mit ihm die
    /// Haelfte, ueber die man zurueckkaeme. Bliebe `.angemeldet` gelten,
    /// stuende unter dem Kalender eine leere Flaeche ohne Ausweg.
    static func geltend(gewaehlt: KurseAnsicht?, hatAnmeldungen: Bool) -> KurseAnsicht {
        guard hatAnmeldungen else { return .alle }
        return gewaehlt ?? .angemeldet
    }

    /// Die Ansicht, nachdem ein Tag im Streifen angetippt wurde.
    ///
    /// **Der Kalender wirkt nur auf „Alle Kurse".** Das bleibt so -- das
    /// Band der eigenen Anmeldungen zeigt bewusst alle, nicht die eines
    /// Tages. Nur hatte das eine Nebenwirkung: wer in der
    /// „Angemeldet"-Haelfte auf einen Tag tippte, sah darunter weiter
    /// seine Anmeldungen stehen, und es wirkte, als faende genau dieser
    /// Kurs an genau diesem Tag statt. Der Tag antwortete nicht, aber es
    /// sah aus, als haette er (Testnotiz vom 19. September, Eintrag 8).
    ///
    /// Deshalb schaltet ein Tag OHNE eigenen Platz auf „Alle Kurse" um --
    /// dorthin, wo er ueberhaupt etwas zu sagen hat. Ein Tag MIT eigenem
    /// Platz laesst die Haelfte stehen: dort steht das, wonach man
    /// getippt hat, schon im Band.
    ///
    /// Aus `.alle` heraus aendert der Tipp nie etwas -- der Kalender
    /// filtert dort bereits.
    static func nachTagwahl(bisher: KurseAnsicht, indikator: KurseTagesindikator) -> KurseAnsicht {
        guard bisher == .angemeldet, indikator != .angemeldet else { return bisher }
        return .alle
    }
}
