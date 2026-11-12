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

// Die Tagesliste des Plan-Tabs ist den Wochenkarten gewichen
// (`PlanWochenKarten.swift`, Spec P2 §3). Was hier bleibt, nutzt Home noch
// (`NaechsteEinheitKarte`, `HomeSerieView`); Task 13 raeumt auf.

/// Die kurze Zeile fuer einen Kurs oder Cardio-Termin mit Tag: Kaestchen,
/// Titel, Tag. "Als nächstes" im Plan-Tab und "Nächste Einheit" auf Home.
struct PlanTerminZeile: View {
    let kaestchen: AnyView
    let titel: String
    let tag: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            kaestchen
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(titel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(tag)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

struct PlanCardioKaestchen: View {
    var body: some View {
        Image(systemName: "waveform.path.ecg")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.text)
            .frame(width: 40, height: 40)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct PlanKursKaestchen: View {
    var body: some View {
        Image(systemName: "person.3")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .frame(width: 40, height: 40)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
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
