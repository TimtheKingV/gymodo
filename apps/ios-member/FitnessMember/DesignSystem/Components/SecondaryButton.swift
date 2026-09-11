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
                // Die Hoehe ist fest: eine zweite Zeile waere abgeschnitten.
                // Betrifft die geteilten Zeilen (zwei Knoepfe nebeneinander)
                // und grosse Dynamic-Type-Stufen.
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, DesignSystem.Spacing.s8)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .foregroundStyle(DesignSystem.Color.text)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    SecondaryButton(title: "Gewicht ändern") {}
        .padding()
        .background(DesignSystem.Color.bg)
}
