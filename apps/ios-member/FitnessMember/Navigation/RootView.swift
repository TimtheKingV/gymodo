import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var catalogStore
    @Environment(WorkoutSessionStore.self) private var workoutStore
    @Environment(KurseStore.self) private var kurseStore
    @Environment(VerlaufStore.self) private var verlaufStore

    let apiClient: APIClient

    /// Merkt sich, ob ueberhaupt schon eine Session da war. Ohne dieses Flag
    /// wuerde der erste Lauf von .task(id:) beim Start -- da ist die Session
    /// noch nil, restoreSession() laeuft parallel -- den persistierten
    /// Katalogzustand faelschlich als "Abmeldung" verwerfen.
    @State private var hatteSession = false
    /// Wird nach 3 s im Ladeschirm wahr (Offline-Spec 2).
    @State private var verbindungLangsam = false

    var body: some View {
        // Nur aussagekraeftig bei geladenem Bootstrap -- destination(...)
        // fragt onboardingOffen ohnehin nur im .loaded-Zweig ab, deshalb
        // darf der Wert hier grob (nil == "offen") berechnet werden.
        let onboardingOffen = catalogStore.bootstrap?.member.onboardingCompletedAt == nil
        let destination = RootDestinationLogic.destination(
            session: sessionStore.session, catalogState: catalogStore.loadState,
            onboardingOffen: onboardingOffen,
            wiederhergestellt: sessionStore.wiederhergestellt)

        Group {
            switch destination {
            case .authFlow:
                AuthFlow(apiClient: apiClient)
            // Zwei Gruende, derselbe Bildschirm: beim Kaltstart wissen wir
            // die Anmeldung noch nicht, danach den Katalog noch nicht.
            // Beide Male laeuft etwas, und beide Male ist das Einzige, was
            // die App ehrlich sagen kann, genau das.
            case .start, .loadingCatalog:
                ladeschirm
            case .onboarding:
                OnboardingFlow(apiClient: apiClient, alsSheet: false) { }
            case .ladefehler:
                NavigationStack { MemberLadefehlerView() }
                    .tint(DesignSystem.Color.accent)
            case .main:
                MainTabView(apiClient: apiClient)
            }
        }
        // RootView haelt beide Stores bereits und reagiert ohnehin auf
        // Session-Wechsel -- der Reset gehoert deshalb hierher und nicht in
        // SessionStore, das sonst eine neue Abhaengigkeit auf CatalogStore
        // bekaeme.
        .task(id: sessionStore.session) {
            if let session = sessionStore.session {
                hatteSession = true
                // Erst anmelden: ohne Bootstrap im Speicher steht der
                // gespeicherte sofort da (Offline-Spec 3a). Kam er aus dem
                // Cache, wird trotzdem nachgeladen -- er kann Stunden alt sein.
                let ausCache = catalogStore.anmelden(userId: session.userId)
                // Nicht nur .idle: auch nach .failed muss ein neuer Anlauf
                // moeglich sein. Aber auch nicht mehr als das: ein
                // Passwortwechsel liefert eine neue Session (neuer
                // Access-Token) fuer denselben Nutzer und wuerde sonst bei
                // bereits geladenem Katalog (.loaded) einen unnoetigen
                // Neuladevorgang ausloesen.
                if ausCache || catalogStore.loadState == .idle || catalogStore.loadState == .failed {
                    await catalogStore.load()
                }
            } else if hatteSession {
                hatteSession = false
                catalogStore.reset()
                // Die laufende Einheit faellt beim Abmelden -- ihre
                // Kennungen gehoeren zum abgemeldeten Konto.
                workoutStore.reset()
                // Dieselbe Begruendung: die Kursbuchungen des vorigen
                // Kontos duerfen dem naechsten weder im Speicher noch auf
                // der Platte erscheinen.
                kurseStore.reset()
                // Und derselbe Grund ein drittes Mal: der Trainingsverlauf
                // des vorigen Kontos darf dem naechsten weder im Speicher
                // noch auf der Platte erscheinen.
                verlaufStore.reset()
            }
        }
    }

    private var ladeschirm: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            ProgressView()
                .tint(DesignSystem.Color.accent)
            // Nach 3 s ein ehrlicher Satz statt eines stummen Spinners
            // (Offline-Spec 2).
            if verbindungLangsam {
                Text("Verbindung ist langsam …")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
        .task {
            try? await Task.sleep(for: .seconds(3))
            verbindungLangsam = true
        }
        .testnotizScreen()
    }
}
