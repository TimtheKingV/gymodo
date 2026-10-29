import SwiftUI

struct MainTabView: View {
    let apiClient: APIClient

    @Environment(PendingTagStore.self) private var pendingTag

    /// Reine Tab-Auswahl. SwiftUI ruft .onAppear/.task fuer einen nicht
    /// ausgewaehlten Tab beim ersten Aufbau NICHT auf -- ohne diese Auswahl
    /// bliebe der ueber Universal Link erfasste Token unerreichbar, bis das
    /// Mitglied von Hand auf "Training" tippt, und der Kalteinstieg
    /// (M1-Spec SS8.1 Schritt 3) waere gebrochen.
    @State private var ausgewaehlterTab = 0

    /// Der typisierte Pfad des Plan-Tabs, wie `pfad` in TrainingRootView
    /// fuer GeraetRoute -- Kursdetail und Einheit sind Pushes und behalten
    /// die Tab-Leiste, statt eigene Tabs zu sein.
    @State private var planPfad: [KursRoute] = []
    /// Der Tag, auf den der Plan-Tab springen soll (von Home, "Als nächstes").
    @State private var planTagWunsch: Date?

    var body: some View {
        TabView(selection: $ausgewaehlterTab) {
            HomeRootView(
                apiClient: apiClient,
                beiTrainingZeigen: { ausgewaehlterTab = 1 },
                beiPlanZeigen: planZeigen)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            TrainingRootView(apiClient: apiClient)
                .tabItem { Label("Training", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            NavigationStack(path: $planPfad) {
                PlanRootView(
                    apiClient: apiClient,
                    beiKurs: { sessionId in planPfad.append(.detail(sessionId: sessionId)) },
                    beiEinheit: { key in planPfad.append(.einheit(key: key)) },
                    beiTrainingStarten: trainingZeigen,
                    tagWunsch: $planTagWunsch)
                .navigationDestination(for: KursRoute.self) { route in
                    switch route {
                    case .detail(let sessionId):
                        KursDetailView(sessionId: sessionId)
                    case .einheit(let key):
                        PlanEinheitView(einheitKey: key, beiTrainingStarten: trainingZeigen)
                    }
                }
            }
            .tabItem { Label("Plan", systemImage: "calendar") }
            .tag(2)

            NavigationStack { ProfilRootView(apiClient: apiClient) }
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(DesignSystem.Color.accent)
        // EIN Ausloeser fuer beide Faelle: .task(id:) laeuft beim ERSCHEINEN
        // (Kalteinstieg -- der Eingang liegt schon vor dem ersten Aufbau
        // dieser View vor, onOpenURL kommt vor dem Bootstrap-Ladevorgang)
        // UND bei jeder spaeteren Aenderung (die App laeuft schon auf einem
        // anderen Tab, ein weiterer Tag kommt herein).
        //
        // Vorher standen dafuer .onAppear und .onChange nebeneinander. Das
        // .onAppear war die schwache Stelle: eine TabView-Auswahl im eigenen
        // onAppear zu setzen faellt in SwiftUI gelegentlich unter den Tisch,
        // weil die TabView zu dem Zeitpunkt noch eingehaengt wird. .task
        // laeuft eine Runde spaeter, wenn sie steht.
        .task(id: pendingTag.eingang) {
            guard pendingTag.istOffen else { return }
            TagProtokoll.log.info("Tab-Wechsel auf Training wegen offenem Tag-Eingang")
            ausgewaehlterTab = 1
        }
    }

    /// "Training starten" aus dem Plan: dort fuehrt die Plankarte die Einheit.
    /// Der Plan-Pfad springt zurueck, damit der Tab beim naechsten Besuch
    /// wieder auf der Woche steht.
    private func trainingZeigen() {
        planPfad.removeAll()
        ausgewaehlterTab = 1
    }

    /// Von Home in den Plan (Leinwand 2d): die Woche, eine Einheit (derselbe
    /// Push wie ein Tipp im Plan) oder ein Tag. Der Pfad beginnt jedes Mal neu,
    /// sonst laege die Einheit ueber einem alten Kursdetail.
    private func planZeigen(_ sprung: PlanSprung) {
        switch sprung {
        case .woche:
            planPfad.removeAll()
        case .einheit(let key):
            planPfad = [.einheit(key: key)]
        case .tag(let tag):
            planPfad.removeAll()
            planTagWunsch = tag
        }
        ausgewaehlterTab = 2
    }
}
