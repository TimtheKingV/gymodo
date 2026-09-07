import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { PlaceholderView(title: "Home") }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { PlaceholderView(title: "Training") }
                .tabItem { Label("Training", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack { PlaceholderView(title: "Kurse") }
                .tabItem { Label("Kurse", systemImage: "calendar") }

            NavigationStack { ProfilRootView() }
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .tint(DesignSystem.Color.accent)
    }
}
