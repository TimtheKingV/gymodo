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
    /// Der gedrosselte Ansagetext (SS12). Ein eigener Task-Takt statt einer
    /// zweiten TimelineView, damit der Sekundentakt der sichtbaren Anzeige
    /// unangetastet bleibt -- kein verschachtelter Renderer, dessen
    /// Ueberleben ueber den 15-Sekunden-Rebuild hinweg unspezifiziert waere.
    @State private var ansage: String

    init(timer: Resttimer, beiVerlaengern: @escaping () -> Void) {
        self.timer = timer
        self.beiVerlaengern = beiVerlaengern
        _ansage = State(initialValue: timer.gesprochen())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("PAUSE · \(Int(timer.gesamtdauer)) S")
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

    /// Zwei Takte statt einem: der sichtbare Fortschritt laeuft sekuendlich
    /// ueber diese eine, ungeschachtelte TimelineView; die VoiceOver-Ansage
    /// haengt an keiner zweiten TimelineView, sondern an einem Task-Takt
    /// unten -- die beiden Cadences beeinflussen sich dadurch strukturell
    /// nicht. Der Balken traegt sonst keinen Accessibility-Inhalt und ist
    /// damit ein echtes, erreichbares Element fuer die Ansage.
    private var balken: some View {
        TimelineView(.periodic(from: .now, by: 1)) { zeit in
            GeometryReader { rahmen in
                ZStack(alignment: .leading) {
                    Rectangle().fill(DesignSystem.Color.line)
                    Rectangle()
                        .fill(DesignSystem.Color.accent)
                        .frame(width: rahmen.size.width * timer.anteil(jetzt: zeit.date))
                        .animation(reduceMotion ? nil : .linear(duration: 1),
                                   value: timer.anteil(jetzt: zeit.date))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 4)
        .accessibilityElement(children: .ignore)
        // designsystem.md SS12: der ganze Satz ist das Label, nicht Label
        // plus Value -- eine Value-Kopplung neben "gesprochen" (das selbst
        // schon mit "Pause" beginnt) wuerde die Ansage verdoppeln.
        .accessibilityLabel(ansage)
        .accessibilityAddTraits(.updatesFrequently)
        // Auf 15 s gedrosselt (SS12): eine 1:1-Kopplung an die sekuendliche
        // Anzeige waere fuer VoiceOver unbenutzbar. Neu ab dem jeweiligen
        // Endzeitpunkt gekeyed, damit "+30 s" (das einen neuen Resttimer
        // erzeugt) die Ansage neu startet statt den alten Countdown fortzufuehren.
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
    ResttimerBalken(timer: Resttimer(), beiVerlaengern: {})
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
}
