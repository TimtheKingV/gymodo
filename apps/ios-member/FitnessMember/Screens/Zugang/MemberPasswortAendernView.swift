import SwiftUI

struct MemberPasswortAendernView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var repeatPassword = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canSubmit: Bool {
        !currentPassword.isEmpty && PasswordPolicy.isValid(newPassword) && newPassword == repeatPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("PASSWORT ÄNDERN").font(DesignSystem.Typography.screentitel)

                LabeledField(label: "Aktuelles Passwort") {
                    SecureField("••••••••••", text: $currentPassword)
                }
                LabeledField(label: "Neues Passwort") {
                    SecureField("••••••••••", text: $newPassword)
                }
                LabeledField(label: "Wiederholen") {
                    SecureField("••••••••••", text: $repeatPassword)
                }

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Passwort speichern", isEnabled: canSubmit, isLoading: isSaving) {
                await save()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
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
            try await sessionStore.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            dismiss()
        } catch {
            errorMessage = AuthCopy.aktuellesPasswortFalsch
        }
    }
}
