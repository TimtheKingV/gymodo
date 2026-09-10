import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var sessionStore: SessionStore
    @State private var catalogStore: CatalogStore
    @State private var workoutStore = WorkoutSessionStore()
    @State private var kurseStore: KurseStore
    @State private var verlaufStore: VerlaufStore
    @State private var netzwerkMonitor = NetzwerkMonitor()
    @State private var pendingTagStore = PendingTagStore()
    private let apiClient: APIClient

    init() {
        let session = SessionStore(backend: SupabaseAuthBackend())
        let client = APIClient(baseURL: AppConfig.apiBaseURL) { await session.currentAccessToken() }
        _sessionStore = State(initialValue: session)
        _catalogStore = State(initialValue: CatalogStore(loader: client, pendingWriteStore: PendingWriteStore()))
        _kurseStore = State(initialValue: KurseStore(loader: client, fileStore: KurseFileStore()))
        _verlaufStore = State(initialValue: VerlaufStore(loader: client, fileStore: VerlaufFileStore()))
        apiClient = client
    }

    var body: some Scene {
        WindowGroup {
            RootView(apiClient: apiClient)
                .environment(sessionStore)
                .environment(catalogStore)
                .environment(workoutStore)
                .environment(kurseStore)
                .environment(verlaufStore)
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
                    // Nicht mehr still verwerfen (so war es bis M1): das
                    // Entitlement laesst nur /t/* in die App, jede URL hier
                    // IST ein Tag-Link. Wird sie abgelehnt, gehoert das dem
                    // Mitglied gesagt -- sonst startet die App wortlos auf
                    // dem Home-Tab und der Aufkleber wirkt kaputt.
                    TagProtokoll.log.info("Link empfangen: \(url.absoluteString, privacy: .public)")
                    if let token = TagLink.token(from: url) {
                        pendingTagStore.capture(token)
                    } else {
                        TagProtokoll.log.error("Link abgelehnt: kein gueltiger Tag-Link")
                        pendingTagStore.captureUngueltig()
                    }
                }
        }
    }
}
