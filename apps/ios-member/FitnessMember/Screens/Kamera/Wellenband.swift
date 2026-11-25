import Koerperbild
import Sensorik
import SwiftUI

/// Die Tempo-Welle als laufendes Band: 2,5 Perioden im Fenster, die Jetzt-Linie bei 40 % der Breite,
/// die Zukunft rechts, das Band laeuft nach links. Soll-Linie hell, Spur und Punkt in Akzent;
/// ausserhalb des Takts faerbt sich das Stueck seit dem Verlassen der Bahn und der Punkt in Warnfarbe.
/// Lage 0 oben, wenn die Wiederholung mit Senken beginnt, sonst unten (die Welle geht in der Bewegungsrichtung).
struct Wellenband: View {
    let welle: Sollwelle
    let tempo: Uebungstempo
    let sollzeit: TimeInterval
    var spur: [KameraSatzAblauf.Spurpunkt] = []
    var punkt: Double?
    var takt: KameraSatzAblauf.Takt = .imTakt
    /// Soll-Zahl erreicht: die Soll-Linie tritt auf 30 % zurueck.
    var gedaempft = false
    /// Die Welle wartet (Tracking verloren): das ganze Band tritt zurueck.
    var wartend = false
    /// Der Punkt steht auf einer nicht sicheren Lage (35 % Deckkraft).
    var punktSicher = true

    static let fenster = 2.5
    static let jetztAnteil = 0.4

    var body: some View {
        Canvas { kontext, groesse in
            let dauer = Self.fenster * welle.vorgabe.periode
            let xJetzt = groesse.width * Self.jetztAnteil
            func x(_ t: TimeInterval) -> CGFloat {
                xJetzt + CGFloat((t - sollzeit) / dauer) * groesse.width
            }
            let rand = groesse.height * 0.14
            let innen = groesse.height - 2 * rand
            func y(_ lage: Double) -> CGFloat {
                let l = CGFloat(min(max(lage, -0.15), 1.15))
                return tempo.beginntMit == .senken ? rand + l * innen : groesse.height - rand - l * innen
            }

            // Jetzt-Linie
            var jetzt = Path()
            jetzt.move(to: CGPoint(x: xJetzt, y: 0))
            jetzt.addLine(to: CGPoint(x: xJetzt, y: groesse.height))
            kontext.stroke(jetzt, with: .color(DesignSystem.Color.text.opacity(0.18)), lineWidth: 1)

            // Soll-Linie
            var soll = Path()
            var px: CGFloat = 0
            while px <= groesse.width {
                let t = sollzeit + Double((px - xJetzt) / groesse.width) * dauer
                let p = CGPoint(x: px, y: y(welle.lage(bei: t)))
                if px == 0 { soll.move(to: p) } else { soll.addLine(to: p) }
                px += 3
            }
            kontext.stroke(soll, with: .color(DesignSystem.Color.text.opacity(gedaempft ? 0.30 : 0.55)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            // Spur: ab dem letzten Punkt in der Bahn warnfarben, wenn der Takt nicht stimmt.
            let sichtbar = spur.filter { x($0.sollzeit) >= -4 && x($0.sollzeit) <= groesse.width + 4 }
            var warnAb = sichtbar.count
            if takt != .imTakt {
                warnAb = (sichtbar.lastIndex { welle.inDerBahn($0.lage, bei: $0.sollzeit) } ?? -1)
                warnAb = max(warnAb, 0)
            }
            func linie(_ bereich: Range<Int>) -> Path {
                var pfad = Path()
                var offen = false
                for i in bereich {
                    let s = sichtbar[i]
                    guard s.sicher else { offen = false; continue }
                    let p = CGPoint(x: x(s.sollzeit), y: y(s.lage))
                    if offen { pfad.addLine(to: p) } else { pfad.move(to: p); offen = true }
                }
                return pfad
            }
            let stil = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            if !sichtbar.isEmpty {
                kontext.stroke(linie(0..<min(warnAb + 1, sichtbar.count)), with: .color(DesignSystem.Color.accent), style: stil)
                if warnAb < sichtbar.count {
                    kontext.stroke(linie(warnAb..<sichtbar.count), with: .color(DesignSystem.Color.warn), style: stil)
                }
            }

            // Punkt
            if let punkt {
                let farbe = takt == .imTakt ? DesignSystem.Color.accent : DesignSystem.Color.warn
                kontext.fill(Path(ellipseIn: CGRect(x: xJetzt - 9, y: y(punkt) - 9, width: 18, height: 18)),
                             with: .color(farbe.opacity(punktSicher ? 1 : 0.35)))
            }
        }
        .opacity(wartend ? 0.4 : 1)
        .accessibilityLabel("Tempo-Welle: \(tempo.inWorten)")
    }
}

#if DEBUG
#Preview("Wellenband") {
    let tempo = Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken)
    let welle = Sollwelle(vorgabe: tempo.vorgabe)
    return Wellenband(welle: welle, tempo: tempo, sollzeit: 2.2)
        .frame(height: 110)
        .background(DesignSystem.Color.bg)
}
#endif
