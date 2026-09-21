import SwiftUI

/// Schritt 2 von 3 des Passwort-Zuruecksetzen-Flows: der sechsstellige Code
/// aus der Mail, und sonst nichts.
///
/// Vorher stand hier der Code zusammen mit dem neuen Passwort auf einem
/// Screen (Testnotiz 21.09., Eintrag 3). Das mischte zwei Dinge, die nicht
/// zusammengehoeren: der Code beantwortet "bist du das?", das Passwort
/// "was soll ab jetzt gelten?". Getrennt kann jeder Schritt fuer sich
/// scheitern und fuer sich gemeldet werden -- ein abgelaufener Code faellt
/// hier auf, nicht erst nachdem jemand ein neues Passwort getippt hat.
///
/// Wird ausschliesslich von `MemberPasswortView` gepusht -- die E-Mail-
/// Adresse kommt fest von dort, kein eigenes Feld.
struct MemberPasswortCodeView: View {
    let email: String

    @Environment(SessionStore.self) private var sessionStore

    @State private var code = CodeEntry()
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var codeGeprueft = false
    @State private var secondsUntilResend = 60

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("CODE EINGEBEN").font(DesignSystem.Typography.screentitel)
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
                        await sessionStore.requestPasswordReset(email: email)
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
                title: "Weiter",
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
        // Sechs Ziffern sind der ganze Screen -- wer sie getippt hat, hat
        // alles gesagt und soll nicht noch auf "Weiter" tippen muessen
        // (gleiches Verhalten wie LoginCodeView).
        .onChange(of: code.isComplete) { _, complete in
            if complete { Task { await submit() } }
        }
        .navigationDestination(isPresented: $codeGeprueft) {
            MemberPasswortNeuView(email: email)
        }
        .testnotizScreen()
    }

    private var formattedCountdown: String {
        String(format: "%02d:%02d", secondsUntilResend / 60, secondsUntilResend % 60)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await sessionStore.verifyPasswordResetCode(email: email, code: code.digits)
            codeGeprueft = true
        } catch {
            errorMessage = AuthCopy.codeUngueltig
        }
    }
}
