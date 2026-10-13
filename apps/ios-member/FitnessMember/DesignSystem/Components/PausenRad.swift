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
    /// Das Gewicht fuer den naechsten Satz -- in der Pause wird
    /// umgesteckt (Testnotiz 11.10., #12).
    let beiGewicht: () -> Void
    /// Die Einheit fuer "± kg" (Testnotiz 12.10. abends, #4).
    let einheit: LoadUnit
    let beiWeiter: () -> Void
    /// Der Weg zurueck zum Training, ohne den Umweg ueber den naechsten
    /// Satz. Wer am Geraet fertig ist, merkt das in der Pause -- nicht
    /// erst, wenn die Raeder wieder dastehen.
    let beiAbschliessen: () -> Void

    /// Der gedrosselte Ansagetext (SS12). Ein eigener Task-Takt statt einer
    /// zweiten TimelineView, damit der Sekundentakt der sichtbaren Anzeige
    /// unangetastet bleibt.
    @State private var ansage: String

    init(timer: Resttimer,
         beiVerlaengern: @escaping () -> Void,
         beiGewicht: @escaping () -> Void,
         einheit: LoadUnit = .kg,
         beiWeiter: @escaping () -> Void,
         beiAbschliessen: @escaping () -> Void) {
        self.timer = timer
        self.beiVerlaengern = beiVerlaengern
        self.beiGewicht = beiGewicht
        self.einheit = einheit
        self.beiWeiter = beiWeiter
        self.beiAbschliessen = beiAbschliessen
        _ansage = State(initialValue: timer.gesprochen())
    }

    var body: some View {
        // Kein eigenes vertikales Padding: der Abstand kommt vom
        // Satzpfad-VStack, und 48 pt hier plus 32 statt 24 pt Abstand zum
        // Knopfblock machten die Pause auf einem 667-pt-iPhone auf iOS 26
        // (510 pt Inhaltshoehe dort) rund 45 pt zu hoch (Plan Schnitt 3,
        // Task 8).
        // Das Rad in der Mitte, die Knoepfe unten in der Daumenzone
        // (Testnotiz 05.10., #12). Die Spacer greifen nur, wenn der
        // Satzpfad die Hoehe des Bildschirms anbietet (GeraetView); sonst
        // bleibt es beim Abstand von 24 pt.
        VStack(spacing: DesignSystem.Spacing.s24) {
            Spacer(minLength: 0)
            rad
            Spacer(minLength: 0)
            VStack(spacing: DesignSystem.Spacing.s12) {
                // Nebeneinander, weil beide die Pause selbst betreffen: noch
                // etwas laenger, oder fuer den naechsten Satz umstecken.
                HStack(spacing: DesignSystem.Spacing.s8) {
                    SecondaryButton(title: "+30 s", action: beiVerlaengern)
                        .accessibilityLabel("Pause um 30 Sekunden verlängern")
                    SecondaryButton(title: Self.gewichtTitel(einheit), action: beiGewicht)
                        .accessibilityLabel("Gewicht für den nächsten Satz ändern")
                }
                // Zwei Akzentflaechen -- bewusst gegen SS2 (Testnotiz 12.10.
                // abends, #6, #7): wer im Zirkel trainiert, wechselt nach
                // jedem Satz die Uebung und macht spaeter eine zweite Runde.
                // Fuer ihn ist "Nächste Übung" so oft der naechste Schritt wie
                // "Nächster Satz" und darf kein kleiner Nebenknopf sein. Es ist
                // derselbe Weg wie "Übung abschließen" unter den Raedern.
                //
                // Erst der Satz, dann die Uebung (Testnotiz 13.10., #2): so
                // gelesen, wie es im Training kommt. Bis dahin stand "Nächster
                // Satz" unten, wo der Daumen vom Sichern lag (06.10., #7).
                // Bis 12.10. hiess er "Weiter".
                PrimaryButton(title: "Nächster Satz") { beiWeiter() }
                    .accessibilityHint("Beendet die Pause und zeigt wieder die Räder")
                    .testnotizElement("geraet.naechster-satz", typ: "PrimaryButton")
                PrimaryButton(title: "Nächste Übung") { beiAbschliessen() }
                    .accessibilityHint("Schließt diese Übung ab")
                    .testnotizElement("geraet.naechste-uebung", typ: "PrimaryButton")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rad: some View {
        Zeitring(timer: timer, beschriftung: "PAUSE") { uhrzeit($0) }
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

    /// "± kg" statt "Gewicht" (Testnotiz 12.10. abends, #4): kurz genug
    /// fuer die halbe Zeile, und am Laufband steht "± km/h".
    nonisolated static func gewichtTitel(_ einheit: LoadUnit) -> String {
        "± \(einheit.kurz)"
    }

    private func uhrzeit(_ sekunden: Int) -> String {
        String(format: "%02d:%02d", sekunden / 60, sekunden % 60)
    }
}

/// Der Bogen mit Beschriftung und Zahl in der Mitte -- fuer die Pause und
/// den Countdown vor dem ersten Satz (Testnotiz 11.10., #10: "gleich wie
/// der Pausen-Timer").
///
/// Eine einzige, ungeschachtelte TimelineView treibt Bogen UND Ziffern --
/// zwei Takte fuer denselben Sekundenwechsel liefen unweigerlich
/// auseinander. Welche, haengt nur davon ab, ob ein eigener Verlauf
/// gesetzt ist.
struct Zeitring: View {
    let timer: Resttimer
    let beschriftung: String
    /// Ein eigener Verlauf fuer den Bogen. nil: der Bogen folgt dem Timer
    /// in Sekundenschritten (Pause). Gesetzt: der Bogen laeuft fliessend im
    /// Animationstakt (Countdown, Testnotiz 12.10. abends, #2).
    var fortschritt: ((Date) -> Double)? = nil
    let mitte: (Int) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Skaliert mit der Schriftgroesse: das Rad traegt Ziffern, und ein
    /// fester Durchmesser liesse sie bei grossen Dynamic-Type-Stufen aus
    /// dem Kreis laufen.
    @ScaledMetric(relativeTo: .body) private var durchmesser: CGFloat = 240
    @ScaledMetric(relativeTo: .body) private var strichstaerke: CGFloat = 12

    var body: some View {
        Group {
            if let fortschritt, !reduceMotion {
                // Jeder Frame rechnet Bogen und Ziffer aus demselben Datum:
                // keine Animation, die hinterherlaeuft. Der Countdown dauert
                // sechs Sekunden, der Takt kostet dabei nichts Merkliches.
                TimelineView(.animation) { zeit in
                    ring(fortschritt: fortschritt(zeit.date), jetzt: zeit.date, animiert: false)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { zeit in
                    ring(fortschritt: fortschritt?(zeit.date) ?? timer.fortschritt(jetzt: zeit.date),
                         jetzt: zeit.date, animiert: !reduceMotion)
                }
            }
        }
        .frame(width: durchmesser, height: durchmesser)
    }

    private func ring(fortschritt: Double, jetzt: Date, animiert: Bool) -> some View {
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
                .animation(animiert ? .linear(duration: 1) : nil, value: fortschritt)

            VStack(spacing: DesignSystem.Spacing.s4) {
                Text(beschriftung)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(mitte(timer.restsekunden(jetzt: jetzt)))
                    .font(.system(size: 48, weight: .black).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, strichstaerke * 2)
        }
    }
}

#Preview {
    PausenRad(timer: Resttimer(), beiVerlaengern: {}, beiGewicht: {}, beiWeiter: {}, beiAbschliessen: {})
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
}
