import Koerperbild
import SwiftUI

/// Der Rahmen, in dem der Koerper stehen soll: gestrichelt beim Aufstellen, ab dem Countdown
/// durchgezogen in Akzent. Groesse je Profil, mittig.
struct Aufstellrahmen: View {
    let profil: Kameraprofil
    var bestanden = false

    /// Anteile an Breite und Hoehe der Flaeche.
    static func anteile(_ profil: Kameraprofil) -> (breite: Double, hoehe: Double) {
        switch profil {
        case .oberkoerper: (0.74, 0.51)
        default: (0.80, 0.66)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let a = Self.anteile(profil)
            RoundedRectangle(cornerRadius: 24)
                .stroke(bestanden ? DesignSystem.Color.accent : DesignSystem.Color.text,
                        style: StrokeStyle(lineWidth: bestanden ? 3 : 2, dash: bestanden ? [] : [10, 10]))
                .frame(width: geo.size.width * a.breite, height: geo.size.height * a.hoehe)
                // Leicht unter der Mitte: oben liegt die Kopfleiste.
                .position(x: geo.size.width / 2, y: geo.size.height * 0.55)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Livebild, Strichfigur und Rahmen als gemeinsamer Grund von Aufstellen und Countdown.
struct KameraBildflaeche: View {
    let ziel: Livebildziel
    let skelett: Skelett?
    let profil: Kameraprofil
    var bestanden = false
    var warnend = false
    var dezent = false
    var hervor: Set<Gelenk> = []

    var body: some View {
        ZStack {
            DesignSystem.Color.surfaceRaised
            Livebild(ziel: ziel)
            Strichfigur(skelett: skelett, gespiegelt: ziel.gespiegelt, warnend: warnend, dezent: dezent, hervor: hervor)
            Aufstellrahmen(profil: profil, bestanden: bestanden)
        }
        .ignoresSafeArea()
    }
}

/// "Ohne Kamera" oben rechts, in jedem Schritt.
struct OhneKameraKnopf: View {
    let aktion: () -> Void

    var body: some View {
        Button("Ohne Kamera", action: aktion)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.text)
            .frame(minHeight: 44)
            .padding(.horizontal, DesignSystem.Spacing.s4)
    }
}

extension View {
    /// Kopf- und Fussleisten ueber dem Livebild: bg mit 82 % Deckkraft, bis unter die Sicherheitsraender.
    func kameraLeiste(_ kante: Edge.Set) -> some View {
        background(DesignSystem.Color.bg.opacity(0.82).ignoresSafeArea(edges: kante))
    }
}
