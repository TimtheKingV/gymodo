import SwiftUI

/// Ein Hinweis, der von selbst geht (Testnotiz 11.10., #8). Der Zeitpunkt
/// gehoert dazu: zweimal derselbe Satz hintereinander ist ein neuer
/// Hinweis, und sein Ablauf beginnt von vorn.
struct Toastmeldung: Equatable {
    static let anzeigedauer: TimeInterval = 3

    let text: String
    let ab: Date

    init(text: String, ab: Date = .now) {
        self.text = text
        self.ab = ab
    }

    var endetAm: Date { ab.addingTimeInterval(Self.anzeigedauer) }

    func sichtbar(jetzt: Date) -> Bool { jetzt < endetAm }
}

/// Der kurze Hinweis ueber den Scan-Knoepfen. Ersetzt dort das stehende
/// InlineBanner fuer Rueckmeldungen, die nur einen Moment brauchen: ein
/// Banner, das bis zum Verlassen des Tabs stand, las sich wie ein Problem.
///
/// Ein Tipp schliesst ihn frueher. VoiceOver liest ihn beim Erscheinen
/// vor -- sonst ginge er ungehoert vorbei.
struct Toast: View {
    let meldung: Toastmeldung
    let beiSchliessen: () -> Void

    var body: some View {
        Text(meldung.text)
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .padding(.vertical, DesignSystem.Spacing.s12)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: beiSchliessen)
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                AccessibilityNotification.Announcement(meldung.text).post()
            }
            // Ablauf an die Meldung gebunden: ein neuer Hinweis setzt die
            // Uhr neu, statt mit dem Rest des alten zu verschwinden.
            .task(id: meldung) {
                let rest = meldung.endetAm.timeIntervalSinceNow
                if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
                guard !Task.isCancelled else { return }
                beiSchliessen()
            }
    }
}
