import SwiftUI

/// "<Name> heute machen?" (Entwurf 3b, E9): eine spaetere Einheit vorziehen.
/// Das Blatt nennt den Nachfolger in der Folge ("Danach: <Name>"), nicht
/// einen verschobenen Wochentag -- bei drei Einheiten waere der falsch.
///
/// Das Vorziehen selbst macht der Aufrufer: `beiStarten` liefert false, wenn
/// gerade eine Einheit an einer Session haengt; dann steht der Hinweis hier
/// im Blatt, statt dass es still zugeht.
struct TrainingVorziehenSheet: View {
    let name: String
    let danach: String
    let beiStarten: () -> Bool
    let beiAbbrechen: () -> Void

    @State private var hinweis: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                Text("\(name) heute machen?")
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Dein Plan läuft in Reihenfolge.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DesignSystem.Spacing.s8) {
                Text("DANACH")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.2)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(danach)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.s12)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Danach: \(danach)")
            if let hinweis {
                InlineBanner(tone: .danger, message: hinweis)
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "\(name) starten") {
                if !beiStarten() { hinweis = "Gerade läuft schon eine Einheit." }
            }
            .testnotizElement("training.vorziehen.start", typ: "PrimaryButton")
            PlanLeiserKnopf(titel: "Abbrechen", aktion: beiAbbrechen)
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, DesignSystem.Spacing.s8)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Color.surface)
    }
}
