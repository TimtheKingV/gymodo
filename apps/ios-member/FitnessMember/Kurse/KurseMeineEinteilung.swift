import Foundation

/// Eine eigene Anmeldung, angereichert um den bereits geparsten Beginn --
/// `KurseMeineEinteilung.bilden` parst `startsAt` ohnehin fuer die
/// Zustands- und Wochenzuordnung; das Ergebnis wird hier mitgegeben, damit
/// der View denselben Zeitpunkt nicht ein zweites Mal aus dem String
/// herstellen muss (und dafuer keinen `Date()`-Verlegenheitsfallback fuer
/// einen strukturell schon ausgeschlossenen Parse-Fehler braucht).
///
/// Nicht `private`: `KurseMeineEinteilungTests` prueft die Zuordnung ohne
/// UI und braucht dafuer Zugriff auf beide Typen, wie
/// `KursDetailInhaltTests` auf `KursDetailInhalt` in KursDetailView.swift.
struct KurseMeineZeile: Identifiable, Equatable {
    let termin: GespeicherterTermin
    let beginn: Date
    var id: String { termin.sessionId }
}

/// Ordnet die gespeicherten eigenen Termine (`KurseStore.eigene.termine`)
/// den drei Abschnitten des Artboards zu -- eine reine Ableitung, getestet
/// in `KurseMeineEinteilungTests`, ohne jede UI-Abhaengigkeit.
///
/// Reihenfolge der Auswertung:
/// 1. Zustand ueber `KursDetailOfflineZustand.zustand(fuer:jetzt:)` --
///    dieselbe schmale Ableitung wie in KursDetailView (Aufgabenbrief
///    Hinweis 3: keine neue Platzhalter-Ableitung fuer denselben Fall).
///    `.abgesagt` und `.vorbei` fallen komplett weg: ein abgesagter oder
///    bereits vergangener Termin ist keine offene eigene Anmeldung mehr,
///    um die sich dieser Screen kuemmert -- Wochenplan und Kursdetail
///    zeigen ihn weiterhin, solange er dort auffindbar ist.
/// 2. Von den verbleibenden (`.angemeldet`/`.warteliste`) landet ein
///    Termin, dessen Kalenderwoche (Montag, Studio-Zeitzone) NICHT die
///    Kalenderwoche von `jetzt` ist, unter "Später" -- unabhaengig
///    vom eigenen Status. Das Artboard zeigt dort einen einzelnen,
///    aktionslosen Vorschau-Eintrag ohne Frist- oder Wartelisten-
///    Fusszeile; die Aufteilung nach Woche statt nach Status bildet genau
///    das nach. (Diese Regel steht nicht woertlich im Aufgabenbrief --
///    siehe Bericht.) Der Abschnitt hiess bis zur Schlusswelle "Nächste
///    Woche"; seit das Ladefenster bis "jetzt plus 14 Tage" reicht, kann
///    er auch Termine der uebernaechsten Woche enthalten.
/// 3. Innerhalb der aktuellen Kalenderwoche entscheidet der eigene Status:
///    `.angemeldet` -> "Angemeldet", `.warteliste` -> "Auf der
///    Warteliste".
///
/// Ein unlesbarer Beginn (`Zeitpunkt.parse` liefert `nil`) faellt ganz
/// weg: ohne lesbaren Beginn liesse sich weder der Zustand (vorbei?) noch
/// die Wochenzugehoerigkeit bestimmen, und ein erratener Abschnitt waere
/// schlimmer als ein fehlender Eintrag.
struct KurseMeineEinteilung {
    let angemeldet: [KurseMeineZeile]
    let warteliste: [KurseMeineZeile]
    let spaeter: [KurseMeineZeile]

    var istLeer: Bool { angemeldet.isEmpty && warteliste.isEmpty && spaeter.isEmpty }

    /// Alle eigenen Anmeldungen als EINE zeitlich aufsteigende Liste.
    ///
    /// Das Band auf dem Kurse-Screen kennt die drei Abschnitte nicht mehr:
    /// dort steht der naechste Kurs oben, ganz gleich ob bestaetigter
    /// Platz, Warteliste oder Termin naechster Woche -- der Zustand steht
    /// auf der Karte selbst (Kontur, Marke, Abmeldehinweis), er muss nicht
    /// noch einmal als Ueberschrift daruebergesetzt werden.
    ///
    /// Die drei Abschnitte bleiben trotzdem: sie sind die getestete
    /// Zuordnung, aus der diese Liste entsteht.
    var alleZeilen: [KurseMeineZeile] {
        (angemeldet + warteliste + spaeter).sorted { $0.beginn < $1.beginn }
    }

    static func bilden(aus termine: [GespeicherterTermin], jetzt: Date, zeitzone: String) -> KurseMeineEinteilung {
        let heutigerMontag = KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone)
        let sortiert = termine.sorted {
            (Zeitpunkt.parse($0.startsAt) ?? .distantPast)
                < (Zeitpunkt.parse($1.startsAt) ?? .distantPast)
        }

        var angemeldet: [KurseMeineZeile] = []
        var warteliste: [KurseMeineZeile] = []
        var spaeter: [KurseMeineZeile] = []

        for termin in sortiert {
            let zustand = KursDetailOfflineZustand.zustand(fuer: termin, jetzt: jetzt)
            guard zustand == .angemeldet || zustand == .warteliste else { continue }
            guard let beginn = Zeitpunkt.parse(termin.startsAt) else { continue }

            let zeile = KurseMeineZeile(termin: termin, beginn: beginn)
            if KurseWochenBerechnung.montag(enthaelt: beginn, zeitzone: zeitzone) != heutigerMontag {
                spaeter.append(zeile)
            } else if zustand == .angemeldet {
                angemeldet.append(zeile)
            } else {
                warteliste.append(zeile)
            }
        }

        return KurseMeineEinteilung(angemeldet: angemeldet, warteliste: warteliste, spaeter: spaeter)
    }
}

/// Der Zustand des "Abmelden"-Knopfs EINER Zeile -- eine reine Ableitung
/// aus der Menge gerade laufender Abmeldeversuche und den Fehlermeldungen
/// je sessionId, getestet in `KurseMeineAbmeldeZustandTests` ohne UI.
///
/// Review-Fund M2: ein einzelner `stornierendId`-Wert kann immer nur EINE
/// Zeile als "laeuft" fuehren. Beginnt eine zweite Zeile ihre Abmeldung,
/// waehrend die erste noch unterwegs ist, wuerde die erste wieder als
/// "bereit" erscheinen -- obwohl ihre Anfrage noch offen ist -- und liesse
/// sich ein zweites Mal antippen, mit einer zweiten, nebenlaeufigen
/// Anfrage fuer denselben Termin. Diese Ableitung nimmt stattdessen eine
/// `Set<String>` laufender sessionIds entgegen: jede Zeile fragt nur nach
/// ihrer EIGENEN sessionId und bleibt unabhaengig von jeder anderen
/// gesperrt, waehrend ihr eigener Versuch laeuft.
enum KurseMeineAbmeldeZustand: Equatable {
    case bereit
    case laeuft
    case fehlgeschlagen(String)

    static func fuer(sessionId: String, laufende: Set<String>, fehlermeldungen: [String: String]) -> KurseMeineAbmeldeZustand {
        if laufende.contains(sessionId) { return .laeuft }
        if let fehler = fehlermeldungen[sessionId] { return .fehlgeschlagen(fehler) }
        return .bereit
    }
}
