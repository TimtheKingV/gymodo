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
