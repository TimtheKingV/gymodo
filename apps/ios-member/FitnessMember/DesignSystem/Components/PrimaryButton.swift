import SwiftUI

/// Hauptaktion, 64pt (designsystem.md SS4). Im deaktivierten Zustand steht
/// immer ein Hinweis daneben (SS5: "nie stumm") -- disabledHint ist deshalb
/// kein optionaler Zierrat, sondern soll bei isEnabled == false befuellt sein.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var disabledHint: String? = nil
    let action: () async -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button {
                Task { await action() }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(DesignSystem.Color.onAccent)
                    } else {
                        Text(title).font(.system(size: 19, weight: .heavy))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .foregroundStyle(isEnabled ? DesignSystem.Color.onAccent : DesignSystem.Color.textFaint)
            }
            .buttonStyle(HauptaktionButtonStyle(isEnabled: isEnabled))
            .disabled(!isEnabled || isLoading)

            if !isEnabled, let disabledHint {
                Text(disabledHint)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Anmelden") {}
        PrimaryButton(title: "Bestätigen", isEnabled: false, disabledHint: "Noch zwei Ziffern") {}
        PrimaryButton(title: "Anmelden", isLoading: true) {}
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
