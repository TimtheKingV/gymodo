import SwiftUI

/// Eyebrow-Label (designsystem.md SS3 "Label"-Rolle) über einem 58pt hohen
/// Eingabefeld -- Standardform fuer alle Zugang-Screens.
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textMuted)
            content
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 17)
                .frame(height: 58)
                .background(DesignSystem.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                        .stroke(DesignSystem.Color.line, lineWidth: 1)
                )
        }
    }
}

#Preview {
    LabeledField(label: "E-Mail-Adresse") {
        TextField("name@beispiel.de", text: .constant(""))
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
