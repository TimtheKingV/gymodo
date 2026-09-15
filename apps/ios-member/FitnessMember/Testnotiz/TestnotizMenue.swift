#if DEBUG
import SwiftUI

/// Ein eigenes Panel statt SwiftUI-Menu: dessen Eintraege laegen ausserhalb
/// des Knopfrahmens, und das durchlaessige Fenster liesse Tipps darauf zur
/// App durch. Im Modus .menue faengt das Fenster alles.
struct TestnotizMenue: View {
    private let testnotiz = Testnotiz.shared

    struct Eintrag: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let aktion: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.bg.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { testnotiz.zurRuhe() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(kopfzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(DesignSystem.Spacing.s16)

                if let fehler = testnotiz.letzterFehler {
                    Text(fehler)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.danger)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .padding(.bottom, DesignSystem.Spacing.s8)
                }

                ForEach(eintraege) { eintrag in
                    zeile(titel: eintrag.titel, symbol: eintrag.symbol, farbe: DesignSystem.Color.text, aktion: eintrag.aktion)
                }

                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                zeile(titel: "Schließen", symbol: "xmark", farbe: DesignSystem.Color.textMuted, aktion: testnotiz.zurRuhe)
            }
            .background(DesignSystem.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var kopfzeile: String {
        (testnotiz.entwurf?.screen?.name ?? "Testnotiz").uppercased()
    }

    private var eintraege: [Eintrag] {
        [
            Eintrag(id: "ausschnitt", titel: "Ausschnitt", symbol: "crop") { testnotiz.modus = .ausschnitt },
        ]
    }

    private func zeile(titel: String, symbol: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(farbe)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
