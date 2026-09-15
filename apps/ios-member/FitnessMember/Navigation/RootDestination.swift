import Foundation

enum RootDestination: Equatable {
    case authFlow
    case loadingCatalog
    case onboarding
    case noStudio
    case main
}

enum RootDestinationLogic {
    /// `onboarding` VOR `noStudio`: die Angaben gehoeren zur Person, nicht
    /// zum Studio, und wer noch keinem beigetreten ist, soll nicht zwei
    /// Einstiege hintereinander sehen. Nur bei .loaded -- ein gescheiterter
    /// Bootstrap weiss nicht, ob das Onboarding offen ist, und darf es nicht
    /// raten.
    ///
    /// .failed faellt bewusst auf .noStudio zurueck statt auf .main: ein
    /// gescheiterter Bootstrap-Ladevorgang soll nie so aussehen wie ein
    /// Mitglied ohne Studio, aber .noStudio zeigt wenigstens eine Aktion
    /// (Beitreten/erneut versuchen) statt einer blockierenden Sackgasse.
    static func destination(session: Session?, catalogState: CatalogLoadState, onboardingOffen: Bool) -> RootDestination {
        guard session != nil else { return .authFlow }
        switch catalogState {
        case .idle, .loading: return .loadingCatalog
        case .loaded(let hasStudio):
            if onboardingOffen { return .onboarding }
            return hasStudio ? .main : .noStudio
        case .failed: return .noStudio
        }
    }
}
