import SwiftUI
import UIKit

/// Was eine Uebungskarte zeigt (P4, Testnotiz 10.11. #7): Name, Vorschaubild,
/// Chips fuer Saetze/Wdh/Pause bzw. Dauer und eine Markierung "statt X" / "neu".
struct UebungskarteModell: Equatable {
    struct Chip: Equatable {
        let symbol: String
        let text: String
        let hervorgehoben: Bool
    }

    let name: String
    let exerciseId: String
    let vorschaubildModell: String?
    let chips: [Chip]
    let markierung: String?

    private static let symbolSaetze = "square.stack.3d.up"
    private static let symbolWdh = "arrow.triangle.2.circlepath"
    private static let symbolZeit = "timer"

    /// Satzzahl, Wiederholungen, Pause bzw. Dauer als Text ("8–12", nil ohne Bereich).
    private static func wdhText(von: Int?, bis: Int?) -> String? {
        guard let von, let bis else { return nil }
        return von == bis ? "\(von)" : "\(von)–\(bis)"
    }

    /// `ausgangExerciseId`: die Uebung der Ausgangsposition. "statt X" nur, wenn sie sich
    /// wirklich unterscheidet (A->B->A zeigt nichts); ohne Angabe gilt `ersetzt`.
    static func aus(
        _ p: EntwurfsPosition, name: String, bild: String?, geaendert: Set<WertFeld>,
        ausgangExerciseId: String? = nil
    ) -> UebungskarteModell {
        var chips: [Chip] = []
        if p.werteOffen {
            chips = [Chip(symbol: symbolSaetze, text: "Standard", hervorgehoben: false)]
        } else if p.art.istCardio {
            chips = [Chip(symbol: symbolZeit, text: "\(p.dauerMin ?? 0) min", hervorgehoben: geaendert.contains(.dauer))]
        } else {
            chips.append(Chip(symbol: symbolSaetze, text: "\(p.saetze) Sätze", hervorgehoben: geaendert.contains(.saetze)))
            if let w = wdhText(von: p.wdhVon, bis: p.wdhBis) {
                chips.append(Chip(symbol: symbolWdh, text: "\(w) Wdh", hervorgehoben: geaendert.contains(.wdh)))
            }
            chips.append(Chip(symbol: symbolZeit, text: "\(p.pauseSek) s", hervorgehoben: geaendert.contains(.pause)))
        }
        var markierung: String?
        if p.neu {
            markierung = "neu"
        } else if let alt = p.ersetzt, ausgangExerciseId.map({ $0 != p.exerciseId }) ?? true {
            markierung = "statt \(alt)"
        }
        return UebungskarteModell(
            name: name, exerciseId: p.exerciseId, vorschaubildModell: bild, chips: chips, markierung: markierung)
    }

    static func aus(_ p: TrainingsplanPosition, bootstrap: BootstrapResponse?) -> UebungskarteModell {
        let zeile = PlanZeilenModell.aus(p, bootstrap: bootstrap)
        let werte: [Chip]
        if let dauer = p.dauerMin {
            werte = [Chip(symbol: symbolZeit, text: "\(dauer) min", hervorgehoben: false)]
        } else {
            var c = [Chip(symbol: symbolSaetze, text: "\(p.saetze) Sätze", hervorgehoben: false)]
            if let w = wdhText(von: p.wdhVon, bis: p.wdhBis) {
                c.append(Chip(symbol: symbolWdh, text: "\(w) Wdh", hervorgehoben: false))
            }
            c.append(Chip(symbol: symbolZeit, text: "\(p.pauseSek) s", hervorgehoben: false))
            werte = c
        }
        return UebungskarteModell(
            name: zeile.name, exerciseId: zeile.exerciseId, vorschaubildModell: zeile.vorschaubildModell,
            chips: werte, markierung: nil)
    }

