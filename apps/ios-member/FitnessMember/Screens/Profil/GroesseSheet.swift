import SwiftUI

/// Die Stepper-Zeile aus Schritt 2 (`GroesseStepperZeile`,
/// OnboardingSchritte.swift) als eigenstaendiges Sheet -- derselbe
/// Bereich (100-250 cm), derselbe Startwert (170) beim ersten Tipp.
struct GroesseSheet: View {
    let bisher: Int?
    let speichern: (Int?) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var groesseCm: Int?
    @State private var fehler: String?
    @State private var laeuft = false

    init(bisher: Int?, speichern: @escaping (Int?) async -> String?) {
        self.bisher = bisher
        self.speichern = speichern
        _groesseCm = State(initialValue: bisher)
    }

    var body: some View {
        ScrollView {
            GroesseSheetInhalt(
                groesseCm: $groesseCm, fehler: fehler, laeuft: laeuft,
                uebernehmen: { await uebernehmen(groesseCm) }, entfernen: { await uebernehmen(nil) })
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s24)
                .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
    }

    private func uebernehmen(_ wert: Int?) async {
        laeuft = true
        fehler = await speichern(wert)
        laeuft = false
        if fehler == nil { dismiss() }
    }
}

/// Der Sheet-Inhalt ohne die `ScrollView`-Huelle -- derselbe Schnitt wie
/// `AuswahlSheetInhalt`/`GewichtEintragenInhalt` (Aufgabe 9/10), fuer die
/// Sichtpruefung ausserhalb jeder `ScrollView` instanziierbar.
struct GroesseSheetInhalt: View {
    @Binding var groesseCm: Int?
    let fehler: String?
    let laeuft: Bool
    let uebernehmen: () async -> Void
    let entfernen: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text("GRÖSSE")
                .font(.system(size: 22, weight: .black))
                .tracking(-0.4)
                .foregroundStyle(DesignSystem.Color.text)

            GroesseStepperZeile(groesseCm: $groesseCm)

            if let fehler {
                InlineBanner(tone: .danger, message: fehler)
            }

            VStack(spacing: DesignSystem.Spacing.s12) {
                PrimaryButton(title: "Übernehmen", isLoading: laeuft) {
                    await uebernehmen()
                }
                if groesseCm != nil {
                    DangerOutlineButton(title: "Angabe entfernen", isLoading: laeuft) {
                        await entfernen()
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.s8)
        }
    }
}

// MARK: - Vorschau

#Preview("Mit Angabe") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            GroesseSheet(bisher: 168, speichern: { _ in nil })
        }
}

#Preview("Ohne Angabe") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            GroesseSheet(bisher: nil, speichern: { _ in nil })
        }
}
