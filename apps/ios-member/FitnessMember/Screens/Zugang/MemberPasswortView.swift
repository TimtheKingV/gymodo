import SwiftUI

struct MemberPasswortView: View {
    @Environment(SessionStore.self) private var sessionStore

    @State private var requestEmail = ""
    @State private var resetEmail = ""
    @State private var code = CodeEntry()
    @State private var newPassword = ""
    @State private var repeatPassword = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canReset: Bool {
        EmailValidator.isValid(resetEmail)
            && code.isComplete
            && PasswordPolicy.isValid(newPassword)
            && newPassword == repeatPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PASSWORT").font(DesignSystem.Typography.screentitel)
                    Text("Fordere einen Code an, oder setze ein neues Passwort, wenn du schon einen hast.")
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("VERGESSEN").font(DesignSystem.Typography.label).foregroundStyle(DesignSystem.Color.textMuted)
                    LabeledField(label: "E-Mail-Adresse") {
                        TextField("name@beispiel.de", text: $requestEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button {
                        Task { await requestReset() }
                    } label: {
                        Label("Code anfordern", systemImage: "lock")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .disabled(!EmailValidator.isValid(requestEmail))
                    Text(AuthCopy.sicherheitshinweisPasswortVergessen)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }

                Divider().background(DesignSystem.Color.line)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ZURÜCKSETZEN").font(DesignSystem.Typography.label).foregroundStyle(DesignSystem.Color.textMuted)
                    LabeledField(label: "E-Mail-Adresse") {
                        TextField("name@beispiel.de", text: $resetEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Code".uppercased())
                            .font(DesignSystem.Typography.label)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        CodeDigitsView(entry: $code)
                    }
                    LabeledField(label: "Neues Passwort") {
                        SecureField("••••••••••", text: $newPassword)
                    }
                    LabeledField(label: "Wiederholen") {
                        SecureField("••••••••••", text: $repeatPassword)
                    }
                }

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }

                PrimaryButton(title: "Passwort speichern", isEnabled: canReset, isLoading: isSaving) {
                    await save()
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
    }

    private func requestReset() async {
        await sessionStore.requestPasswordReset(email: requestEmail)
        if resetEmail.isEmpty { resetEmail = requestEmail }
    }

    private func save() async {
        guard newPassword == repeatPassword else {
            errorMessage = AuthCopy.passwoerterStimmenNichtUeberein
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await sessionStore.resetPassword(email: resetEmail, code: code.digits, newPassword: newPassword)
        } catch {
            errorMessage = AuthCopy.codeUngueltig
        }
    }
}
