/// Befestigungsarten, fuer die der Tempo-Modus angeboten wird (Tempo-Spec 7.6).
/// Eigene Liste, unabhaengig von `Befestigungsart.freigegeben` des Zaehlers:
/// Eine Art kommt erst hinein, wenn `tempobericht.md` fuer sie das Guetetor
/// zeigt; `TempoBerichtTests` haelt sie dort fest.
public enum Tempofreigabe {
    public static let arten: Set<Befestigungsart> = []
}
