import SwiftUI

struct MemberRegistrierenView: View {
    @Environment(SessionStore.self) private var sessionStore
    let apiClient: APIClient
    @State private var vorname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var didRequireConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("KONTO ANLEGEN").font(DesignSystem.Typography.screentitel)
                    Text("Für dein Studio brauchst du ein Konto.").foregroundStyle(DesignSystem.Color.textMuted)
                }

                LabeledField(label: "Vorname") {
                    TextField("Dein Vorname", text: $vorname)
                        .textContentType(.givenName)
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
                Text("Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Konto anlegen",
                    isEnabled: EmailValidator.isValid(email) && PasswordPolicy.isValid(password),
                    isLoading: isSubmitting
                ) {
                    await submit()
                }
                Text("Danach schicken wir dir einen Code zur Bestätigung.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
        .navigationDestination(isPresented: $didRequireConfirmation) {
            LoginCodeView(email: email, apiClient: apiClient)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        sessionStore.nameVormerken(vorname)
        do {
            let gotImmediateSession = try await sessionStore.signUp(email: email, password: password)
            if gotImmediateSession {
                // Ohne Bestaetigungspflicht (Supabase mit abgeschalteter
                // E-Mail-Bestaetigung) landet das Mitglied direkt hier --
                // LoginCodeView, der einzige bisherige Konsument des
                // vorgemerkten Namens, wird auf diesem Weg nie erreicht.
                await sessionStore.vorgemerktenNamenSchreiben { name in
                    _ = try await apiClient.setDisplayName(name)
                }
            } else {
                didRequireConfirmation = true
            }
        } catch {
            errorMessage = AuthCopy.unbekanntOderFalsch
        }
    }
}
