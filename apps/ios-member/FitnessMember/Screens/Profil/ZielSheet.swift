import SwiftUI

/// Schritt 4 ("Wie oft?") bzw. Schritt 5 ("Zielgewicht") aus dem
/// Onboarding, hier als Sheet ueber Home (R23, "Neues Ziel setzen") und
/// dem Profil. "Übernehmen" ruft `setGoal`, "Ziel aufgeben" ruft
/// `dropGoal` -- beide Schreibwege reicht der Aufrufer als Closures durch
/// (Ruling R27: danach IMMER `catalogStore.load()` UND
/// `verlauf.laden(...)`, weil der Kalender `weeklyTarget` aus
/// `/me/sessions` liest, nicht aus dem Bootstrap; ein neues Zielgewicht
/// macht ausserdem `verlauf.erreichtesZielgewicht` ungueltig -- das ist
/// Sache des Aufrufers, nicht dieses Sheets, das keinen `VerlaufStore`
/// kennt).
struct ZielSheet: View {
    enum Art: Identifiable, Hashable {
        case tageProWoche, zielgewicht

        var id: Self { self }

        /// Der Rohwert aus `PUT /me/goals`/`DELETE /me/goals/[kind]"
        /// (GOAL_KINDS in packages/domain/src/goals.ts) -- dieselbe
        /// Zeichenkette wie in `HomeZieleTests`/`Ziel.kind`.
        var kind: String {
            switch self {
            case .tageProWoche: "weekly_days"
            case .zielgewicht: "target_weight"
            }
        }

        var titel: String {
            switch self {
            case .tageProWoche: "Tage pro Woche"
            case .zielgewicht: "Zielgewicht"
            }
        }
    }

    let art: Art
    /// Das aktive Ziel DIESER Sorte -- bestimmt die Vorgabe UND, ob "Ziel
    /// aufgeben" ueberhaupt erscheint (Ruling: nur, wenn eines aktiv ist).
    let aktiv: Ziel?
    /// Nur fuer `.zielgewicht` gebraucht: Vorgabe-Fallback und
    /// Bezugspunkt der Kontextzeile ("noch X kg"), wie im Onboarding.
    let letzterMesswert: Messwert?
    let uebernehmen: (Double) async -> String?
    let aufgeben: () async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var tage: Int
    @State private var zielgewichtKg: Double
    @State private var fehler: String?
    @State private var laeuft = false

    init(
        art: Art, aktiv: Ziel?, letzterMesswert: Messwert? = nil,
        uebernehmen: @escaping (Double) async -> String?, aufgeben: @escaping () async -> String?
    ) {
        self.art = art
        self.aktiv = aktiv
        self.letzterMesswert = letzterMesswert
        self.uebernehmen = uebernehmen
        self.aufgeben = aufgeben
        _tage = State(initialValue: ProfilZeilen.tageProWocheVorgabe(aktiv: aktiv))
        _zielgewichtKg = State(
            initialValue: ProfilZeilen.zielgewichtVorgabe(aktiv: aktiv, letzterMesswert: letzterMesswert))
    }

    var body: some View {
        ScrollView {
            ZielSheetInhalt(
                art: art, aktiv: aktiv, tage: $tage, zielgewichtKg: $zielgewichtKg,
                letzterMesswert: letzterMesswert, fehler: fehler, laeuft: laeuft,
                uebernehmen: { await speichernUebernehmen() }, aufgeben: { await speichernAufgeben() })
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s24)
                .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
    }

    private func speichernUebernehmen() async {
        laeuft = true
        let wert = art == .tageProWoche ? Double(tage) : zielgewichtKg
        fehler = await uebernehmen(wert)
        laeuft = false
        if fehler == nil { dismiss() }
    }

    private func speichernAufgeben() async {
        laeuft = true
        fehler = await aufgeben()
        laeuft = false
        if fehler == nil { dismiss() }
    }
}

/// Der Sheet-Inhalt ohne die `ScrollView`-Huelle -- derselbe Schnitt wie
/// `AuswahlSheetInhalt`/`GroesseSheetInhalt` (Aufgabe 10), fuer die
/// Sichtpruefung ausserhalb jeder `ScrollView` instanziierbar.
struct ZielSheetInhalt: View {
    let art: ZielSheet.Art
    let aktiv: Ziel?
    @Binding var tage: Int
    @Binding var zielgewichtKg: Double
    let letzterMesswert: Messwert?
    let fehler: String?
    let laeuft: Bool
    let uebernehmen: () async -> Void
    let aufgeben: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text(art.titel.uppercased())
                .font(.system(size: 22, weight: .black))
                .tracking(-0.4)
                .foregroundStyle(DesignSystem.Color.text)

            inhalt

            if let fehler {
                InlineBanner(tone: .danger, message: fehler)
            }

            VStack(spacing: DesignSystem.Spacing.s12) {
                PrimaryButton(title: "Übernehmen", isLoading: laeuft) {
                    await uebernehmen()
                }
                if aktiv != nil {
                    DangerOutlineButton(title: "Ziel aufgeben", isLoading: laeuft) {
                        await aufgeben()
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.s8)
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch art {
        case .tageProWoche:
            WieOftSchritt(tage: $tage)
        case .zielgewicht:
            ZielgewichtSchritt(gewichtKg: letzterMesswert?.weightKg, zielgewichtKg: $zielgewichtKg)
        }
    }
}

// MARK: - Vorschau

#Preview("Tage pro Woche") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ZielSheet(
                art: .tageProWoche,
                aktiv: Ziel(id: "z", kind: "weekly_days", targetValue: 3, createdAt: "2026-08-01T00:00:00Z"),
                uebernehmen: { _ in nil }, aufgeben: { nil })
        }
}

#Preview("Zielgewicht, ohne aktives Ziel") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ZielSheet(
                art: .zielgewicht, aktiv: nil,
                letzterMesswert: Messwert(measuredOn: "2026-09-13", weightKg: 82.5),
                uebernehmen: { _ in nil }, aufgeben: { nil })
        }
}
