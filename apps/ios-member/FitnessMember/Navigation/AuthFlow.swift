import SwiftUI

struct AuthFlow: View {
    var body: some View {
        NavigationStack {
            LoginMailView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .register: MemberRegistrierenView()
                    case .password: MemberPasswortView()
                    }
                }
        }
        .tint(DesignSystem.Color.accent)
    }
}
