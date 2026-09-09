import SwiftUI

struct LoginCodeView: View {
    let email: String
    let apiClient: APIClient

    @Environment(SessionStore.self) private var sessionStore
    @State private var code = CodeEntry()
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var secondsUntilResend = 60

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("E-MAIL BESTÄTIGEN").font(DesignSystem.Typography.screentitel)
                (Text("Code gesendet an ") + Text(email).foregroundColor(DesignSystem.Color.text).fontWeight(.semibold))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }

            CodeDigitsView(entry: $code)

            if secondsUntilResend > 0 {
                Label("Neuen Code anfordern in \(formattedCountdown)", systemImage: "clock")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            } else {
                Button("Neuen Code anfordern") {
                    Task {
                        await sessionStore.resendSignupCode(email: email)
                        secondsUntilResend = 60
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            }

            if let errorMessage {
                InlineBanner(tone: .danger, message: errorMessage)
            }

            InlineBanner(
                tone: .muted,
                message: "Keine Mail bekommen? Sieh im Spam-Ordner nach. Der Code ist eine Stunde gültig.",
                icon: "envelope"
            )

            Spacer()

            PrimaryButton(
                title: "Bestätigen",
                isEnabled: code.isComplete,
                isLoading: isSubmitting,
                disabledHint: code.isComplete ? nil : "Noch \(code.remaining) Ziffern"
            ) {
                await submit()
            }
        }
        .padding(28)
        .background(DesignSystem.Color.bg)
        .onReceive(timer) { _ in
            if secondsUntilResend > 0 { secondsUntilResend -= 1 }
        }
        .onChange(of: code.isComplete) { _, complete in
            if complete { Task { await submit() } }
        }
    }

    private var formattedCountdown: String {
        String(format: "%02d:%02d", secondsUntilResend / 60, secondsUntilResend % 60)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await sessionStore.verifySignupCode(email: email, code: code.digits)
            await sessionStore.vorgemerktenNamenSchreiben { name in
                _ = try await apiClient.setDisplayName(name)
            }
        } catch {
            errorMessage = AuthCopy.codeUngueltig
        }
    }
}
