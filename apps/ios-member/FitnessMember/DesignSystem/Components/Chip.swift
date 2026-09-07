import SwiftUI

/// Chip ist ausschliesslich Umriss, auch im aktiven Zustand -- eine gefuellte
/// Chip-Flaeche waere eine zweite Akzentflaeche (Design-Challenge-Review SS1.1).
struct Chip: View {
    let text: String
    var isActive: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
            .overlay(
                Capsule().stroke(isActive ? DesignSystem.Color.accent : DesignSystem.Color.line, lineWidth: 1)
            )
    }
}

#Preview {
    HStack {
        Chip(text: "Heute", isActive: true)
        Chip(text: "Woche")
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
