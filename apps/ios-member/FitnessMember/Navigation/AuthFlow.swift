import SwiftUI

struct AuthFlow: View {
    let apiClient: APIClient

    var body: some View {
        NavigationStack {
            LoginMailView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .register: MemberRegistrierenView(apiClient: apiClient)
                    case .password: MemberPasswortView()
                    }
                }
        }
        .tint(DesignSystem.Color.accent)
    }
}
