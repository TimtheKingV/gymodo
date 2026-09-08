import SwiftUI

/// Press-Feedback fuer jeden Button der App.
///
/// Die Design-Challenge fand, dass in der gesamten Canvas kein einziger
/// Button ein :active-Feedback hat -- und accentPressed war in Swift
/// definiert, aber unbenutzt. Einmal als ButtonStyle statt je Button, damit
/// die Abweichung strukturell unmoeglich wird statt nur unerwuenscht.
struct PressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion
                         ? DesignSystem.Motion.pressSkalierung : 1)
            .animation(reduceMotion ? nil : DesignSystem.Motion.press,
                       value: configuration.isPressed)
    }
}

/// Wie PressButtonStyle, zusaetzlich mit dem Farbwechsel der Hauptaktion.
struct HauptaktionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hintergrund(gedrueckt: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .scaleEffect(configuration.isPressed && !reduceMotion
                         ? DesignSystem.Motion.pressSkalierung : 1)
            .animation(reduceMotion ? nil : DesignSystem.Motion.press,
                       value: configuration.isPressed)
    }

    private func hintergrund(gedrueckt: Bool) -> Color {
        guard isEnabled else { return DesignSystem.Color.surfaceRaised }
        return gedrueckt ? DesignSystem.Color.accentPressed : DesignSystem.Color.accent
    }
}
