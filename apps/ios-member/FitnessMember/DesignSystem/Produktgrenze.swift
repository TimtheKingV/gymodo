import Foundation

/// Eine Quelle fuer den Satz aus designsystem.md SS10 (Wortlaut seit
/// Sensor Teilprojekt B, Spec 3.2). Eigene Datei statt einer Eigenschaft
/// von GeraetModel, damit der Test ihn ohne Geraetekontext pruefen kann.
enum Produktgrenze {
    static let kanonisch = """
        Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo \
        deine Wiederholungen mit — du siehst die Zahl und entscheidest. \
        Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, \
        keine Trainings- oder Gesundheitsempfehlung von Gymtavo.
        """
}
