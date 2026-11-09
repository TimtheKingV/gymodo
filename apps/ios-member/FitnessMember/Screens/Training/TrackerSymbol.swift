#if DEBUG
import Sensorik
import SwiftUI

/// Der Tracker im Training (Paket 3): nur ein Symbol in der Kopfzeile,
/// gruen verbunden, sonst grau -- nie rot. Ohne gemerkten Tracker steht
/// hier nichts. Liest die Koordinatoren selbst aus dem Environment, damit
/// die Aufrufer der Kopfzeile davon nichts wissen (im Release gibt es sie
/// nicht).
struct TrackerSymbol: View {
    @Environment(SensorAufnahmeKoordinator.self) private var koordinator

    @State private var blattOffen = false

    var body: some View {
        let quelle = koordinator.quelle
        if TrackerAnzeige.sichtbar(hatGemerktenSensor: quelle.hatGemerktenSensor) {
            let verbunden = TrackerAnzeige.symbol(quelle.zustand) == .verbunden
            Button { blattOffen = true } label: {
                // Dasselbe Symbol wie in der Einrichtung im Profil; das
                // Produktbild "SensorGeraet" laesst sich nicht gruen/grau faerben.
                Image(systemName: "sensor.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(verbunden ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel(verbunden ? "Tracker verbunden" : "Tracker nicht verbunden")
            .accessibilityHint("Zeigt den Tracker")
            .testnotizElement("geraet.tracker", typ: "Button")
            .fixedSize()
            // Wie bei der Trainingsuhr: die 44 pt ragen aus der Kopfzeile
            // heraus, statt sie zu strecken.
            .padding(.vertical, -DesignSystem.Spacing.s12)
            .sheet(isPresented: $blattOffen) { TrackerBlatt() }
        }
    }
}

/// Was das Blatt im Training zeigt: Status und Automatik-Schalter, sonst
/// nichts. Verbinden, Auswahl und Vergessen gibt es nur im Profil (F7).
private struct TrackerBlatt: View {
    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @Environment(ZaehlerKoordinator.self) private var zaehler

    var body: some View {
        let zustand = koordinator.quelle.zustand
        let verbunden = TrackerAnzeige.symbol(zustand) == .verbunden
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                Image(systemName: "sensor.fill")
                    .foregroundStyle(verbunden ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(zustand.name.map(SensorName.anzeige) ?? SensorName.trackerName)
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(TrackerAnzeige.status(zustand))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    if !verbunden {
                        Text("Einrichtung im Profil")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            Toggle("Sätze automatisch starten und sichern", isOn: Binding(
                get: { zaehler.automatikAktiv }, set: { zaehler.automatikAktiv = $0 }))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .tint(DesignSystem.Color.accent)
                .testnotizElement("geraet.tracker.automatik", typ: "Toggle")
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Color.bg)
        // .medium dazu: bei grosser Schrift schneidet 220 pt sonst ab.
        .presentationDetents([.height(220), .medium])
        .presentationDragIndicator(.visible)
        .testnotizScreen()
    }
}
#endif
