import SwiftUI

/// Linearer Balken, kein Spinner -- er zeigt Restdauer, nicht
/// Beschaeftigung (designsystem.md SS6).
///
/// Reduce Motion faellt hier von selbst richtig: die Sekundenschritte
/// kommen ohnehin diskret aus TimelineView, nur die Interpolation dazwischen
/// entfaellt. Genau das meint "der Balken springt dann sekundenweise".
struct ResttimerBalken: View {
    let timer: Resttimer
    let beiVerlaengern: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("PAUSE · \(Int(Resttimer.dauer)) S")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { zeit in
                    Text(uhrzeit(timer.restsekunden(jetzt: zeit.date)))
                        .font(DesignSystem.Typography.wertSekundaer)
                        .foregroundStyle(DesignSystem.Color.text)
                }
            }

            balken
                .frame(height: 4)

            HStack {
                Text("Läuft weiter, auch wenn du wegsiehst.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Spacer()
                Button("+30 s", action: beiVerlaengern)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(height: 44)
                    .background(DesignSystem.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel("Pause um 30 Sekunden verlängern")
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // .contain, nicht .combine: "+30 s" bleibt als eigener Button
        // erreichbar, statt in einem Gesamttext der Karte zu verschwinden.
        .accessibilityElement(children: .contain)
    }

    /// Zwei Takte statt einem: der sichtbare Fortschritt laeuft sekuendlich,
    /// die VoiceOver-Ansage auf einem eigenen 15-Sekunden-Takt (SS12) --
    /// eine 1:1-Kopplung an die sekuendliche Anzeige waere unbenutzbar.
    /// Der Balken traegt sonst keinen Accessibility-Inhalt und ist damit
    /// ein echtes, erreichbares Element fuer die Ansage -- kein 1x1-Trick.
    private var balken: some View {
        TimelineView(.periodic(from: .now, by: 15)) { langsam in
            TimelineView(.periodic(from: .now, by: 1)) { schnell in
                GeometryReader { rahmen in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(DesignSystem.Color.line)
                        Rectangle()
                            .fill(DesignSystem.Color.accent)
                            .frame(width: rahmen.size.width * timer.anteil(jetzt: schnell.date))
                            .animation(reduceMotion ? nil : .linear(duration: 1),
                                       value: timer.anteil(jetzt: schnell.date))
                    }
                }
                .clipShape(Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pause")
            .accessibilityValue(timer.gesprochen(langsam.date))
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func uhrzeit(_ sekunden: Int) -> String {
        String(format: "%02d:%02d", sekunden / 60, sekunden % 60)
    }
}

#Preview {
    ResttimerBalken(timer: Resttimer(), beiVerlaengern: {})
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
}
