import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var catalogStore

    /// Merkt sich, ob ueberhaupt schon eine Session da war. Ohne dieses Flag
    /// wuerde der erste Lauf von .task(id:) beim Start -- da ist die Session
    /// noch nil, restoreSession() laeuft parallel -- den persistierten
    /// Katalogzustand faelschlich als "Abmeldung" verwerfen.
    @State private var hatteSession = false

    var body: some View {
        let destination = RootDestinationLogic.destination(session: sessionStore.session, catalogState: catalogStore.loadState)

        Group {
            switch destination {
            case .authFlow:
                AuthFlow()
            case .loadingCatalog:
                ProgressView()
                    .tint(DesignSystem.Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Color.bg)
            case .noStudio:
                NavigationStack { MemberKeinStudioView() }
                    .tint(DesignSystem.Color.accent)
            case .main:
                MainTabView()
            }
        }
        // RootView haelt beide Stores bereits und reagiert ohnehin auf
        // Session-Wechsel -- der Reset gehoert deshalb hierher und nicht in
        // SessionStore, das sonst eine neue Abhaengigkeit auf CatalogStore
        // bekaeme.
        .task(id: sessionStore.session) {
            if sessionStore.session != nil {
                hatteSession = true
                // Nicht nur .idle: auch nach .failed muss ein neuer Anlauf
                // moeglich sein. Aber auch nicht mehr als das: ein
                // Passwortwechsel liefert eine neue Session (neuer
                // Access-Token) fuer denselben Nutzer und wuerde sonst bei
                // bereits geladenem Katalog (.loaded) einen unnoetigen
                // Neuladevorgang ausloesen.
                if catalogStore.loadState == .idle || catalogStore.loadState == .failed {
                    await catalogStore.load()
                }
            } else if hatteSession {
                hatteSession = false
                catalogStore.reset()
            }
        }
    }
}
