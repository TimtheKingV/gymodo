import SwiftUI
import UIKit

extension Color {
    /// Tokens aus designsystem.md §2 als 0xRRGGBB, z. B. Color(hex: 0xD4FF3F).
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Nur fuer Tests -- extrahiert die tatsaechlich gerenderten Komponenten
    /// ueber UIColor, um die Herleitung in init(hex:) unabhaengig zu pruefen.
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
