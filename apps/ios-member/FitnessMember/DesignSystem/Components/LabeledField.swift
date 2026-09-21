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

extension Text {
    /// Platzhalter fuer `TextField("", text:prompt:)`.
    ///
    /// Ohne `prompt` setzt iOS den Platzhalter in seinem eigenen Blau -- eine
    /// Farbe, die in diesem Design sonst nirgends vorkommt und auf dem
    /// Anmeldebildschirm neben dem gruenen Cursor stand (Testnotiz 21.09.,
    /// Eintraege 1 und 2). Als Text-Fabrik statt als View-Modifier, weil
    /// `prompt:` einen `Text` verlangt und die Farbe deshalb im `Text`
    /// selbst sitzen muss.
    static func platzhalter(_ inhalt: String) -> Text {
        Text(inhalt).foregroundColor(DesignSystem.Color.accentDim)
    }
}

#Preview {
    LabeledField(label: "E-Mail-Adresse") {
        TextField("", text: .constant(""), prompt: Text.platzhalter("name@beispiel.de"))
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
