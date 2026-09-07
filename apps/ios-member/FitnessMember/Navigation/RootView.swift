import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var catalogStore

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
        .task(id: sessionStore.session) {
            if sessionStore.session != nil, catalogStore.loadState == .idle {
                await catalogStore.load()
            }
        }
    }
}
