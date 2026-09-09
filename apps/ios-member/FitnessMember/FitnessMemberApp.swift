import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var sessionStore: SessionStore
    @State private var catalogStore: CatalogStore
    @State private var workoutStore = WorkoutSessionStore()
    @State private var kurseStore: KurseStore
    @State private var netzwerkMonitor = NetzwerkMonitor()
    @State private var pendingTagStore = PendingTagStore()
    private let apiClient: APIClient

    init() {
        let session = SessionStore(backend: SupabaseAuthBackend())
        let client = APIClient(baseURL: AppConfig.apiBaseURL) { await session.currentAccessToken() }
        _sessionStore = State(initialValue: session)
        _catalogStore = State(initialValue: CatalogStore(loader: client, pendingWriteStore: PendingWriteStore()))
        _kurseStore = State(initialValue: KurseStore(loader: client, fileStore: KurseFileStore()))
        apiClient = client
    }

    var body: some Scene {
        WindowGroup {
            RootView(apiClient: apiClient)
                .environment(sessionStore)
                .environment(catalogStore)
                .environment(workoutStore)
                .environment(kurseStore)
                .environment(netzwerkMonitor)
                .environment(pendingTagStore)
                .task {
                    await sessionStore.restoreSession()
                    // Der bisher fehlende Ausloeser der Schreib-Warteschlange.
                    netzwerkMonitor.start {
                        Task { await catalogStore.flushPending() }
                    }
                    await catalogStore.flushPending()
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
