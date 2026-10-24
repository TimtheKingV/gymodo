import SwiftUI

/// Die eine Zirkel-Uebersicht am Ende (Spec Mini-Zirkel 21.10.,
/// Entscheidung 7): alle Uebungen und alle Runden auf einer Seite, ein
/// "Weiter". Nach der letzten Runde genauso wie nach "Zirkel beenden" --
/// Beenden behaelt alle gesicherten Saetze, also zeigt es sie auch.
///
/// Bewusst knapp: je Uebung der Name und ihre Saetze, keine Bilanz, kein
/// Vergleich. Die ausfuehrliche Auswertung kommt mit dem Trainingsende.
struct ZirkelUebersichtView: View {
    /// "Zirkel geschafft" bzw. "Zirkel beendet" (ZirkelUebersicht.kopf).
    let kopf: String
    let zeilen: [ZirkelZeile]
    let beiWeiter: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Text(kopf.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                Card {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                        ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in
                            zeileAnzeigen(zeile)
                        }
                    }
                    .padding(DesignSystem.Spacing.s12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .testnotizElement("zirkel.uebersicht.saetze", typ: "Card")
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: "Weiter") { beiWeiter() }
                .accessibilityHint("Beendet den Zirkel, alle Sätze bleiben gesichert")
                .testnotizElement("zirkel.uebersicht.weiter", typ: "PrimaryButton")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, DesignSystem.Spacing.s8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Darunter liegt die Pause oder das Geraet des letzten Slots, beide
        // ohne Funktion, sobald der Zirkel vorbei ist. Heraus geht es nur
        // ueber "Weiter".
        .navigationBarBackButtonHidden(true)
        .testnotizScreen()
    }

    private func zeileAnzeigen(_ zeile: ZirkelZeile) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(zeile.uebungsname)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            // Ein Satz je Runde, nebeneinander gelesen wie eine Reihe.
            // Ohne Satz (immer uebersprungen) ein ruhiges Wort statt einer
            // leeren Stelle, die wie ein Ladefehler aussaehe.
            Text(zeile.saetze.isEmpty ? "Kein Satz" : zeile.saetze.joined(separator: "  ·  "))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(zeile.saetze.isEmpty ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Eine Zeile der Uebersicht: eine Uebung, ein Text je gesichertem Satz.
struct ZirkelZeile: Equatable {
    let uebungsname: String
    let saetze: [String]
}

/// Die Uebersicht als reine Rechnung, damit sie ohne View pruefbar ist.
enum ZirkelUebersicht {
    /// Aus den Bloecken der Einheit, nicht aus dem Schrittzaehler des
    /// Zirkels: der weiss, wie viele Slots erledigt sind, aber nicht,
    /// welche davon einen Satz hatten. Eine uebersprungene Runde hat keinen
    /// Satz und fehlt deshalb einfach. Reihenfolge wie im Zirkel; eine
    /// Uebung ohne Block steht mit leerer Liste da.
    ///
    /// `seit`: Beginn des Zirkels. Lief die Uebung vorher schon einzeln,
    /// traegt ihr Block diese Saetze mit -- sie gehoeren nicht hierher.
    static func zeilen(zirkel: Zirkel, bloecke: [LokalerBlock], seit: Date? = nil,
                       name: (ZirkelUebung) -> String) -> [ZirkelZeile] {
        zirkel.uebungen.map { uebung in
            let block = bloecke.first {
                $0.stationSchluessel == uebung.station && $0.exerciseId == uebung.exerciseId
            }
            let saetze = block.map { block in
                block.saetze
                    .filter { satz in seit.map { satz.performedAt >= $0 } ?? true }
                    .compactMap { ZirkelPauseText.satzwerte($0, block) }
            } ?? []
            return ZirkelZeile(uebungsname: name(uebung), saetze: saetze)
        }
    }

    /// "Geschafft" nur, wenn alle Runden durch sind; nach "Zirkel beenden"
    /// mitten drin waere das geschoent.
    static func kopf(_ zirkel: Zirkel) -> String {
        zirkel.istFertig ? "Zirkel geschafft" : "Zirkel beendet"
    }
}
