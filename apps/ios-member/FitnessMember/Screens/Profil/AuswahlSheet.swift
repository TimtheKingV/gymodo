import SwiftUI

/// ProfilAlter.dc.html -- stellvertretend fuer Geschlecht, Alter und
/// Richtung: Chips wie im Onboarding (`ChipGitter`), "Übernehmen" darunter,
/// "Angabe entfernen" als Umriss in `danger`. Richtung bekommt hier
/// bewusst dieselben Chips wie Geschlecht/Alter, keine Kacheln --
/// `Zielkachel` bleibt dem Onboarding vorbehalten (Aufgabe-10-Brief Step
/// 1: "das Sheet ist kein Onboarding").
///
/// `nil` ist in diesem Typ kein Sonderfall: ein abgewaehlter Chip UND
/// "Angabe entfernen" fuehren beide zu `speichern(nil)`, demselben Wert,
/// den `ProfilWrite.Feld.loeschen` erwartet.
struct AuswahlSheet<Wahl: Hashable & Sendable>: View {
    let titel: String
    var hinweis: String? = nil
    let optionen: [(Wahl, String)]
    let spalten: Int
    let speichern: (Wahl?) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var auswahl: Wahl?
    @State private var fehler: String?
    @State private var laeuft = false

    init(
        titel: String, hinweis: String? = nil, optionen: [(Wahl, String)], gewaehlt: Wahl?,
        spalten: Int, speichern: @escaping (Wahl?) async -> String?
    ) {
        self.titel = titel
        self.hinweis = hinweis
        self.optionen = optionen
        self.spalten = spalten
        self.speichern = speichern
        _auswahl = State(initialValue: gewaehlt)
    }

    var body: some View {
        ScrollView {
            AuswahlSheetInhalt(
                titel: titel, hinweis: hinweis, optionen: optionen, spalten: spalten,
                auswahl: $auswahl, fehler: fehler, laeuft: laeuft,
                uebernehmen: { await uebernehmen(auswahl) }, entfernen: { await uebernehmen(nil) })
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s24)
                .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
    }

    private func uebernehmen(_ wert: Wahl?) async {
        laeuft = true
        fehler = await speichern(wert)
        laeuft = false
        if fehler == nil { dismiss() }
    }
}

/// Der Sheet-Inhalt ohne die `ScrollView`-Huelle -- eigener Typ statt
/// einer privaten `body`-Rechnung, aus demselben Grund wie
/// `GewichtEintragenInhalt` (Aufgabe 9): `ImageRenderer` kann eine
/// `ScrollView` nicht zeichnen (Sichtpruefung Aufgabe 9/10), dieser Typ
/// schon, direkt instanziiert mit `.constant(...)`-Bindings.
struct AuswahlSheetInhalt<Wahl: Hashable & Sendable>: View {
    let titel: String
    var hinweis: String? = nil
    let optionen: [(Wahl, String)]
    let spalten: Int
    @Binding var auswahl: Wahl?
    let fehler: String?
    let laeuft: Bool
    let uebernehmen: () async -> Void
    let entfernen: () async -> Void

    /// Fuer `ChipGitter.text` -- ein Wörterbuch statt einer linearen Suche
    /// je Chip, `optionen` bleibt trotzdem die vom Aufrufer vorgegebene
    /// Reihenfolge (`ChipGitter` iteriert ueber `werte`, nicht ueber die
    /// Dictionary-Schluessel).
    private var beschriftung: [Wahl: String] { Dictionary(uniqueKeysWithValues: optionen) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text(titel.uppercased())
                .font(.system(size: 22, weight: .black))
                .tracking(-0.4)
                .foregroundStyle(DesignSystem.Color.text)

            if let hinweis {
                Text(hinweis)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
            }

            ChipGitter(
                werte: optionen.map(\.0), text: { beschriftung[$0] ?? "" },
                auswahl: $auswahl, spalten: spalten)

            if let fehler {
                InlineBanner(tone: .danger, message: fehler)
            }

            VStack(spacing: DesignSystem.Spacing.s12) {
                PrimaryButton(title: "Übernehmen", isLoading: laeuft) {
                    await uebernehmen()
                }
                // Nur, solange die LIVE-Auswahl etwas traegt: waehlt das
                // Mitglied den letzten Chip ab, sendet "Übernehmen" ab
                // jetzt schon dasselbe (nil) -- ein zweiter Knopf fuer
                // denselben Zielzustand waere Rauschen.
                if auswahl != nil {
                    DangerOutlineButton(title: "Angabe entfernen", isLoading: laeuft) {
                        await entfernen()
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.s8)
        }
    }
}

// MARK: - Vorschau

#Preview("Geschlecht") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AuswahlSheet(
                titel: "Geschlecht", optionen: Geschlecht.alle.map { ($0, $0.wort) },
                gewaehlt: Geschlecht.weiblich, spalten: 3, speichern: { _ in nil })
        }
}

#Preview("Alter") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AuswahlSheet(
                titel: "Alter", hinweis: "Als Spanne. Ändert sich nicht von selbst.",
                optionen: Altersspanne.alle.map { ($0, $0.wort) },
                gewaehlt: Altersspanne.bis34, spalten: 4, speichern: { _ in nil })
        }
}