    /// Ein Satz fuer VoiceOver: "Name, 3 Sätze, 8 bis 12 Wiederholungen, 150 Sekunden Pause".
    var beschreibung: String {
        let teile = chips.map { chip -> String in
            if chip.text.hasSuffix(" Wdh") {
                return chip.text.replacingOccurrences(of: "–", with: " bis ")
                    .replacingOccurrences(of: " Wdh", with: " Wiederholungen")
            }
            if chip.text.hasSuffix(" s") { return chip.text.dropLast(2) + " Sekunden Pause" }
            if chip.text.hasSuffix(" min") { return chip.text.dropLast(4) + " Minuten" }
            return chip.text
        }
        return ([name] + teile + [markierung].compactMap { $0 }).joined(separator: ", ")
    }
}

/// Karte einer Uebung (Variante A): Vorschaubild links, Name, Chips darunter, rechts ein
/// freier Platz (Ziehgriff im Bearbeiten, P4).
struct Uebungskarte<Rechts: View>: View {
    let modell: UebungskarteModell
    let foto: UIImage?
    /// Tipp auf Bild und Texte (Bearbeiten: Anpassen-Blatt). Der rechte Platz bleibt
    /// ein eigenes Element, damit VoiceOver den Griff getrennt ansagt (P4, Testnotiz 10.11. #3).
    var beiTippen: (() -> Void)? = nil
    /// Testnotiz-Kennung nur fuer Bild und Texte, nicht fuer den Griff.
    var testnotizKennung: String? = nil
    @ViewBuilder let rechts: () -> Rechts

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
            koerper
            rechts()
        }
        .padding(12)
        .background(DesignSystem.Color.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignSystem.Color.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension Uebungskarte {
    /// Bild und Texte als ein Element mit der Beschreibung der Karte.
    @ViewBuilder
    private var koerper: some View {
        let inhalt = HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: modell.exerciseId) {
                PlanZeilenFoto(foto: foto)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(modell.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let markierung = modell.markierung {
                    Text(markierung)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.accent)
                }
                ChipZeile(chips: modell.chips)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(modell.beschreibung)
        if let beiTippen, let testnotizKennung {
            inhalt
                .onTapGesture(perform: beiTippen)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { beiTippen() }
                .testnotizElement(testnotizKennung, typ: "Button")
        } else if let beiTippen {
            inhalt
                .onTapGesture(perform: beiTippen)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { beiTippen() }
        } else {
            inhalt
        }
    }
}

extension Uebungskarte where Rechts == EmptyView {
    init(modell: UebungskarteModell, foto: UIImage?) {
        self.init(modell: modell, foto: foto) { EmptyView() }
    }
}

/// Umbrechende Pillen-Zeile (Symbol + Text).
private struct ChipZeile: View {
    let chips: [UebungskarteModell.Chip]

    var body: some View {
        FlowLayout(abstand: 6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                HStack(spacing: 4) {
                    Image(systemName: chip.symbol).font(.system(size: 11, weight: .semibold))
                    Text(chip.text).font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(chip.hervorgehoben ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(chip.hervorgehoben ? DesignSystem.Color.accentMuted : DesignSystem.Color.surfaceRaised)
                .clipShape(Capsule())
            }
        }
    }
}

/// Einfaches Umbruch-Layout fuer die Chips.
private struct FlowLayout: Layout {
    let abstand: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        platzieren(breite: proposal.width ?? .infinity, subviews: subviews).groesse
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = platzieren(breite: bounds.width, subviews: subviews)
        for (i, punkt) in r.punkte.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + punkt.x, y: bounds.minY + punkt.y), proposal: .unspecified)
        }
    }

    private func platzieren(breite: CGFloat, subviews: Subviews) -> (punkte: [CGPoint], groesse: CGSize) {
        var x: CGFloat = 0, y: CGFloat = 0, zeilenHoehe: CGFloat = 0, maxX: CGFloat = 0
        var punkte: [CGPoint] = []
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x > 0, x + g.width > breite { x = 0; y += zeilenHoehe + abstand; zeilenHoehe = 0 }
            punkte.append(CGPoint(x: x, y: y))
            x += g.width + abstand
            zeilenHoehe = max(zeilenHoehe, g.height)
            maxX = max(maxX, x - abstand)
        }
        return (punkte, CGSize(width: maxX, height: y + zeilenHoehe))
    }
}
