import SwiftUI

/// Nebenaktion, Umriss statt Flaeche -- zaehlt nicht als die eine
/// Akzentflaeche des Screens (designsystem.md SS2).
struct SecondaryButton: View {
    let title: String
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .foregroundStyle(DesignSystem.Color.text)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }
}

#Preview {
    SecondaryButton(title: "Gewicht ändern") {}
        .padding()
        .background(DesignSystem.Color.bg)
}
