import SwiftUI

/// Reiner Werte-Namespace, keine Instanzen. Tokens 1:1 aus
/// docs/superpowers/specs/2026-08-30-designsystem.md SS2-4 -- Werte hier
/// aendern heisst das Dokument nachziehen, nicht umgekehrt.
enum DesignSystem {
    enum Color {
        static let bg = SwiftUI.Color(hex: 0x0A0B0D)
        static let surface = SwiftUI.Color(hex: 0x14161A)
        static let surfaceRaised = SwiftUI.Color(hex: 0x1D2026)
        static let line = SwiftUI.Color(hex: 0x2A2E36)
        static let text = SwiftUI.Color(hex: 0xF2F4F7)
        static let textMuted = SwiftUI.Color(hex: 0x9BA3AF)
        static let textFaint = SwiftUI.Color(hex: 0x5C636E)
        static let accent = SwiftUI.Color(hex: 0xD4FF3F)
        static let accentPressed = SwiftUI.Color(hex: 0xA8CC2A)
        static let onAccent = SwiftUI.Color(hex: 0x0A0B0D)
        static let warn = SwiftUI.Color(hex: 0xFFB020)
        static let danger = SwiftUI.Color(hex: 0xFF5A4E)
    }

    enum Spacing {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let s48: CGFloat = 48
    }

    enum Radius {
        static let card: CGFloat = 12
        static let neben: CGFloat = 14
        static let haupt: CGFloat = 16
        static let pille: CGFloat = 999
    }

    enum Typography {
        static let screentitel = Font.system(size: 32, weight: .black)
        static let wertHeld = Font.system(size: 64, weight: .black).monospacedDigit()
        static let label = Font.system(size: 11, weight: .heavy)
        static let body = Font.system(size: 16, weight: .regular)

        /// designsystem.md SS3: 30-34pt Black, Versalien, Tracking -2,5 %.
        static let geraetename = Font.system(size: 32, weight: .black)
        /// Zweite Titelrolle, in SessionDetail/Uebungsfortschritt belegt
        /// (Design-Challenge SS3.4 -- dort als nachzutragen vermerkt).
        static let detailScreentitel = Font.system(size: 28, weight: .black)
        static let uebungsname = Font.system(size: 17, weight: .semibold)
        static let wertSekundaer = Font.system(size: 19, weight: .black).monospacedDigit()
        static let fliesstext = Font.system(size: 15, weight: .regular)
        /// Nachbarn im Rad, designsystem.md SS7: 30pt und 26pt.
        static let radNah = Font.system(size: 30, weight: .black).monospacedDigit()
        static let radFern = Font.system(size: 26, weight: .black).monospacedDigit()
    }

    /// Die vier Momente, die wir selbst fahren. Momentum, Deceleration,
    /// Rubber-Banding und Unterbrechbarkeit kommen vom System-Scroller und
    /// stehen deshalb bewusst nicht hier (Spec Abschnitt 6).
    enum Motion {
        static let oeffnen = Animation.spring(response: 0.34, dampingFraction: 0.86)
        static let pause = Animation.spring(response: 0.4, dampingFraction: 0.9)
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.9)
        static let pressSkalierung: CGFloat = 0.97
    }
}
