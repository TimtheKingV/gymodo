import SwiftUI

/// "Was machst du heute?" -- die Uebungsliste eines erkannten Geraets.
///
/// Ein Tap auf eine Uebung fuehrt direkt zum Satz; es gibt keinen
/// Bestaetigungsknopf (designsystem.md SS8).
struct GeraetErkanntView: View {
    let modell: GeraetModel
    let beiAuswahl: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopfzeile
                geraetefoto
                geraetename
                Text("Was machst du heute?")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                uebungsliste
                hinweis
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kopfzeile: some View {
        HStack {
            Text(ortsangabe)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer()
            // Abweichung vom Artboard: dort accent. Die eine Akzentflaeche
            // des Screens ist die aktive Uebungszeile (designsystem.md SS2).
            Label("ERKANNT", systemImage: "wave.3.right")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var ortsangabe: String {
        [modell.maschine.label, modell.maschine.locationNote]
            .compactMap { $0 }
            .joined(separator: " · ")
            .uppercased()
    }

    /// Bestaetigt in einer Sekunde, dass man am richtigen Geraet steht --
    /// bei zwei baugleichen Stationen der eigentliche Nutzen. Offline gibt
    /// es keine signierte URL, dann steht hier der Platzhalter.
    private var geraetefoto: some View {
        AsyncImage(url: modell.kontext?.equipmentModel.photoUrl.flatMap(URL.init(string:))) { bild in
            bild.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                DesignSystem.Color.surfaceRaised
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityHidden(true)
    }

    private var geraetename: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(modell.maschine.equipmentModel.name.uppercased())
                .font(DesignSystem.Typography.geraetename)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
            Text(hersteller)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var hersteller: String {
        [modell.maschine.equipmentModel.manufacturer, modell.maschine.locationNote]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var uebungsliste: some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(sortierteUebungen) { uebung in
                Button { beiAuswahl(uebung.id) } label: {
                    zeile(uebung)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("\(uebung.name), \(untertitel(uebung))")
                .accessibilityHint("Öffnet das Gerät")
            }
        }
    }

    /// Ab zwei Besuchen steht die zuletzt genutzte Uebung oben
    /// (designsystem.md SS8).
    private var sortierteUebungen: [GeraetUebung] {
        modell.uebungen.sorted { links, _ in links.id == modell.uebungId }
    }

    private func zeile(_ uebung: GeraetUebung) -> some View {
        let aktiv = uebung.id == modell.uebungId
        return HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(untertitel(uebung))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(aktiv ? DesignSystem.Color.surfaceRaised : DesignSystem.Color.surface)
        .overlay(alignment: .leading) {
            // Die eine Akzentflaeche des Screens.
            if aktiv {
                Rectangle().fill(DesignSystem.Color.accent).frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func untertitel(_ uebung: GeraetUebung) -> String {
        if let letzter = letzterSatz(uebung.id) {
            return "zuletzt · \(Zahlformat.gewichtMitEinheit(letzter))"
        }
        return "Noch nie · Ziel \(uebung.targetRepsMin) – \(uebung.targetRepsMax) Wdh."
    }

    private func letzterSatz(_ uebungId: String) -> Double? {
        modell.letztesGewicht(fuer: uebungId)
    }

    private var hinweis: some View {
        Text("Ein Tap genügt — du landest direkt beim Satz. Trainierst du hier immer dasselbe, überspringt gymodo diesen Schritt künftig.")
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .lineSpacing(3)
    }
}
