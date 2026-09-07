import SwiftUI

/// Schritt 2 von 2 des Passwort-Zuruecksetzen-Flows: Code (aus der Mail) und
/// neues Passwort. Wird ausschliesslich von MemberPasswortView gepusht --
/// die E-Mail-Adresse kommt fest von dort, kein eigenes Feld, damit der
/// Zwei-Schritt-Fluss eindeutig bleibt. Zurueck-Navigation (Chevron/Wisch-
/// Geste) kommt automatisch vom NavigationStack, falls die Adresse falsch
/// war oder der Code abgelaufen ist.
struct MemberPasswortZuruecksetzenView: View {
    let email: String

    @Environment(SessionStore.self) private var sessionStore

    @State private var code = CodeEntry()
    @State private var newPassword = ""
    @State private var repeatPassword = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canSave: Bool {
        code.isComplete
            && PasswordPolicy.isValid(newPassword)
            && newPassword == repeatPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CODE EINGEBEN").font(DesignSystem.Typography.screentitel)
                    (Text("Code gesendet an ") + Text(email).foregroundColor(DesignSystem.Color.text).fontWeight(.semibold))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
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

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Passwort speichern", isEnabled: canSave, isLoading: isSaving) {
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
            try await sessionStore.resetPassword(email: email, code: code.digits, newPassword: newPassword)
        } catch {
            errorMessage = AuthCopy.codeUngueltig
        }
    }
}
