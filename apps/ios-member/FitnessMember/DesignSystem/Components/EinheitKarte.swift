import SwiftUI

/// Was die eine Karte zeigt -- fuer ein absolviertes Training (Home) und fuer
/// eine Planeinheit (Plan-Tab, spaeter die Kopfzeile im Detail).
struct EinheitKarteModell: Equatable {
    /// Absolviertes Training (Home) oder Planeinheit.
    enum Art: Equatable { case training, einheit }

    let art: Art
    let titel: String
    /// Zeile unter dem Titel: Tag („Freitag, 6. Nov“, Akzent) oder nil.
    let tag: String?
    let zeilen: [String]
    let stufen: [String: TrainingsProfil.Stufe]
    let zustand: TerminZustand

    static func training(
        _ karte: Trainingskarte, muskeln: [String: [GeraetMuskel]]
    ) -> EinheitKarteModell {
        let profil = TrainingsProfil.berechne(karte: karte, muskeln: muskeln)
        // Keine "AUTO BEENDET"-Marke auf der Karte: sie steht im Detail, wo ein
        // erklaerender Satz neben ihr hat (`SessionDetailView.autoBeendetHinweis`).
        return EinheitKarteModell(
            art: .training, titel: profil.titel, tag: nil,
            zeilen: [HomeZeilen.grosseZeile(karte), HomeZeilen.kleineZeile(karte)],
            stufen: profil.stufen, zustand: .erledigt)
    }

    static func einheit(
        _ einheit: TrainingsplanEinheit, namen: EinheitNamen, muskeln: [String: [GeraetMuskel]],
        tag: String?, zustand: TerminZustand
    ) -> EinheitKarteModell {
        EinheitKarteModell(
            art: .einheit, titel: namen.name(einheit.key), tag: tag,
            zeilen: [EinheitKuerzel.untertitel(einheit)],
            stufen: TrainingsProfil.berechne(einheit: einheit, muskeln: muskeln).stufen,
            zustand: zustand)
    }

    /// „verpasst · verschoben auf Fr“, „verpasst“, „Erledigt“, nil bei .geplant.
    static func zustandsText(_ zustand: TerminZustand, kalender: Calendar) -> String? {
        switch zustand {
        case .geplant:
            return nil
        case .erledigt:
            return "Erledigt"
        case .verpasst(let verschobenAuf):
            guard let tag = verschobenAuf else { return "verpasst" }
            // Feste Kurznamen: unabhaengig von Locale-Eigenheiten (Punkt, Laenge).
            let kurz = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
            let index = (kalender.component(.weekday, from: tag) - 1 + 7) % 7
            return "verpasst · verschoben auf \(kurz[index])"
        }
    }
}

/// Die eine Karte: kleine Muskelfigur, Titel, Kurzinfo, Zustand.
struct EinheitKarte: View {
    let modell: EinheitKarteModell
    let geschlecht: Geschlecht?
    /// Fuer den Text „verpasst · verschoben auf <Kurztag>“.
    var kalender: Calendar = .current
    /// Tippen auf die Karte (ohne den Knopf); nil, wenn die Umgebung selbst tippbar macht.
    var beiTipp: (() -> Void)? = nil
    /// VoiceOver-Hinweis nur fuer den Tipp-Inhalt, nicht fuer den Knopf.
    var hinweis: String? = nil
    /// Optionaler Knopf rechts unten („Training starten“), nur am geplanten Tag.
    /// `label`/`hinweis` fuer VoiceOver; ohne `label` gilt der Titel.
    var aktion: (titel: String, label: String?, hinweis: String?, ausloesen: () -> Void)? = nil

    private var verpasst: Bool {
        if case .verpasst = modell.zustand { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            if let beiTipp {
                Button(action: beiTipp) { inhalt }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityHint(hinweis ?? "")
            } else {
                inhalt
            }
            if let aktion {
                HStack {
                    Spacer(minLength: 0)
                    Button(action: aktion.ausloesen) {
                        Text(aktion.titel)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.onAccent)
                            .padding(.horizontal, DesignSystem.Spacing.s16)
                            .frame(minHeight: 44)
                            .background(DesignSystem.Color.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel(aktion.label ?? aktion.titel)
                    .accessibilityHint(aktion.hinweis ?? "")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(aktion != nil ? DesignSystem.Color.accent : .clear, lineWidth: 1.5))
    }

    private var inhalt: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            // Beide Seiten: im Kleinformat ist schwer zu sehen, ob eine
            // Figur Vorder- oder Rueckseite zeigt -- darum die Beschriftung.
            VStack(spacing: DesignSystem.Spacing.s4) {
                MuskelFigur(
                    farben: MuskelFarben.farben(stufen: modell.stufen), geschlecht: geschlecht,
                    kompakt: true)
                HStack {
                    Text("vorne")
                    Spacer(minLength: 0)
                    Text("hinten")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .frame(width: 76)
            // Die Figur ist Bild, ihre Beschriftung nur fuer das Auge:
            // VoiceOver laese sonst "vorne hinten" vor dem Titel.
            .accessibilityHidden(true)
            text
        }
        .opacity(verpasst ? 0.75 : 1)
        .contentShape(Rectangle())
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(modell.titel)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)

            if let tag = modell.tag {
                Text(tag)
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.accent)
            }

            ForEach(Array(modell.zeilen.enumerated()), id: \.offset) { index, zeile in
                Text(zeile)
                    .font(index == 0 && modell.art == .training
                        ? DesignSystem.Typography.wertSekundaer : DesignSystem.Typography.fliesstext)
                    .foregroundStyle(index == 0 && modell.art == .training
                        ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }

            zustandsmarke
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var zustandsmarke: some View {
        if let text = EinheitKarteModell.zustandsText(modell.zustand, kalender: kalender) {
            if verpasst {
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.horizontal, DesignSystem.Spacing.s8)
                    .padding(.vertical, DesignSystem.Spacing.s4)
                    .overlay(
                        Capsule().strokeBorder(
                            DesignSystem.Color.textFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            } else if case .erledigt = modell.zustand, modell.art == .einheit {
                // Beim Training ist Erledigt selbstverstaendlich; nur die Planeinheit sagt es.
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }
}
