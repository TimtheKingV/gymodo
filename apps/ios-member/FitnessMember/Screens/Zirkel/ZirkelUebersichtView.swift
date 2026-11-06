import SwiftUI

/// Die eine Zirkel-Uebersicht am Ende (Spec Mini-Zirkel 21.10.,
/// Entscheidung 7): alle Uebungen und alle Runden auf einer Seite, ein
/// "Weiter". Nach der letzten Runde genauso wie nach "Zirkel beenden" --
/// Beenden behaelt alle gesicherten Saetze, also zeigt es sie auch.
///
/// Bewusst knapp: je Uebung der Name und ihre Saetze, keine Bilanz, kein
/// Vergleich. Die ausfuehrliche Auswertung kommt mit dem Trainingsende.
struct ZirkelUebersichtView: View {
    /// Oeffnet die Trainingssteuerung der Wurzel (Tipp auf die Uhr in der
    /// Kopfzeile, wie am Geraet und in der Pause).
    let beiSteuerung: () -> Void
    /// "Zirkel geschafft" bzw. "Zirkel beendet" (ZirkelUebersicht.kopf).
    let kopf: String
    let zeilen: [ZirkelZeile]
    /// Die Reserve-Antwort je Block (E4: einmal je Station hier statt am
    /// Geraet) und der Weg, sie nachzutragen.
    let reserve: (_ blockId: String) -> Reserve?
    let beiReserve: (_ blockId: String, Reserve) -> Void
    let beiWeiter: () -> Void

    /// Beim Erscheinen einmal aus den Einstellungen gelesen, wie am Geraet.
    @State private var reserveErklaerungZeigen = false

    private var fragtReserve: Bool { zeilen.contains(where: \.fragtReserve) }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            TrainingKopfzeile(ort: "MINI-ZIRKEL", beiSteuerung: beiSteuerung)
            Text(kopf.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                if fragtReserve { reserveFrage }
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

    /// Die Frage steht einmal ueber der Liste, je Station nur die Chips
    /// (jede Information nur einmal pro Screen).
    private var reserveFrage: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(ReserveSkala.frage)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            if reserveErklaerungZeigen {
                Text(ReserveSkala.erklaerung)
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DesignSystem.Spacing.s12)
        .onAppear {
            reserveErklaerungZeigen = !UserDefaults.standard.bool(forKey: Einstellungen.reserveErklaertKey)
            UserDefaults.standard.set(true, forKey: Einstellungen.reserveErklaertKey)
        }
    }

    private func zeileAnzeigen(_ zeile: ZirkelZeile) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
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
            // Ausserhalb des kombinierten Elements: die Chips bleiben
            // einzeln bedienbar.
            if zeile.fragtReserve, let blockId = zeile.blockId {
                ReserveSkala(auswahl: reserve(blockId), mitErklaerung: false, kompakt: true) {
                    beiReserve(blockId, $0)
                }
                .testnotizElement("zirkel.uebersicht.reserve", typ: "ReserveSkala")
            }
        }
    }
}

/// Eine Zeile der Uebersicht: eine Uebung, ein Text je gesichertem Satz.
struct ZirkelZeile: Equatable {
    let uebungsname: String
    let saetze: [String]
    /// Der Block der Station in der Einheit; nil, solange sie keinen hat.
    let blockId: String?
    /// Ob die Zeile nach der Reserve fragt (E4): nur Wiederholungen, nur mit
    /// Satz im Zirkel, nur mit gemerktem letzten Satz.
    let fragtReserve: Bool
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
    ///
    /// `hatLetztenWrite`: ob der Speicher den letzten Satz des Blocks noch
    /// kennt -- ohne ihn kaeme eine Reserve-Antwort nie beim Server an.
    static func zeilen(zirkel: Zirkel, bloecke: [LokalerBlock], seit: Date? = nil,
                       name: (ZirkelUebung) -> String,
                       hatLetztenWrite: (_ blockId: String) -> Bool = { _ in true }) -> [ZirkelZeile] {
        zirkel.uebungen.map { uebung in
            let block = bloecke.first {
                $0.stationSchluessel == uebung.station && $0.exerciseId == uebung.exerciseId
            }
            let imZirkel = block?.saetze.filter { satz in seit.map { satz.performedAt >= $0 } ?? true } ?? []
            let saetze = block.map { block in imZirkel.compactMap { ZirkelPauseText.satzwerte($0, block) } } ?? []
            let fragtReserve = block.map { block in
                block.volumeKind == .reps && imZirkel.last.map { $0.cardio == nil } == true
                    && hatLetztenWrite(block.id)
            } ?? false
            return ZirkelZeile(uebungsname: name(uebung), saetze: saetze, blockId: block?.id,
                               fragtReserve: fragtReserve)
        }
    }

    /// "Geschafft" nur, wenn alle Runden durch sind; nach "Zirkel beenden"
    /// mitten drin waere das geschoent.
    static func kopf(_ zirkel: Zirkel) -> String {
        zirkel.istFertig ? "Zirkel geschafft" : "Zirkel beendet"
    }
}
