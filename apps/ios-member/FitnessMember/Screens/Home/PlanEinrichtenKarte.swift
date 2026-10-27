import SwiftUI

/// Entwurf 1.5: die Karte "Dein Trainingsplan" fuer Bestandsmitglieder --
/// erscheint nach dem Onboarding im aktiven Studio, solange dort kein Plan
/// steht (`PlanEinrichten.zeigtKarte`). Die Aktion ist ein Umriss: Home
/// hat seine eine Akzentflaeche schon.
///
/// Das Sheet haelt der Aufrufer (`HomeRootView`), nicht die Karte: nach
/// "Plan übernehmen" laedt der Flow den Bootstrap neu, die Karte
/// verschwindet damit -- ein Sheet an ihr wuerde mitten im Schliessen aus
/// der Hierarchie fallen.
struct PlanEinrichtenKarte: View {
    let beiOeffnen: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("NEU")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text("Dein Trainingsplan")
                    .font(.system(size: 19, weight: .black))
                    .tracking(-0.4)
                    .foregroundStyle(DesignSystem.Color.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Sag uns Zeit und Erfahrung, den Rest wissen wir schon. Dauert etwa zwei Minuten.")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(title: "Plan einrichten") { beiOeffnen() }
                    .accessibilityHint("Öffnet die Fragen zu deinem Trainingsplan")
            }
            .padding(DesignSystem.Spacing.s16)
        }
    }
}

#Preview {
    PlanEinrichtenKarte {}
        .padding(20)
        .background(DesignSystem.Color.bg)
}
