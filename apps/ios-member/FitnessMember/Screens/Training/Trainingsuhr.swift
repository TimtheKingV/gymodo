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
    /// Pausieren oder beenden -- derselbe Drawer vom Training-Tab und von
    /// der Uhr am Geraet (Testnotiz 05.10., #7, #11). Pausiert heisst die
    /// erste Wahl "Fortsetzen". Der Satz zur Vier-Stunden-Regel steht hier,
    /// wo beendet wird.
    ///
    /// Ein Drawer von unten statt des Aktionsblatts (Testnotiz 06.10., #4):
    /// das Blatt legte sich als Overlay ueber die Mitte und sah aus wie eine
    /// Systemwarnung, nicht wie ein Teil der App.
    func trainingSteuerung(
        istOffen: Binding<Bool>,
        pausiert: Bool,
        beiPauseUmschalten: @escaping () -> Void,
        beiBeenden: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: istOffen) {
            TrainingSteuerungSheet(
                pausiert: pausiert,
                beiPauseUmschalten: {
                    istOffen.wrappedValue = false
                    beiPauseUmschalten()
                },
                beiBeenden: {
                    istOffen.wrappedValue = false
                    beiBeenden()
                })
        }
    }
}

private struct TrainingSteuerungSheet: View {
    let pausiert: Bool
    let beiPauseUmschalten: () -> Void
    let beiBeenden: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Laufpunkt(pausiert: pausiert)
                Text(pausiert ? "TRAINING PAUSIERT" : "TRAINING LÄUFT")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Text("Ohne neuen Satz endet das Training nach vier Stunden von selbst.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .lineSpacing(3)
                .padding(.bottom, DesignSystem.Spacing.s8)
            // Fortsetzen ist die Hauptaktion einer Pause; Pausieren ist nur
            // eine Wahl unter zweien und bleibt Kontur. Beenden ist
            // zerstoerend und traegt deshalb nie den Akzent.
            if pausiert {
                PrimaryButton(title: "Fortsetzen") { beiPauseUmschalten() }
                    .testnotizElement("training.fortsetzen", typ: "PrimaryButton")
            } else {
                SecondaryButton(title: "Pausieren") { beiPauseUmschalten() }
                    .testnotizElement("training.pausieren", typ: "SecondaryButton")
            }
            DangerOutlineButton(title: "Training beenden") { beiBeenden() }
                .testnotizElement("training.beenden", typ: "DangerOutlineButton")
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Color.bg)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .testnotizScreen()
    }
}
