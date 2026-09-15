import SwiftUI

/// "Angabe entfernen" / "Ziel aufgeben" -- gen.py `ROT`: 52 pt, Radius 14,
/// Umriss in `danger` bei 45 % Deckkraft, Text `danger`. Wie
/// `SecondaryButton` keine Flaeche: zaehlt nicht als die eine
/// Akzentflaeche des Screens (designsystem.md SS2), und Rot ist ohnehin
/// kein Akzent, sondern die Warnfarbe fuer eine zerstoerende Aktion.
struct DangerOutlineButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(DesignSystem.Color.danger)
                } else {
                    Text(title).font(.system(size: 16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .foregroundStyle(DesignSystem.Color.danger)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.danger.opacity(0.45), lineWidth: 1)
        )
        .buttonStyle(PressButtonStyle())
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        DangerOutlineButton(title: "Angabe entfernen") {}
        DangerOutlineButton(title: "Ziel aufgeben", isLoading: true) {}
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
