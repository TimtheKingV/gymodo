import SwiftUI

/// Kopfzeile des Trainingsablaufs: links der Ort, rechts die laufende
/// Trainingsuhr. Gemeinsam fuer Geraet, Pause und Zirkel-Uebersicht, damit
/// alle denselben Kopf zeigen.
struct TrainingKopfzeile: View {
    /// Bereits grossgeschrieben uebergeben.
    let ort: String
    /// Oeffnet die `.trainingSteuerung` des Hosts.
    let beiSteuerung: () -> Void

    @Environment(WorkoutSessionStore.self) private var sessions

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ort)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer(minLength: DesignSystem.Spacing.s12)
            trainingsuhr
        }
    }

    /// Wie lange das Training schon laeuft -- oben rechts, in derselben
    /// Zeile wie der Ort, mit dem pulsierenden Punkt davor (Testnotiz
    /// 05.10., #10). Ein Tipp oeffnet "Pausieren / Training beenden" (#11).
    ///
    /// Ohne laufende Einheit (die Vier-Stunden-Grenze ist waehrend des
    /// Screens abgelaufen) steht hier nichts -- eine Uhr auf 00:00 waere
    /// eine Behauptung ueber ein Training, das nicht mehr laeuft.
    @ViewBuilder
    private var trainingsuhr: some View {
        if let session = sessions.aktiveSession() {
            Button(action: beiSteuerung) {
                HStack(spacing: 6) {
                    Laufpunkt(pausiert: session.istPausiert)
                    TrainingsuhrText(session: session, font: .system(size: 15, weight: .semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .testnotizElement("geraet.trainingsuhr", typ: "Button")
            .accessibilityHint("Pausieren oder Training beenden")
            .fixedSize()
            // Die 44 pt Trefferflaeche ragen aus der Kopfzeile heraus,
            // statt sie zu strecken -- dasselbe Hoehenbudget wie bei
            // "andere Übung".
            .padding(.vertical, -DesignSystem.Spacing.s12)
        }
    }
}
