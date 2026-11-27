import Koerperbild
import SwiftUI

/// Das Skelett als Strichfigur ueber dem Livebild. Die Abbildung ist dieselbe
/// Aspect-Fill-Rechnung wie die des Livebilds; gespiegelt wird x -> 1 - x.
struct Strichfigur: View {
    let skelett: Skelett?
    var gespiegelt = true
    /// Warnfarbe statt Akzent, solange die Aufstellung nicht passt.
    var warnend = false
    /// Im Satz: alles auf 50 %, nur diese Gelenke (das Signalgelenk) und ihre Knochen kraeftig.
    var dezent = false
    var hervor: Set<Gelenk> = []

    static let knochen: [(Gelenk, Gelenk)] = [
        (.nase, .hals),
        (.hals, .schulterL), (.hals, .schulterR),
        (.schulterL, .ellbogenL), (.ellbogenL, .handL),
        (.schulterR, .ellbogenR), (.ellbogenR, .handR),
        (.schulterL, .hueftL), (.schulterR, .hueftR), (.hueftL, .hueftR),
        (.hueftL, .knieL), (.knieL, .fussL),
        (.hueftR, .knieR), (.knieR, .fussR),
    ]

    /// Bildpunkt (0...1, oben links) -> Punkt in der Flaeche, Aspect-Fill und gespiegelt wie das Livebild.
    nonisolated static func abbilden(x: Double, y: Double, seitenverhaeltnis: Double, in groesse: CGSize,
                         gespiegelt: Bool) -> CGPoint {
        let a = max(seitenverhaeltnis, 0.01)
        let hoehe = max(groesse.width / a, groesse.height)
        let breite = hoehe * a
        let xm = gespiegelt ? 1 - x : x
        return CGPoint(x: (groesse.width - breite) / 2 + xm * breite,
                       y: (groesse.height - hoehe) / 2 + y * hoehe)
    }

    var body: some View {
        Canvas { kontext, groesse in
            guard let skelett else { return }
            let farbe = warnend ? DesignSystem.Color.warn : DesignSystem.Color.accent
            func punkt(_ g: Gelenk) -> CGPoint? {
                guard let p = skelett.sicher(g) else { return nil }
                return Self.abbilden(x: p.x, y: p.y, seitenverhaeltnis: skelett.seitenverhaeltnis,
                                     in: groesse, gespiegelt: gespiegelt)
            }
            let stil = StrokeStyle(lineWidth: warnend ? 3 : 4, lineCap: .round, lineJoin: .round)
            let schwach: Double = dezent ? 0.5 : 1
            var linien = Path()
            var starkeLinien = Path()
            for (a, b) in Self.knochen {
                guard let pa = punkt(a), let pb = punkt(b) else { continue }
                if dezent, hervor.contains(a), hervor.contains(b) {
                    starkeLinien.move(to: pa); starkeLinien.addLine(to: pb)
                } else {
                    linien.move(to: pa); linien.addLine(to: pb)
                }
            }
            kontext.stroke(linien, with: .color(farbe.opacity(schwach)), style: stil)
            kontext.stroke(starkeLinien, with: .color(farbe), style: stil)
            for gelenk in Gelenk.allCases {
                guard let p = punkt(gelenk) else { continue }
                let stark = !dezent || hervor.contains(gelenk)
                kontext.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)),
                             with: .color(farbe.opacity(stark ? 1 : 0.5)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
