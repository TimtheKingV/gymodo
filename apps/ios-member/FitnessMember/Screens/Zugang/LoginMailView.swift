import SwiftUI

struct LoginMailView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PendingTagStore.self) private var pendingTagStore
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if pendingTagStore.token != nil {
                    InlineBanner(
                        tone: .accent,
                        message: "Melde dich an — danach landest du direkt bei diesem Gerät.",
                        icon: "wave.3.right"
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("ANMELDEN").font(DesignSystem.Typography.screentitel)
                    Text("Mit E-Mail und Passwort.").foregroundStyle(DesignSystem.Color.textMuted)
                }

                LabeledField(label: "E-Mail-Adresse") {
                    TextField("name@beispiel.de", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledField(label: "Passwort") {
                    SecureField("••••••••••", text: $password)
                }

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                PrimaryButton(title: "Anmelden", isEnabled: !email.isEmpty && !password.isEmpty, isLoading: isSubmitting) {
                    await submit()
                }
                HStack(spacing: 10) {
                    NavigationLink("Passwort vergessen", value: AuthRoute.password)
                    Circle().fill(DesignSystem.Color.line).frame(width: 3, height: 3)
                    NavigationLink("Konto anlegen", value: AuthRoute.register)
                }
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await sessionStore.signIn(email: email, password: password)
        } catch {
            errorMessage = AuthCopy.unbekanntOderFalsch
        }
    }
}
