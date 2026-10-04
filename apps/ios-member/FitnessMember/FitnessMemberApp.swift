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
    #if DEBUG
    /// Eine Instanz fuer die ganze App: die Verbindung ueberlebt den Wechsel
    /// zwischen Geraeten (Spec Sensor-Anbindung 5.3). Der CBCentralManager
    /// entsteht erst beim Tap auf "Sensor verbinden".
    @State private var sensorAufnahme = SensorAufnahmeKoordinator(
        quelle: BluetoothSensorQuelle(),
        wurzel: URL.documentsDirectory.appendingPathComponent("Sensoraufnahmen"),
        geraet: .init(
            model: Laufzeitkontext.modellkennung(),
            os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))
    #endif
    private let apiClient: APIClient

    init() {
        // Vor allem anderen: UINavigationBar.appearance() wirkt nur auf
        // Leisten, die danach entstehen.
        Navigationsleiste.einrichten()

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
                .testnotizInstallieren(netz: netzwerkMonitor, katalog: catalogStore, session: sessionStore)
                .environment(sessionStore)
                .environment(catalogStore)
                .environment(workoutStore)
                .environment(kurseStore)
                .environment(verlaufStore)
                .environment(netzwerkMonitor)
                .environment(pendingTagStore)
                #if DEBUG
                .sensorInstallieren(sensorAufnahme)
                #endif
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

private extension View {
    #if DEBUG
    func sensorInstallieren(_ koordinator: SensorAufnahmeKoordinator) -> some View {
        environment(koordinator).task { koordinator.starten() }
    }
    #endif
}
