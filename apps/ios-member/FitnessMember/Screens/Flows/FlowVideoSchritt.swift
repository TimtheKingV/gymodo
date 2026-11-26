import AVFoundation
import SwiftUI

/// Ein Flow-Schritt mit dem Video der Uebung: Ueberschrift, Video als
/// Schleife, darunter Name und Beschreibung. Ohne `video` steht an Stelle des
/// Videos der Ring. Das Asset kommt fertig vorbereitet vom Aufrufer, damit ein
/// Phasenwechsel mit demselben Video nichts neu aufbaut.
struct FlowVideoSchritt: View {
    let ueberschrift: String
    /// Kleine Zeile ueber dem Namen ("Als Nächstes"); nil: keine.
    let zeile: String?
    let name: String
    let beschreibung: String?
    /// Wohin das Mitglied schaut oder steht, wenn die Kamera zaehlt.
    let blickzeile: String?
    let video: AVAsset?
    let ringErsatz: FlowRing

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Text(ueberschrift)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                // Die Hoehe haelt Platz fuer die Zeitpille, die der Aufrufer oben rechts darueberlegt.
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            flaeche
            VStack(spacing: DesignSystem.Spacing.s8) {
                if let zeile {
                    Text(zeile)
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.accent)
                }
                Text(name)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                if let beschreibung, !beschreibung.isEmpty {
                    Text(beschreibung)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                if let blickzeile {
                    Text(blickzeile)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    private var flaeche: some View {
        if let video {
            Schleifenvideo(asset: video, ganz: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 160, maxHeight: 340)
                .background(DesignSystem.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
                .accessibilityHidden(true)
        } else {
            ringErsatz
        }
    }
}

#if DEBUG
#Preview("Ohne Video: Ring") {
    FlowVideoSchritt(
        ueberschrift: "PAUSE", zeile: "Als Nächstes", name: "Liegestütze",
        beschreibung: "Den Körper gerade halten, die Brust zum Boden senken.",
        blickzeile: "Stell dich seitlich zur Kamera", video: nil,
        ringErsatz: FlowRing(rest: 0.6, beschriftung: "PAUSE", ziffer: "14", kante: 160))
        .padding(20)
        .background(DesignSystem.Color.bg)
}

#Preview("Mit Video (Datei fehlt)") {
    FlowVideoSchritt(
        ueberschrift: "SCHRITT 2 VON 20", zeile: nil, name: "Liegestütze", beschreibung: nil,
        blickzeile: nil, video: AVURLAsset(url: URL(fileURLWithPath: "/nicht/da.mp4")),
        ringErsatz: FlowRing(rest: 0.6, beschriftung: "ARBEIT", ziffer: "31", kante: 160))
        .padding(20)
        .background(DesignSystem.Color.bg)
}
#endif
