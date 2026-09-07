import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var sessionStore: SessionStore
    @State private var catalogStore: CatalogStore
    @State private var pendingTagStore = PendingTagStore()

    init() {
        let session = SessionStore(backend: SupabaseAuthBackend())
        let apiClient = APIClient(baseURL: AppConfig.apiBaseURL) { await session.currentAccessToken() }
        _sessionStore = State(initialValue: session)
        _catalogStore = State(initialValue: CatalogStore(loader: apiClient, pendingWriteStore: PendingWriteStore()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .environment(catalogStore)
                .environment(pendingTagStore)
                .task {
                    await sessionStore.restoreSession()
                }
                .onOpenURL { url in
                    // Ungueltige Links werden still verworfen (M0-Verhalten
                    // aus Task 7 unveraendert uebernommen).
                    if let token = TagLink.token(from: url) {
                        pendingTagStore.capture(token)
                    }
                }
        }
    }
}
