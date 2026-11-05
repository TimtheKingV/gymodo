import Foundation

/// Kurze Texte zur Muskelauswertung auf Home.
enum MuskelHinweise {
    /// Ein Satz ueber die Gruppen mit Nachholbedarf; nennt hoechstens die zwei
    /// schwaechsten (geringste Zahl zuerst, bei Gleichstand Anzeigereihenfolge).
    static func startsatz(_ h: Haeufigkeit) -> String {
        guard h.istAuswertbar else { return "Für die Analyse braucht es noch ein paar Trainings." }
        let schwach = MuskelHauptgruppe.angezeigt.enumerated()
            .filter { Ausgewogenheit.status(gruppe: $0.element, in: h) == .nachholbedarf }
            .sorted {
                let a = h.jeGruppe[$0.element] ?? 0, b = h.jeGruppe[$1.element] ?? 0
                return a != b ? a < b : $0.offset < $1.offset
            }
            .prefix(2)
            .map(\.element.titel)
        switch schwach.count {
        case 0: return "Du trainierst alle Gruppen ähnlich oft."
        case 1: return "\(schwach[0]) kommt zu kurz."
        default: return "\(schwach[0]) und \(schwach[1]) kommen zu kurz."
        }
    }

    /// Nennt den schwaechsten auswertbaren Muskel der Gruppe, falls er Nachholbedarf hat.
    static func gruppenhinweis(gruppe: MuskelHauptgruppe, in h: Haeufigkeit, namen: [String: String]) -> String? {
        let schwaechster = gruppe.muskelSchluessel
            .filter { Ausgewogenheit.status(muskel: $0, gruppe: gruppe, in: h) == .nachholbedarf }
            .min { (h.jeMuskel[$0] ?? 0) < (h.jeMuskel[$1] ?? 0) }
        guard let schluessel = schwaechster else { return nil }
        let name = namen[schluessel] ?? schluessel
        let anzahl = h.jeMuskel[schluessel] ?? 0
        let wie = anzahl == 0 ? "nicht dran" : "\(anzahl)× dran"
        return "\(name) kam in \(Haeufigkeit.fensterTage) Tagen \(wie). Eine Übung dafür würde dein Training abrunden."
    }
}
