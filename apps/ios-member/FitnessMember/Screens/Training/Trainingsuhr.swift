import SwiftUI

/// Der Punkt vor "TRAINING LÄUFT" und vor der kleinen Uhr am Geraet.
///
/// Laeuft das Training, pulsiert er im Akzent: ein Lebenszeichen, dass die
/// Uhr zaehlt (Testnotiz 05.10., #9, #10). In der Pause wird er zum
/// Pausenzeichen in derselben Farbe (#11) -- dieselbe Stelle, ein anderer
/// Zustand, statt eines zweiten Symbols daneben. Ohne Bewegung (Bedienungs-
/// hilfen) steht der Punkt still; die Aussage traegt die Farbe.
struct Laufpunkt: View {
    let pausiert: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if pausiert {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(DesignSystem.Color.accent)
            } else if reduceMotion {
                punkt
            } else {
                punkt.phaseAnimator([false, true]) { inhalt, hell in
                    inhalt
                        .opacity(hell ? 1 : 0.35)
                        .scaleEffect(hell ? 1 : 0.7)
                } animation: { _ in .easeInOut(duration: 0.9) }
            }
        }
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)
    }

    private var punkt: some View {
        Circle()
            .fill(DesignSystem.Color.accent)
            .frame(width: 8, height: 8)
    }
}

/// Die trainierte Zeit, sekundengenau und ohne Pausen
/// (`LokaleSession.trainiert(bis:)`). Gegen gespeicherte Zeitpunkte
/// gerechnet statt mitgezaehlt: das ueberlebt Hintergrund und
/// Sperrbildschirm.
struct TrainingsuhrText: View {
    let session: LokaleSession
    let font: Font

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { zeit in
            let dauer = session.trainiert(bis: zeit.date)
            Text(Zahlformat.dauer(dauer))
                .font(font.monospacedDigit())
                // Weiss, nicht grau: die Uhr ist ein Wert, keine
                // Nebeninformation (Testnotiz 05.10., #10).
                .foregroundStyle(DesignSystem.Color.text)
                // Ohne Label liest VoiceOver "23:41" als Uhrzeit
                // (designsystem.md SS12).
                .accessibilityLabel(
                    session.istPausiert
                        ? "Pausiert, \(Zahlformat.dauerGesprochen(dauer))"
                        : Zahlformat.dauerGesprochen(dauer))
        }
    }
}

extension View {
    /// Pausieren oder beenden -- derselbe Dialog vom Training-Tab und von
    /// der Uhr am Geraet (Testnotiz 05.10., #7, #11). Pausiert heisst die
    /// erste Wahl "Fortsetzen". Der Satz zur Vier-Stunden-Regel stand unter
    /// dem alten Beenden-Knopf und steht jetzt hier, wo beendet wird.
    func trainingSteuerung(
        istOffen: Binding<Bool>,
        pausiert: Bool,
        beiPauseUmschalten: @escaping () -> Void,
        beiBeenden: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            pausiert ? "Training pausiert" : "Training läuft",
            isPresented: istOffen,
            titleVisibility: .visible
        ) {
            Button(pausiert ? "Fortsetzen" : "Pausieren", action: beiPauseUmschalten)
            Button("Training beenden", role: .destructive, action: beiBeenden)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ohne neuen Satz endet das Training nach vier Stunden von selbst.")
        }
    }
}
