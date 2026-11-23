import SwiftUI

/// Kleines Etikett mit dem Geraetetyp neben einem Uebungsnamen ("Kurzhantel").
/// Uebungsnamen nennen das Geraet nicht mehr (docs/katalog-stilleitfaden.md);
/// ohne das Etikett waeren "Bankdrücken" an Lang- und Kurzhantel nicht zu
/// unterscheiden.
struct GeraetEtikett: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(Capsule())
    }
}
