import SwiftUI

/// Der gleiche Kopf fuer Training-Detail und Einheiten-Detail: Ueberzeile,
/// Name, Kurzinfo und darunter die Muskelfigur (Vorder- und Rueckseite) in
/// voller Breite wie unter Fortschritt > Muskulatur. Er nutzt dasselbe Modell
/// wie die Karte, damit beide dieselben Texte zeigen.
struct ProfilKopf: View {
    /// Kleine Zeile ueber dem Titel: „GEPLANT · FREITAG, 6. NOV“ oder das Datum des Trainings.
    let ueberzeile: String
    let modell: EinheitKarteModell
    let geschlecht: Geschlecht?

    /// Akzent nur mit Datum: „EINHEIT“ ohne geplanten Tag bleibt gedaempft.
    private var akzent: Bool { modell.art == .einheit && ueberzeile != "EINHEIT" }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(ueberzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(akzent ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
                Text(modell.titel)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(modell.zeilen.enumerated()), id: \.offset) { _, zeile in
                    Text(zeile)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .monospacedDigit()
                }
            }

            MuskelKartenRahmen {
                VStack(spacing: DesignSystem.Spacing.s12) {
                    VStack(spacing: DesignSystem.Spacing.s8) {
                        MuskelFigur(
                            farben: MuskelFarben.farben(stufen: modell.stufen), geschlecht: geschlecht)
                        HStack(spacing: 0) {
                            MuskelAnsichtsname(text: "Vorderseite")
                            MuskelAnsichtsname(text: "Rückseite")
                        }
                    }
                    legende
                }
            }
            // Die Figur ist schematisch; der Titel nennt die Muskeln als Text.
            .accessibilityHidden(true)
        }
    }

    private var legende: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            legendeEintrag("stark", DesignSystem.Color.accent)
            legendeEintrag("mit", DesignSystem.Color.accentPressed)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendeEintrag(_ text: String, _ farbe: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    // MARK: - Texte

    /// „GEPLANT · FREITAG, 6. NOV“ (de_DE, Monat ohne Punkt, Grossbuchstaben).
    static func ueberzeile(geplantAm: Date, kalender: Calendar) -> String {
        "GEPLANT · \(datumGross(geplantAm, kalender))"
    }

    /// „FREITAG, 6. NOV“ -- das Datum des Trainings im selben Stil.
    static func ueberzeile(trainiertAm: Date, kalender: Calendar) -> String {
        datumGross(trainiertAm, kalender)
    }

    static func startKnopfText(istGeplanterTag: Bool) -> String {
        istGeplanterTag ? "Training starten" : "Jetzt starten (vorziehen)"
    }

    private static func datumGross(_ datum: Date, _ kalender: Calendar) -> String {
        let locale = Locale(identifier: "de_DE")
        let formatierer = DateFormatter()
        formatierer.locale = locale
        formatierer.calendar = kalender
        formatierer.timeZone = kalender.timeZone
        formatierer.dateFormat = "EEEE, d. MMM"
        var text = formatierer.string(from: datum)
        // „Nov.“ -> „Nov“: der Monat steht ohne Abkuerzungspunkt.
        if text.hasSuffix(".") { text.removeLast() }
        return text.uppercased(with: locale)
    }
}
