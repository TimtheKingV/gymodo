#if DEBUG
import SwiftUI

/// Vollflaechig: ein Rechteck ziehen oder einen Punkt tippen. Gezeichnet
/// wird in einem Canvas, der die Safe Area ignoriert -- so decken sich seine
/// Koordinaten mit .global und damit mit dem Bildschirmfoto.
struct AuswahlOverlay: View {
    enum Art { case rechteck, punkt }

    let art: Art
    let beiRechteck: (CGRect) -> Void
    let beiPunkt: (CGPoint) -> Void
    let beiAbbruch: () -> Void

    @State private var start: CGPoint?
    @State private var ende: CGPoint?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Canvas { kontext, groesse in
                var flaeche = Path(CGRect(origin: .zero, size: groesse))
                if art == .rechteck, let rechteck { flaeche.addRect(rechteck) }
                kontext.fill(flaeche, with: .color(DesignSystem.Color.bg.opacity(0.45)), style: FillStyle(eoFill: true))
                if art == .rechteck, let rechteck {
                    kontext.stroke(Path(rechteck), with: .color(DesignSystem.Color.accent), lineWidth: 2)
                }
                if art == .punkt, let ende {
                    let kreis = CGRect(x: ende.x - 22, y: ende.y - 22, width: 44, height: 44)
                    kontext.stroke(Path(ellipseIn: kreis), with: .color(DesignSystem.Color.accent), lineWidth: 2)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { wert in
                        start = wert.startLocation
                        ende = wert.location
                    }
                    .onEnded { wert in
                        start = nil
                        ende = nil
                        abschliessen(von: wert.startLocation, bis: wert.location)
                    }
            )

            Button(action: beiAbbruch) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Color.surfaceRaised, in: Circle())
            }
            .accessibilityLabel("Abbrechen")
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var rechteck: CGRect? {
        guard let start, let ende else { return nil }
        return CGRect(x: start.x, y: start.y, width: ende.x - start.x, height: ende.y - start.y).standardized
    }

    private func abschliessen(von a: CGPoint, bis b: CGPoint) {
        switch art {
        case .punkt:
            beiPunkt(b)
        case .rechteck:
            let r = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y).standardized
            // Ein Tipp ohne Zug bricht ab, statt einen 1-Pixel-Ausschnitt zu sichern.
            if r.width < 8 || r.height < 8 { beiAbbruch() } else { beiRechteck(r) }
        }
    }
}
#endif
