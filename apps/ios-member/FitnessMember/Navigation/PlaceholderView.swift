import SwiftUI

/// Steht fuer Home/Training/Kurse, bis die jeweiligen Folge-Sub-Projekte sie
/// fuellen (Design-Spec SS2 -- nicht Teil dieses Sub-Projekts).
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack {
            Text(title.uppercased()).font(DesignSystem.Typography.screentitel)
            Text("Kommt mit einem Folge-Sub-Projekt.")
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
    }
}
