import SwiftUI

/// Bewusst minimal (Design-Spec SS7): das vollstaendige Profil.dc.html
/// (Produktgrenze-Text, RIR-Einstellung) kommt mit der Home/Profil-Spec
/// eines Folge-Sub-Projekts. Hier nur genug, um MemberPasswortAendernView
/// und MemberStudiosView aufzuhaengen.
struct ProfilRootView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        List {
            Section {
                if let email = sessionStore.session?.email {
                    Text(email)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.text)
                }
            }
            .listRowBackground(DesignSystem.Color.surface)

            Section {
                NavigationLink("Passwort ändern") { MemberPasswortAendernView() }
                NavigationLink("Studios") { MemberStudiosView() }
            }
            .listRowBackground(DesignSystem.Color.surface)

            Section {
                Button("Abmelden", role: .destructive) {
                    Task { await sessionStore.signOut() }
                }
            }
            .listRowBackground(DesignSystem.Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .navigationTitle("PROFIL")
    }
}
