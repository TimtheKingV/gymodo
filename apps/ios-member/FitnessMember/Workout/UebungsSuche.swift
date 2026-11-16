import Foundation

/// Die Suche in der Uebungsliste eines Geraets (Testnotiz 10.11., #15):
/// ab mehr als 3 Uebungen, im Namen, Gross/klein und Umlaute egal --
/// dieselbe Normalisierung wie die Geraetesuche.
enum UebungsSuche {
    /// "Wenn über 3 Übungen an einem Gerät sind" (Tim).
    static let sucheAb = 4

    static func bietetSucheAn(uebungsanzahl: Int) -> Bool {
        uebungsanzahl >= sucheAb
    }

    /// nil = keine Suche aktiv (leer oder nur Leerzeichen): die Liste zeigt
    /// ihre normale Ansicht. Sonst die Treffer in der Reihenfolge von
    /// `uebungen`, auch leer.
    static func treffer(_ uebungen: [GeraetUebung], suchtext: String) -> [GeraetUebung]? {
        let gesucht = GeraeteAuswahl.normalisiert(suchtext)
        guard !gesucht.isEmpty else { return nil }
        return uebungen.filter { GeraeteAuswahl.normalisiert($0.name).contains(gesucht) }
    }
}
