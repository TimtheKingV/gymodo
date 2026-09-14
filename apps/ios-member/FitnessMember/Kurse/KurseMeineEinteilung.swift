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

/// Ein Abschnitt der eigenen Anmeldungen, benannt nach seinem Abstand zur
/// laufenden Woche ("Diese Woche", "Nächste Woche", ...).
///
/// `titel` ist der Nutzertext in normaler Schreibweise; die Grossschrift
/// ist Sache der Darstellung, damit VoiceOver das Wort liest und nicht
/// buchstabiert. `id` ist der Titel selbst: jede Stufe kommt hoechstens
/// einmal vor.
struct KurseAbschnitt: Identifiable, Equatable {
    let titel: String
    let zeilen: [KurseMeineZeile]
    var id: String { titel }
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
///    er auch Termine der uebernaechsten Woche enthalten. Der Screen zeigt
///    die drei Listen nicht mehr in dieser Form, sondern neu geschnitten
///    nach Wochenabstand (`abschnitte`) -- sie bleiben die getestete
///    Grundlage, aus der dieser Schnitt entsteht.
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

    /// Alle eigenen Anmeldungen als EINE zeitlich aufsteigende Liste --
    /// die Eingabe von `abschnitte`.
    ///
    /// Erst zusammenfuehren, dann nach Woche schneiden: die Liste auf dem
    /// Kurse-Screen teilt nach Zeit, nicht nach Status, und innerhalb einer
    /// Woche steht der naechste Kurs oben, ganz gleich ob bestaetigter
    /// Platz oder Warteliste -- der Zustand steht auf der Karte selbst
    /// (Kontur, Marke, Abmeldehinweis).
    var alleZeilen: [KurseMeineZeile] {
        (angemeldet + warteliste + spaeter).sorted { $0.beginn < $1.beginn }
    }

    /// Die Stufen in zeitlicher Folge; die letzte nimmt alles ab ihrem
    /// Abstand auf.
    private static let abschnittTitel = ["Diese Woche", "Nächste Woche", "Übernächste Woche", "Bald"]

    /// Ob die Liste ihre Wochen-Ueberschriften zeigt. Liegt alles in dieser
    /// Woche, trennt die Ueberschrift nichts, und die Beschriftung des
    /// Umschalters darueber sagt schon, was die Liste ist. Ein einzelner
    /// Abschnitt einer SPAETEREN Woche behaelt sie -- ohne sie laese sich
    /// die Karte wie diese Woche.
    ///
    /// Gegen den Titel aus `abschnittTitel`, nicht gegen ein zweites
    /// Literal im View: sonst liefe ein umbenannter Titel still an der
    /// Regel vorbei.
    static func zeigtUeberschriften(_ abschnitte: [KurseAbschnitt]) -> Bool {
        !(abschnitte.count == 1 && abschnitte.first?.titel == abschnittTitel[0])
    }

    /// Die eigenen Anmeldungen, geschnitten nach ganzen Wochen Abstand zur
    /// Woche von `jetzt`: 0 "Diese Woche", 1 "Nächste Woche",
    /// 2 "Übernächste Woche", ab 3 "Bald". Leere Abschnitte fallen weg --
    /// eine Ueberschrift ohne Karte darunter sagte nur "hier ist nichts".
    ///
    /// Die Woche beginnt am Montag 00:00 in der Studio-Zeitzone
    /// (`KurseWochenBerechnung.montag`), dieselbe Grenze wie der
    /// Wochenstreifen darueber -- sonst stuende ein Termin unter "Nächste
    /// Woche", den der Kalender noch in dieser zeigt.
    ///
    /// Gezaehlt in Kalendertagen zwischen den beiden Montagen, nicht in
    /// Sekunden: eine Woche mit Zeitumstellung hat 167 oder 169 Stunden,
    /// und eine abgeschnittene Sekundenrechnung legte den Montag nach der
    /// Umstellung im Fruehjahr noch in die laufende Woche.
    ///
    /// "Bald" bleibt beim heutigen Ladefenster (jetzt plus 14 Tage,
    /// `KurseWochenBerechnung.fensterEnde`) leer. Die Stufe steht trotzdem
    /// hier, damit ein groesseres Fenster sie nur noch fuellt, statt dass
    /// die vierte Woche dann ohne Ueberschrift unter der dritten landet.
    func abschnitte(jetzt: Date, zeitzone: String) -> [KurseAbschnitt] {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")!
        let heutigerMontag = KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone)
        let titel = Self.abschnittTitel

        var stufen = Array(repeating: [KurseMeineZeile](), count: titel.count)
        for zeile in alleZeilen {
            let montag = KurseWochenBerechnung.montag(enthaelt: zeile.beginn, zeitzone: zeitzone)
            let tage = kalender.dateComponents([.day], from: heutigerMontag, to: montag).day ?? 0
            // Nach unten geklemmt, obwohl `bilden` Vergangenes schon
            // aussortiert: ein negativer Index waere ein Absturz, eine
            // Karte unter "Diese Woche" nur ungenau.
            let stufe = min(max(tage / 7, 0), titel.count - 1)
            stufen[stufe].append(zeile)
        }

        return zip(titel, stufen)
            .filter { !$0.1.isEmpty }
            .map { KurseAbschnitt(titel: $0.0, zeilen: $0.1) }
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
