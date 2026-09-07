import SwiftUI

/// Schritt 1 von 2 des Passwort-Zuruecksetzen-Flows: nur die E-Mail-Adresse
/// anfordern. Schritt 2 (Code + neues Passwort) ist ein eigener, gepushter
/// Screen (MemberPasswortZuruecksetzenView) -- das gibt eine echte
/// Zurueck-Navigation, falls die Adresse falsch war oder der Code
/// abgelaufen ist, statt beides auf einem Screen zu vermischen.
struct MemberPasswortView: View {
    @Environment(SessionStore.self) private var sessionStore

    @State private var requestEmail = ""
    @State private var didRequest = false
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PASSWORT").font(DesignSystem.Typography.screentitel)
                    Text("Fordere einen Code an, um dein Passwort zurückzusetzen.")
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                LabeledField(label: "E-Mail-Adresse") {
                    TextField("name@beispiel.de", text: $requestEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Text(AuthCopy.sicherheitshinweisPasswortVergessen)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: "Code anfordern",
                isEnabled: EmailValidator.isValid(requestEmail),
                isLoading: isRequesting
            ) {
                await requestReset()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
        .navigationDestination(isPresented: $didRequest) {
            MemberPasswortZuruecksetzenView(email: requestEmail)
        }
    }

    /// Schaltet unabhaengig vom tatsaechlichen Ergebnis weiter -- die
    /// Sicherheitsanforderung "gleiche Antwort, ob das Konto existiert oder
    /// nicht" gilt genauso fuer die Navigation wie fuer den Text.
    private func requestReset() async {
        isRequesting = true
        defer { isRequesting = false }
        await sessionStore.requestPasswordReset(email: requestEmail)
        didRequest = true
    }
}
