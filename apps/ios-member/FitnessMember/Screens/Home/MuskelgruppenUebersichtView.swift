import SwiftUI

/// Uebungsfortschritt auf Home, Sicht "Muskelgruppen" (Entwurf A): oben die
/// Ausgewogenheit mit einem Satz, dann die Figur nach Trainingshaeufigkeit
/// gefaerbt, darunter die sechs Gruppen. Fortschritt (Zahl) und Haeufigkeit
/// (Balken, Farbe) bleiben sichtbar getrennt.
///
/// Die Figur ist nicht antippbar; das Detail oeffnet nur ueber die Liste.
struct MuskelgruppenUebersichtView: View {
    let auswertung: MuskelAuswertung
    let geschlecht: Geschlecht?
    let onGruppe: (MuskelHauptgruppe) -> Void

    private var h: Haeufigkeit { auswertung.haeufigkeit }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            ausgewogenheitsKarte
            figurKarte
            gruppenListe
        }
    }

    private var ausgewogenheitsKarte: some View {
        let prozent = Ausgewogenheit.prozent(h)
        return MuskelKartenRahmen {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                MuskelKartenTitel(text: "Ausgewogenheit")
                Text(prozent.map { "\($0) %" } ?? "–")
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(prozent == nil ? DesignSystem.Color.textFaint : DesignSystem.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(MuskelHinweise.startsatz(h))
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ausgewogenheit \(prozent.map { "\($0) Prozent" } ?? "noch nicht auswertbar"). \(MuskelHinweise.startsatz(h))")
    }

    private var figurKarte: some View {
        MuskelKartenRahmen {
            VStack(spacing: DesignSystem.Spacing.s12) {
                VStack(spacing: DesignSystem.Spacing.s8) {
                    MuskelFigur(farben: MuskelFarben.farbenAlle(h), geschlecht: geschlecht)
                    HStack(spacing: 0) {
                        ansichtsname("Vorderseite")
                        ansichtsname("Rückseite")
                    }
                }
                MuskelLegende()
            }
        }
        // Die Figur ist schematisch und fuer VoiceOver verborgen; die
        // Gruppenliste darunter traegt dieselbe Aussage als Text.
        .accessibilityHidden(true)
    }

    private func ansichtsname(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .frame(maxWidth: .infinity)
    }

    private var gruppenListe: some View {
        let groesste = MuskelHauptgruppe.angezeigt.map { h.jeGruppe[$0] ?? 0 }.max() ?? 0
        return MuskelKartenRahmen(innen: 0) {
            VStack(spacing: 0) {
                ForEach(Array(MuskelHauptgruppe.angezeigt.enumerated()), id: \.element) { index, gruppe in
                    if index > 0 {
                        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                    }
                    gruppenZeile(gruppe, groesste: groesste)
                }
            }
        }
    }

    private func gruppenZeile(_ gruppe: MuskelHauptgruppe, groesste: Int) -> some View {
        let status = Ausgewogenheit.status(gruppe: gruppe, in: h)
        let wert = MuskelFortschritt.anzeige(auswertung.fortschritt.jeGruppe[gruppe])
        let brauchtTrainings = FortschrittsText.brauchtTrainings(wert, auswertbar: h.istAuswertbar)
        return Button {
            onGruppe(gruppe)
        } label: {
            HStack(spacing: DesignSystem.Spacing.s12) {
                Text(gruppe.titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(minWidth: 84, alignment: .leading)
                    .layoutPriority(1)
                if h.istAuswertbar {
                    HaeufigkeitsBalken(
                        anteil: Self.anteil(h.jeGruppe[gruppe] ?? 0, von: groesste),
                        status: status,
                        zaehl: h.jeGruppe[gruppe] ?? 0)
                } else {
                    Spacer(minLength: 0)
                }
                // Feste Spalte, damit die Balken aller Zeilen gleich lang sind.
                VStack(alignment: .trailing, spacing: 2) {
                    FortschrittsText(wert: wert)
                    if brauchtTrainings {
                        FortschrittsText.BrauchtTrainings()
                    }
                }
                .frame(width: 76, alignment: .trailing)
                .layoutPriority(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)
            // Platz fuer den zweizeiligen Hinweis unter dem Strich.
            .padding(.vertical, DesignSystem.Spacing.s8)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(gruppe.titel), Fortschritt \(FortschrittsText.gesprochen(wert))\(brauchtTrainings ? ", \(FortschrittsText.brauchtTrainingsText)" : ""), \(MuskelStatusText.gesprochen(status))")
        .accessibilityAddTraits(.isButton)
    }

    nonisolated static func anteil(_ wert: Int, von groesste: Int) -> Double {
        groesste > 0 ? Double(wert) / Double(groesste) : 0
    }
}

// MARK: - Bausteine fuer Uebersicht und Detail

/// Rahmen wie die Muskelkarte der Einweisung.
struct MuskelKartenRahmen<Inhalt: View>: View {
    var innen: CGFloat = DesignSystem.Spacing.s16
    @ViewBuilder let inhalt: Inhalt

    var body: some View {
        inhalt
            .padding(innen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
    }
}

struct MuskelKartenTitel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(DesignSystem.Typography.label)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Color.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Trainingshaeufigkeit als Balken; Laenge relativ zum groessten Wert,
/// Farbe aus dem Status. Nachholbedarf behaelt einen kurzen Ansatz, damit
/// die Farbe auch bei null Einheiten zu sehen ist.
struct HaeufigkeitsBalken: View {
    let anteil: Double
    let status: MuskelStatus
    /// Anzahl Einheiten, die der Balken zeigt; daneben als Zahl.
    var zaehl: Int? = nil

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            GeometryReader { geo in
                let breite = max(status == .nachholbedarf ? 6 : 0, geo.size.width * min(1, max(0, anteil)))
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignSystem.Color.surfaceRaised)
                    Capsule().fill(MuskelFarben.farbe(status)).frame(width: breite)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: .infinity)
            if let zaehl {
                Text("\(zaehl)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(minWidth: 20, alignment: .trailing)
                    .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }
}

/// "+14 %" im Akzent, "stabil" und Rueckgang gedaempft, "–" ohne Wert.
struct FortschrittsText: View {
    let wert: FortschrittsWert
    var font: Font = DesignSystem.Typography.wertSekundaer

    var body: some View {
        Text(Self.text(wert))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(Self.farbe(wert))
            .lineLimit(1)
            .fixedSize()
    }

    nonisolated static func text(_ wert: FortschrittsWert) -> String {
        switch wert {
        case .wert(let p): p > 0 ? "+\(p) %" : "\(p) %".replacingOccurrences(of: "-", with: "−")
        case .stabil: "±0 %"
        case .keinWert: "–"
        }
    }

    static func farbe(_ wert: FortschrittsWert) -> Color {
        switch wert {
        case .wert(let p) where p > 0: DesignSystem.Color.accent
        case .wert, .stabil: DesignSystem.Color.textMuted
        case .keinWert: DesignSystem.Color.textFaint
        }
    }

    nonisolated static let brauchtTrainingsText = "braucht noch Trainings"

    /// Strich mit Hinweis nur, wenn die Haeufigkeit schon auswertbar ist und
    /// nur der Fortschritt fehlt; Muskeln ohne Kraftuebung zeigen "keine Kraftübung im Katalog".
    nonisolated static func brauchtTrainings(_ wert: FortschrittsWert, auswertbar: Bool, ohneKraftuebung: Bool = false) -> Bool {
        wert == .keinWert && auswertbar && !ohneKraftuebung
    }

    /// Kleiner Hinweis unter bzw. neben dem Strich.
    struct BrauchtTrainings: View {
        var body: some View {
            Text(FortschrittsText.brauchtTrainingsText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    nonisolated static func gesprochen(_ wert: FortschrittsWert) -> String {
        switch wert {
        case .wert(let p): p > 0 ? "plus \(p) Prozent" : "minus \(abs(p)) Prozent"
        case .stabil: "plus minus null Prozent"
        case .keinWert: "noch kein Wert"
        }
    }
}

enum MuskelStatusText {
    /// Der Statuschip im Detail; nil = kein Chip.
    static func chip(_ status: MuskelStatus) -> String? {
        switch status {
        case .ok: "Gut dabei"
        case .viel: "Eher viel"
        case .nachholbedarf: "Zu wenig"
        case .keineKraftuebung, .keineAuswertung: nil
        }
    }

    static func gesprochen(_ status: MuskelStatus) -> String {
        switch status {
        case .ok: "gut dabei"
        case .viel: "eher viel"
        case .nachholbedarf: "zu wenig"
        case .keineKraftuebung: "keine Kraftübung im Katalog"
        case .keineAuswertung: "noch keine Auswertung"
        }
    }
}

/// Nachholbedarf · ok · viel · keine Auswertung.
struct MuskelLegende: View {
    private let eintraege: [(String, MuskelStatus)] = [
        ("Nachholbedarf", .nachholbedarf), ("ok", .ok), ("viel", .viel), ("keine Auswertung", .keineAuswertung),
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignSystem.Spacing.s12) { inhalt }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) { inhalt }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var inhalt: some View {
        ForEach(eintraege, id: \.0) { titel, status in
            HStack(spacing: 6) {
                Circle().fill(MuskelFarben.farbe(status)).frame(width: 8, height: 8)
                Text(titel)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Vorschau

enum MuskelVorschau {
    static let gefuellt = MuskelAuswertung(
        haeufigkeit: Haeufigkeit(
            einheiten: 10,
            jeMuskel: ["pectorals": 6, "lats": 5, "upper_back": 2, "deltoid_anterior": 4, "deltoid_lateral": 3,
                       "biceps": 4, "triceps": 5, "quads": 3, "hamstrings": 1, "glutes": 2, "calves": 1, "abs": 1],
            jeGruppe: [.brust: 6, .ruecken: 5, .schultern: 4, .arme: 6, .beine: 3, .rumpf: 1]),
        fortschritt: MuskelFortschritt(
            jeMuskel: ["pectorals": 14, "lats": 9, "upper_back": 2, "deltoid_anterior": -5, "biceps": 11,
                       "triceps": 6, "quads": 4, "hamstrings": 1],
            jeGruppe: [.brust: 14, .ruecken: 5.5, .schultern: -5, .arme: 8.5, .beine: 2.5]))

    static let leer = MuskelAuswertung(
        haeufigkeit: Haeufigkeit(einheiten: 1, jeMuskel: ["pectorals": 1], jeGruppe: [.brust: 1]),
        fortschritt: MuskelFortschritt(jeMuskel: [:], jeGruppe: [:]))
}

#Preview("Übersicht, mit Daten") {
    ScrollView {
        MuskelgruppenUebersichtView(auswertung: MuskelVorschau.gefuellt, geschlecht: .maennlich, onGruppe: { _ in })
            .padding(20)
    }
    .background(DesignSystem.Color.bg)
}

#Preview("Übersicht, zu wenig Training") {
    ScrollView {
        MuskelgruppenUebersichtView(auswertung: MuskelVorschau.leer, geschlecht: .weiblich, onGruppe: { _ in })
            .padding(20)
    }
    .background(DesignSystem.Color.bg)
}
