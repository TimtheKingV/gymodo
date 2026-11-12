import SwiftUI

/// Der kurze Schluessel im Kaestchen: "A", "OK A".
enum EinheitKuerzel {
    static func text(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
    }

    /// "6 Übungen · ca. 60 Min"
    static func untertitel(_ einheit: TrainingsplanEinheit) -> String {
        let n = einheit.positionen.count
        var teile = ["\(n) \(n == 1 ? "Übung" : "Übungen")"]
        if let min = einheit.geschaetzteMinuten { teile.append("ca. \(Int(min.rounded())) Min") }
        return teile.joined(separator: " · ")
    }
}

/// Die Marke unter einem Tag im Home-Streifen: gefuellter Punkt (Kraft),
/// Raute (Cardio), Ring (Kurs besucht) und gestrichelter Ring (Kurs gebucht)
/// -- Formen, nicht nur Farben. Geleistetes ist gedeckt, nichts ist rot.
struct PlanTagMarke: View {
    let marke: TagMarke

    var body: some View {
        Group {
            switch marke {
            case .kraft:
                Circle().fill(DesignSystem.Color.textFaint)
            case .kurs:
                Circle().strokeBorder(DesignSystem.Color.textMuted, lineWidth: 2)
            case .cardio:
                Rectangle()
                    .fill(DesignSystem.Color.textFaint)
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(45))
            case .kursGebucht:
                Circle().strokeBorder(
                    DesignSystem.Color.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            }
        }
        .frame(width: 8, height: 8)
    }
}
