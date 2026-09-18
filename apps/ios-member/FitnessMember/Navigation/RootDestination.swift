import Foundation

enum RootDestination: Equatable {
    case authFlow
    case loadingCatalog
    case onboarding
    case noStudio
    case ladefehler
    case main
}

enum RootDestinationLogic {
    /// `onboarding` VOR `noStudio`: die Angaben gehoeren zur Person, nicht
    /// zum Studio, und wer noch keinem beigetreten ist, soll nicht zwei
    /// Einstiege hintereinander sehen. Nur bei .loaded -- ein gescheiterter
    /// Bootstrap weiss nicht, ob das Onboarding offen ist, und darf es nicht
    /// raten.
    ///
    /// .failed bekommt einen EIGENEN Bildschirm und faellt nicht mehr auf
    /// .noStudio zurueck. Der Rueckfall war als das vorsichtige Verhalten
    /// gedacht -- .noStudio zeigt wenigstens eine Aktion statt einer
    /// blockierenden Sackgasse --, war es aber nicht: er gibt einen Ausfall
    /// als Tatsache ueber die Mitgliedschaft aus. Am 18. September hat er
    /// genau das getan. Der Bootstrap antwortete tagelang mit 500, weil in
    /// der Produktionsdatenbank vier Migrationen fehlten (0041 bis 0044,
    /// member_goals und body_measurements gab es dort nicht). Jedes
    /// Mitglied las daraufhin "Noch kein Studio" -- auch, wer seit einer
    /// Woche in der Datenbank bei seinem Studio stand. Und weil derselbe
    /// Bildschirm den Studio-Code anbietet, tat der Beitritt danach
    /// sichtbar nichts: er gelang, das Neuladen scheiterte erneut, der
    /// Bildschirm blieb Wort fuer Wort stehen.
    ///
    /// Ein Ladefehler ist keine Aussage ueber die Mitgliedschaft. Wer
    /// beides gleich zeichnet, macht den Ausfall von aussen unauffindbar --
    /// und schickt das Mitglied auf die Suche nach einem Code, den es
    /// laengst eingeloest hat.
    static func destination(session: Session?, catalogState: CatalogLoadState, onboardingOffen: Bool) -> RootDestination {
        guard session != nil else { return .authFlow }
        switch catalogState {
        case .idle, .loading: return .loadingCatalog
        case .loaded(let hasStudio):
            if onboardingOffen { return .onboarding }
            return hasStudio ? .main : .noStudio
        case .failed: return .ladefehler
        }
    }
}
