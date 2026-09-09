import Foundation

enum RootDestination: Equatable {
    case authFlow
    case loadingCatalog
    case noStudio
    case main
}

enum RootDestinationLogic {
    /// .failed faellt bewusst auf .noStudio zurueck statt auf .main: ein
    /// gescheiterter Bootstrap-Ladevorgang soll nie so aussehen wie ein
    /// Mitglied ohne Studio, aber .noStudio zeigt wenigstens eine Aktion
    /// (Beitreten/erneut versuchen) statt einer blockierenden Sackgasse.
    static func destination(session: Session?, catalogState: CatalogLoadState) -> RootDestination {
        guard session != nil else { return .authFlow }
        switch catalogState {
        case .idle, .loading: return .loadingCatalog
        case .loaded(let hasStudio): return hasStudio ? .main : .noStudio
        case .failed: return .noStudio
        }
    }

    /// Ob RootView die plattenbasierten Caches (Katalog, Kurse, Verlauf,
    /// laufende Trainingseinheit) zuruecksetzen muss: immer, sobald die
    /// Zielansicht .authFlow ist -- nicht erst beim Wechsel "hatte eine
    /// Session -> hat keine mehr".
    ///
    /// Genau dieser Unterschied schliesst eine Luecke: Konto A meldet sich
    /// an, die App wird hart beendet, das Token laeuft ab. Beim naechsten
    /// Start haben die Stores A's Daten schon aus ihren Initializern von
    /// der Platte geladen, restoreSession() liefert nil, und ein Wachposten
    /// nach dem Muster "hatte je eine Session" wurde in diesem Prozess nie
    /// wahr -- kein Reset liefe je, und Konto B saehe A's Sessions,
    /// Gewichte und RIR-Werte, bis der eigene Ladevorgang durchkommt.
    ///
    /// Ein ueberfluessiger Reset ganz am Anfang, waehrend restoreSession()
    /// noch laeuft und `destination` deshalb kurz ebenfalls .authFlow ist,
    /// ist dagegen harmlos: es gibt in diesem Moment ohnehin nichts zu
    /// zeigen, und eine anschliessend wiederhergestellte Session stoesst
    /// den Katalog-Ladevorgang ohnehin neu an.
    static func sollteZuruecksetzen(destination: RootDestination) -> Bool {
        destination == .authFlow
    }
}
