import SwiftUI

enum BannerTone {
    case accent, muted, danger

    var foreground: SwiftUI.Color {
        switch self {
        case .accent: DesignSystem.Color.accent
        case .muted: DesignSystem.Color.textMuted
        case .danger: DesignSystem.Color.danger
        }
    }

    var border: SwiftUI.Color {
        switch self {
        case .accent: DesignSystem.Color.accent.opacity(0.33)
        case .muted: DesignSystem.Color.line
        case .danger: DesignSystem.Color.danger.opacity(0.5)
        }
    }
}

struct InlineBanner: View {
    let tone: BannerTone
    let message: String
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon {
                Image(systemName: icon).foregroundStyle(tone.foreground)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(tone.border, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        InlineBanner(tone: .accent, message: "Beinpresse erkannt", icon: "wave.3.right")
        InlineBanner(tone: .danger, message: "E-Mail oder Passwort stimmt nicht.")
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
