/// Wie der Sensor haengt (Sensor-Spec B 6.7). Feste Liste statt Freitext,
/// weil der Zaehler je Art ein eigenes Profil braucht: am Stapel ist das
/// Signal linear, an der Hantel kommt Drehung dazu, am Hebel ein Kreisbogen.
public enum Befestigungsart: String, Codable, Sendable, CaseIterable {
    case stapel, langhantel, kurzhantel, hebelarm, kabelgriff, koerper

    /// Arten, fuer die der Zaehler im Release zaehlt (Spec B 7). Jede kommt
    /// in einem eigenen Commit zusammen mit dem Guetebericht hinein, der das
    /// Tor zeigt; GueteberichtTests haelt sie dort fest.
    public static let freigegeben: Set<Befestigungsart> = []
}

/// Ob die Art eines Satzes vorgeschlagen oder vom Nutzer gewaehlt ist
/// (Spec B, Nachtrag 14.10. Punkt 3). Beim Einlesen gilt nur eine gewaehlte
/// Art ohne Rueckfrage als Wahrheit.
public enum BefestigungsartQuelle: String, Codable, Sendable {
    case vorschlag, gewaehlt
}

extension Befestigungsart {
    /// Vorschlag aus dem Geraetetyp (Spec B, Nachtrag 14.10. Punkt 2). Nur
    /// der Name taugt dafuer: die Kategorie kennt nur kraft und cardio.
    /// nil an Cardio-Geraeten, dort ist der Umfang keine Wiederholung.
    public static func vorschlag(geraetename: String, istKraft: Bool) -> Befestigungsart? {
        if geraetename.localizedCaseInsensitiveContains("kurzhantel") { return .kurzhantel }
        if geraetename.localizedCaseInsensitiveContains("langhantel") { return .langhantel }
        // Als eigenes Wort und gross geschrieben: "SZ-Stange", nicht "Schulterpresse".
        let woerter = geraetename.split { !$0.isLetter && !$0.isNumber }
        if woerter.contains("SZ") { return .langhantel }
        return istKraft ? .stapel : nil
    }
}
