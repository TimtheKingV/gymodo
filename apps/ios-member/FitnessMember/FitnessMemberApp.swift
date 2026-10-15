import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var sessionStore: SessionStore
    @State private var catalogStore: CatalogStore
    @State private var workoutStore = WorkoutSessionStore()
    @State private var kurseStore: KurseStore
    @State private var verlaufStore: VerlaufStore
    @State private var netzwerkMonitor: NetzwerkMonitor
    @State private var pendingTagStore = PendingTagStore()
    /// Die Uebungsvideos fuer Training UND Home: die Fortschrittszeilen auf
    /// Home zeigen sie seit der Testnotiz 11.10. (#2) ebenfalls. Ein Vorrat
    /// fuer beide, damit ein Video nicht zweimal geladen wird.
    @State private var videoVorrat = UebungsVideoVorrat()
    #if DEBUG
    /// Eine Instanz fuer die ganze App: die Verbindung ueberlebt den Wechsel
    /// zwischen Geraeten (Spec Sensor-Anbindung 5.3). Der CBCentralManager
    /// entsteht erst beim Tap auf "Sensor verbinden". Aufnahme und Zaehler
    /// hoeren auf dieselbe Quelle, jeder mit eigenem Strom.
    @State private var sensorAufnahme: SensorAufnahmeKoordinator
    @State private var satzZaehler: ZaehlerKoordinator
    #endif
    private let apiClient: APIClient

    init() {
        // Vor allem anderen: UINavigationBar.appearance() wirkt nur auf
        // Leisten, die danach entstehen.
        Navigationsleiste.einrichten()
        // Vor dem ersten Video: die Kategorie gilt erst fuer Spieler, die
        // danach anlaufen. Scheitert sie, bleibt die App benutzbar.
        try? AudioSitzung.einrichten()

        #if DEBUG
        let quelle = BluetoothSensorQuelle()
        _sensorAufnahme = State(initialValue: SensorAufnahmeKoordinator(
            quelle: quelle,
            wurzel: URL.documentsDirectory.appendingPathComponent("Sensoraufnahmen"),
            geraet: .init(
                model: Laufzeitkontext.modellkennung(),
                os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")))
        _satzZaehler = State(initialValue: ZaehlerKoordinator(quelle: quelle))
        #endif

        let netz = NetzwerkMonitor()
        _netzwerkMonitor = State(initialValue: netz)
        let session = SessionStore(backend: SupabaseAuthBackend())
        let client = APIClient(baseURL: AppConfig.apiBaseURL, istOnline: { await netz.istOnline }) {
            await session.currentAccessToken()
        }
        _sessionStore = State(initialValue: session)
        _catalogStore = State(initialValue: CatalogStore(loader: client, pendingWriteStore: PendingWriteStore(), bootstrapFileStore: BootstrapFileStore()))
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
                .environment(videoVorrat)
                #if DEBUG
                .sensorInstallieren(sensorAufnahme, zaehler: satzZaehler)
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
    func sensorInstallieren(_ koordinator: SensorAufnahmeKoordinator, zaehler: ZaehlerKoordinator) -> some View {
        environment(koordinator).environment(zaehler).task {
            // Zaehler zuerst: verbindet der Aufnahme-Koordinator beim Start
            // den gemerkten Sensor, soll der Zaehler die Kante schon hoeren.
            zaehler.starten()
            koordinator.starten()
        }
    }
    #endif
}
