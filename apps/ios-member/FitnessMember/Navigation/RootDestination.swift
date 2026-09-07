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
}
