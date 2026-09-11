import SwiftUI

/// Die Pause als Rad: ein Bogen, der sich fuellt, mit der Restdauer in
/// seiner Mitte.
///
/// Kein Spinner -- der Bogen ist determiniert und zeigt, wie weit die Pause
/// durch ist (designsystem.md SS6, der Grund des alten Balkens gilt
/// unveraendert). Die Form wechselt vom Balken zum Rad, weil die Pause den
/// Screen jetzt ganz uebernimmt statt als Band ueber ihm zu liegen: auf
/// einer leeren Flaeche ist ein Kreis mit Ziffern in der Mitte aus zwei
/// Metern Abstand lesbar, ein 4pt-Balken nicht.
///
/// Reduce Motion faellt hier von selbst richtig: die Sekundenschritte
/// kommen ohnehin diskret aus TimelineView, nur die Interpolation dazwischen
/// entfaellt -- der Bogen springt dann sekundenweise.
struct PausenRad: View {
    let timer: Resttimer
    let beiVerlaengern: () -> Void
    let beiWeiter: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Der gedrosselte Ansagetext (SS12). Ein eigener Task-Takt statt einer
    /// zweiten TimelineView, damit der Sekundentakt der sichtbaren Anzeige
    /// unangetastet bleibt.
    @State private var ansage: String

    /// Skaliert mit der Schriftgroesse: das Rad traegt Ziffern, und ein
    /// fester Durchmesser liesse sie bei grossen Dynamic-Type-Stufen aus
    /// dem Kreis laufen.
    @ScaledMetric(relativeTo: .body) private var durchmesser: CGFloat = 240
    @ScaledMetric(relativeTo: .body) private var strichstaerke: CGFloat = 12

    init(timer: Resttimer, beiVerlaengern: @escaping () -> Void, beiWeiter: @escaping () -> Void) {
        self.timer = timer
        self.beiVerlaengern = beiVerlaengern
        self.beiWeiter = beiWeiter
        _ansage = State(initialValue: timer.gesprochen())
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s32) {
            rad
            VStack(spacing: DesignSystem.Spacing.s12) {
                // "Weiter" ist die Hauptaktion dieses Zustands und damit die
                // eine Akzentflaeche des Screens (SS2) -- solange die Pause
                // laeuft, gibt es keine zweite.
                PrimaryButton(title: "Weiter") { beiWeiter() }
                    .accessibilityHint("Beendet die Pause und zeigt wieder die Räder")
                SecondaryButton(title: "+30 s", action: beiVerlaengern)
                    .accessibilityLabel("Pause um 30 Sekunden verlängern")
            }
            Text("Läuft weiter, auch wenn du wegsiehst.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.s24)
    }

    /// Eine einzige, ungeschachtelte TimelineView treibt Bogen UND Ziffern
    /// -- zwei Takte fuer denselben Sekundenwechsel liefen unweigerlich
    /// auseinander.
    private var rad: some View {
        TimelineView(.periodic(from: .now, by: 1)) { zeit in
            let fortschritt = timer.fortschritt(jetzt: zeit.date)
            ZStack {
                Circle()
                    .stroke(DesignSystem.Color.line, lineWidth: strichstaerke)
                Circle()
                    .trim(from: 0, to: fortschritt)
                    .stroke(DesignSystem.Color.accent,
                            style: StrokeStyle(lineWidth: strichstaerke, lineCap: .round))
                    // Bogenanfang oben statt rechts -- die Zwoelf ist die
                    // Stelle, an der eine Uhr anfaengt.
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: fortschritt)

                VStack(spacing: DesignSystem.Spacing.s4) {
                    Text("PAUSE")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                    Text(uhrzeit(timer.restsekunden(jetzt: zeit.date)))
                        .font(.system(size: 48, weight: .black).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, strichstaerke * 2)
            }
        }
        .frame(width: durchmesser, height: durchmesser)
        .accessibilityElement(children: .ignore)
        // designsystem.md SS12: der ganze Satz ist das Label, nicht Label
        // plus Value -- eine Value-Kopplung neben "gesprochen" (das selbst
        // schon mit "Pause" beginnt) wuerde die Ansage verdoppeln.
        .accessibilityLabel(ansage)
        .accessibilityAddTraits(.updatesFrequently)
        // Auf 15 s gedrosselt (SS12): eine 1:1-Kopplung an die sekuendliche
        // Anzeige waere fuer VoiceOver unbenutzbar. Neu ab dem jeweiligen
        // Endzeitpunkt gekeyed, damit "+30 s" die Ansage neu startet statt
        // den alten Countdown fortzufuehren.
        .task(id: timer.endetAm) {
            while !Task.isCancelled {
                ansage = timer.gesprochen()
                guard timer.laeuft() else { break }
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func uhrzeit(_ sekunden: Int) -> String {
        String(format: "%02d:%02d", sekunden / 60, sekunden % 60)
    }
}

#Preview {
    PausenRad(timer: Resttimer(), beiVerlaengern: {}, beiWeiter: {})
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
}
