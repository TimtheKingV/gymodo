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

    /// Der typisierte Pfad des Kurse-Tabs, wie `pfad` in TrainingRootView
    /// fuer GeraetRoute -- KursDetail und KurseMeine sind Pushes und
    /// behalten die Tab-Leiste, statt eigene Tabs zu sein.
    @State private var kursePfad: [KursRoute] = []

    var body: some View {
        TabView(selection: $ausgewaehlterTab) {
            HomeRootView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            TrainingRootView(apiClient: apiClient)
                .tabItem { Label("Training", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            NavigationStack(path: $kursePfad) {
                KurseWochenView(
                    beiAuswahl: { termin in kursePfad.append(.detail(sessionId: termin.id)) },
                    beiMeineKurse: { kursePfad.append(.meine) }
                )
                .navigationDestination(for: KursRoute.self) { route in
                    switch route {
                    case .detail(let sessionId):
                        KursDetailView(sessionId: sessionId)
                    case .meine:
                        KurseMeineView(beiAuswahl: { sessionId in kursePfad.append(.detail(sessionId: sessionId)) })
                    }
                }
            }
            .tabItem { Label("Kurse", systemImage: "calendar") }
            .tag(2)

            NavigationStack { ProfilRootView() }
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(DesignSystem.Color.accent)
        // Der Kalteinstieg: der Token liegt schon vor dem ersten Aufbau
        // dieser View vor (onOpenURL laeuft vor dem Bootstrap-Ladevorgang).
        .onAppear { if pendingTag.token != nil { ausgewaehlterTab = 1 } }
        // Der warme Fall: die App laeuft schon auf einem anderen Tab, und
        // ein weiterer Universal Link kommt herein.
        .onChange(of: pendingTag.token) { _, neu in
            if neu != nil { ausgewaehlterTab = 1 }
        }
    }
}
