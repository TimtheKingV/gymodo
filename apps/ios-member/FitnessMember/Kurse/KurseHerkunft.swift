import Foundation

/// Wie frisch das ist, was ein Kurse-Screen gerade zeigt -- und ob eine
/// Belegungszahl darin ueberhaupt noch etwas aussagt.
///
/// EINE Ableitung fuer alle drei Screens. Vorher hatte jeder seine eigene
/// Antwort auf dieselbe Frage: `KurseWochenView` unterschied Offline von
/// Serverfehler, `KursDetailView` nannte jeden Fehler "ohne Empfang",
/// `KurseMeineView` schwieg beim Serverfehler -- und die Fuenf-Minuten-
/// Regel samt "Stand: ..." gab es nur auf dem Wochenplan, waehrend das
/// Kursdetail "12 von 16" ohne jede Altersangabe zeigte. Drei Screens,
/// drei Antworten auf dieselbe Bedingung; genau das war M1, M2 und M3.
///
/// Der Kern ist Spec 5.2: eine Belegungszahl veraltet binnen Minuten, und
/// sie ohne Netz zu zeigen, als waere sie aktuell, ist eine Unwahrheit.
/// Die Antwort darauf ist NICHT, den ganzen Plan wegzuwerfen -- Name,
/// Uhrzeit und Raum eines Termins aendern sich nicht, die Belegung schon.
/// Es faellt also weg, was nicht mehr stimmt (`zeigtBelegung`), und stehen
/// bleibt, was weiter stimmt, mit einer ehrlichen Altersangabe darueber.
enum KurseHerkunft: Equatable {
    /// Zuletzt erfolgreich geladen, und das ist frisch genug. Nur hier
    /// gelten Belegungszahlen.
    case frisch
    /// Erfolgreich geladen, aber zu lange her.
    case veraltet
    /// Der letzte Ladeversuch scheiterte ohne Empfang.
    case ohneEmpfang
    /// Der letzte Ladeversuch scheiterte am Server. "Kein Empfang" waere
    /// hier eine falsche Aussage ueber das Geraet -- und sie schickte das
    /// Mitglied WLAN suchen statt es erneut versuchen zu lassen.
    case serverfehler

    /// Ab wann eine Belegungszahl nicht mehr als frisch durchgeht.
    ///
    /// Nicht die Grenze, ab der die Zahl falsch WIRD -- das weiss niemand
    /// --, sondern die, ab der sie ohne Datum eine Behauptung waere.
    static let frischeGrenze: TimeInterval = 5 * 60

    /// Am LADEZUSTAND, nicht an der Datenquelle: `KurseStore.laden` kennt
    /// den tatsaechlichen `APIError`, die Quelle kennt ihn nicht.
    ///
    /// `wocheStand == nil` heisst "noch kein erfolgreicher Abruf in dieser
    /// Sitzung" -- dann gibt es nichts zu datieren, und waehrend `.laedt`
    /// ist auch nichts fehlgeschlagen. Ohne diesen Zweig flackerte beim
    /// ersten Laden ein Hinweis auf, der noch fuer nichts gilt.
    static func bilden(
        ladeZustand: KurseLadeZustand, wocheStand: Date?, jetzt: Date
    ) -> KurseHerkunft {
        if case .fehlgeschlagen(let fehler) = ladeZustand {
            return fehler == .offline ? .ohneEmpfang : .serverfehler
        }
        guard let wocheStand else { return .frisch }
        return jetzt.timeIntervalSince(wocheStand) >= frischeGrenze ? .veraltet : .frisch
    }

    /// Nur frische Zahlen sind Zahlen (Spec 5.2). Gilt fuer die
    /// Belegung ("12 von 16") und fuer alles andere, was sich ohne Zutun
    /// des Mitglieds aendert.
    var zeigtBelegung: Bool { self == .frisch }

    var symbol: String? {
        switch self {
        case .frisch: nil
        case .ohneEmpfang: "wifi.slash"
        case .veraltet, .serverfehler: "clock.arrow.circlepath"
        }
    }

    /// Der Satz ueber dem Inhalt. `nil`, solange alles frisch ist -- ein
    /// Datum ueber einer gerade geholten Zahl waere Rauschen.
    ///
    /// `stand` gibt der Screen mit, weil jeder etwas anderes zeigt: der
    /// Wochenplan `KurseStore.wocheStand`, "Meine Kurse" den Stand seines
    /// Caches, das Kursdetail je nach Quelle das eine oder das andere.
    /// `zusatz` ebenso -- "nach unten ziehen" gilt nur dort, wo es ein
    /// Ziehen zum Aktualisieren gibt.
    func satz(stand: Date?, zusatz: String? = nil) -> String? {
        guard self != .frisch else { return nil }
        return Herkunftssatz.bilden(
            ohneEmpfang: self == .ohneEmpfang, stand: stand, zusatz: zusatz)
    }
}
