import Foundation

/// Die sechs Zustaende eines Kurstermins aus Sicht des eigenen Mitglieds
/// (Spec Abschnitt 5.3) -- eine reine Funktion, weil alle drei
/// Kurse-Screens dieselbe Auswertung brauchen und keiner sie noch einmal
/// erfinden soll.
enum KursZustand: Equatable {
    case abgesagt
    case vorbei
    case angemeldet
    case warteliste
    case frei
    case voll
}

enum KursZustandRechner {
    /// Verbindliche Auswertungsreihenfolge: abgesagt schlaegt vorbei,
    /// vorbei schlaegt jeden eigenen Status. Ein abgesagter Kurs, fuer den
    /// man angemeldet ist, ist abgesagt -- nicht angemeldet. Ein Termin,
    /// dessen Beginn schon vergangen ist, gilt als vorbei, auch wenn er
    /// gerade erst losgegangen ist: an- und abmelden geht dann beides
    /// nicht mehr.
    static func zustand(fuer termin: CourseWeekSession, jetzt: Date) -> KursZustand {
        if termin.status == "cancelled" { return .abgesagt }

        if let beginn = Zeitpunkt.parse(termin.startsAt), beginn <= jetzt {
            return .vorbei
        }

        switch termin.ownStatus {
        case "booked": return .angemeldet
        case "waitlisted": return .warteliste
        default: return termin.freeSeats > 0 ? .frei : .voll
        }
    }

    /// Der spaeteste Zeitpunkt, zu dem eine Abmeldung noch durchgeht --
    /// die Swift-Seite von `abmeldenBis` in courses.ts. Dort dient die
    /// Funktion nur der Server-Testsuite als Dokumentation des Zeitpunkts,
    /// den der Server tatsaechlich prueft; die verbindliche Pruefung
    /// bleibt server-seitig. Hier ist es die Anzeige, die die drei Screens
    /// brauchen -- eine bewusste Doppelung an der Systemgrenze.
    ///
    /// `nil` bei unlesbarem Beginn: eine erfundene Uhrzeit waere schlimmer
    /// als gar keine.
    static func abmeldenBis(startsAt: String, fristStunden: Int) -> Date? {
        guard let beginn = Zeitpunkt.parse(startsAt) else { return nil }
        return beginn.addingTimeInterval(-Double(fristStunden) * 3600)
    }

    /// Eigene Buchungen und Wartelistenplaetze, zeitlich sortiert -- was
    /// KurseMeine zeigt.
    static func meineKurse(aus woche: CourseWeek) -> [CourseWeekSession] {
        woche.sessions
            .filter { $0.ownStatus != nil }
            .sorted {
                (Zeitpunkt.parse($0.startsAt) ?? .distantPast)
                    < (Zeitpunkt.parse($1.startsAt) ?? .distantPast)
            }
    }
}

/// Uhrzeiten und Datumsangaben in der Studio-Zeitzone (designsystem.md
/// SS10) -- bewusst getrennt von `Zahlformat.uhrzeit` (Aufgabe 5), das
/// geraetelokal formatiert und fuer die eigene Trainingseinheit richtig
/// ist. Ein Kurstermin gehoert dem Studio, nicht dem Geraet, das gerade
/// hinschaut, und `CourseWeek.timezone` liefert die Zeitzone mit. Zwei
/// Funktionen statt einer mit optionalem Parameter, damit keine
/// Aufrufstelle die Zeitzone spaeter vergisst.
///
/// Beide Formatter werden je Aufruf neu angelegt statt als gecachte
/// `static let` gehalten (anders als in Zahlformat): die Zeitzone ist ein
/// Aufrufparameter, und ein gemeinsamer, gecachter `DateFormatter` (eine
/// nicht-Sendable Klasse mit veraenderlichem `timeZone`) muesste bei
/// jedem Aufruf umgeschaltet werden -- das waere geteilter veraenderlicher
/// Zustand ueber nebenlaeufige Aufrufe hinweg.
enum KursZeit {
    static func uhrzeit(_ zeitpunkt: Date, zeitzone: String) -> String {
        let formatter = DateFormatter()
        // en_US_POSIX, nicht de_DE: "HH:mm" ist ein rein numerisches
        // Muster, und ein regionsgebundenes Gebietsschema kann "HH" unter
        // der Nutzereinstellung "24-Stunden-Zeit aus" umbiegen --
        // dieselbe Korrektur wie bei Zahlformat.uhrzeit (Aufgabe 5).
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: zeitpunkt)
    }

    static func datumAusgeschrieben(_ zeitpunkt: Date, zeitzone: String) -> String {
        let formatter = DateFormatter()
        // de_DE, bewusst nicht en_US_POSIX: dieses Muster traegt deutsche
        // Wochentags- und Monatsnamen ("Mi, 27. August"), und
        // en_US_POSIX wuerde daraus englischen Text machen ("Wed, 27
        // August"). Der Unterschied zur Uhrzeit oben: dort stehen nur
        // Ziffern, hier steht Sprache -- und die App ist durchgehend
        // Deutsch (SS10), nicht geraetelokal ueber .current.
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: zeitzone) ?? TimeZone(identifier: "UTC")
        // "ccc" (stand-alone) statt "EEE" (Satzform): liefert "Mi" ohne
        // Punkt, wie designsystem.md SS10 es vorschreibt -- "EEE" liefert
        // in der de_DE-CLDR-Tabelle "Mi." mit Punkt.
        formatter.dateFormat = "ccc, d. MMMM"
        return formatter.string(from: zeitpunkt)
    }
}
