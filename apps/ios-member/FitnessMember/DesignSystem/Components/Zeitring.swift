import SwiftUI

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
    let fortschritt: ((Date) -> Double)?
    let mitte: (Int) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Skaliert mit der Schriftgroesse: das Rad traegt Ziffern, und ein
    /// fester Durchmesser liesse sie bei grossen Dynamic-Type-Stufen aus
    /// dem Kreis laufen.
    @ScaledMetric(relativeTo: .body) private var durchmesser: CGFloat = 240
    @ScaledMetric(relativeTo: .body) private var strichstaerke: CGFloat = 12
    /// Die Ziffern wachsen und schrumpfen mit dem Ring: 48 pt in einem
    /// kleinen Ring liefen sonst an den Bogen.
    private let ziffernGroesse: CGFloat

    /// `kante`: der Durchmesser ohne Dynamic Type. 240 fuer Pause und
    /// Countdown am Geraet; kleiner im Zirkel, wo die naechste Uebung das
    /// Wichtigste auf dem Screen ist und die Uhr nur Nebensache (Spec
    /// Mini-Zirkel, Anti-Ziel "Pausenscreen nicht ueberladen").
    init(timer: Resttimer, beschriftung: String, kante: CGFloat = 240,
         fortschritt: ((Date) -> Double)? = nil, mitte: @escaping (Int) -> String) {
        self.timer = timer
        self.beschriftung = beschriftung
        self.fortschritt = fortschritt
        self.mitte = mitte
        let massstab = kante / 240
        _durchmesser = ScaledMetric(wrappedValue: kante, relativeTo: .body)
        _strichstaerke = ScaledMetric(wrappedValue: max(6, 12 * massstab), relativeTo: .body)
        ziffernGroesse = 48 * massstab
    }

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
                    .font(.system(size: ziffernGroesse, weight: .black).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, strichstaerke * 2)
        }
    }
}

/// Der volle Ring nach dem letzten vorgeschlagenen Satz (Testnotiz 14.10.,
/// 18:45 #5): an der Stelle, an der sonst die Pause laeuft, steht "Fertig"
/// -- bei Cardio nach dem einen Satz, sonst nach der Satzzahl. Dieselben
/// Masse wie der Zeitring, damit der Uebergang aus der Pause nicht springt.
struct FertigRing: View {
    @ScaledMetric(relativeTo: .body) private var durchmesser: CGFloat = 240
    @ScaledMetric(relativeTo: .body) private var strichstaerke: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Color.accent, lineWidth: strichstaerke)
            Text("Fertig")
                .font(.system(size: 48, weight: .black))
                .foregroundStyle(DesignSystem.Color.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, strichstaerke * 2)
        }
        .frame(width: durchmesser, height: durchmesser)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fertig")
    }
}
